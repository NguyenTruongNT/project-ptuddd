import 'dart:convert';
import 'dart:io';

/// Chỉ hỗ trợ fixture QA ở host đã đăng nhập CLI. Không thuộc mã ứng dụng,
/// không mở thêm endpoint test và không nới quyền service_role trên Cloud.
class QrCloudQa {
  QrCloudQa(this.suffix) {
    uuid(suffix);
  }
  final String suffix;

  String uuid(String value) {
    if (!RegExp(r'^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$')
        .hasMatch(value)) {
      throw const FormatException('QA chỉ nhận UUID do test tạo.');
    }
    return "'$value'::uuid";
  }

  Future<List<Map<String, dynamic>>> query(
    String step,
    String sql, {
    bool readOnly = true,
  }) async {
    if (!RegExp(r'^[a-z-]+$').hasMatch(step)) {
      throw const FormatException('Invalid QA step');
    }
    final file = File('.dart_tool/qr-home-$suffix-$step.sql');
    await file.writeAsString(sql);
    final result = await Process.run('npx.cmd', [
      'supabase@3.3.0',
      'db',
      'query',
      '--remote=dacrjfgleursgtnzeoix',
      readOnly ? '--read-only' : '--yes',
      '--file',
      file.path,
      '--output-format',
      'json',
    ]);
    if (result.exitCode != 0) {
      // SQL chỉ chứa UUID fixture. Giữ log local để sửa/dọn; không log credential.
      await File('${file.path}.log')
          .writeAsString('${result.stdout}\n${result.stderr}');
      throw StateError('Cloud QA $step thất bại; xem ${file.path}.log');
    }
    final response =
        jsonDecode(result.stdout as String) as Map<String, dynamic>;
    return (response['rows'] as List).cast<Map<String, dynamic>>();
  }

  Future<void> prepareTransaction({
    required String material,
    required String owner,
    required String receiver,
    required String listing,
    required String request,
    required String transaction,
  }) async {
    final m = uuid(material),
        a = uuid(owner),
        b = uuid(receiver),
        l = uuid(listing),
        r = uuid(request),
        t = uuid(transaction);
    await query('prepare', '''do \$\$ begin
      if not exists(select 1 from auth.users where id=$a and email='n4-a-$suffix@example.test')
        or not exists(select 1 from auth.users where id=$b and email='n4-b-$suffix@example.test')
        or not exists(select 1 from public.materials where id=$m and owner_id=$a) then
        raise exception 'Fixture scope mismatch'; end if;
      insert into public.listings(id,material_id,created_by,offer_type,status) values($l,$m,$a,'BORROW','PUBLISHED');
      insert into public.exchange_requests(id,listing_id,requester_id,requested_borrow_days,status)
        values($r,$l,$b,7,'ACCEPTED');
      insert into public.transactions(id,listing_id,request_id,material_id,type,owner_at_acceptance,receiver_id,status,agreed_borrow_days)
        values($t,$l,$r,$m,'BORROW',$a,$b,'AWAITING_HANDOVER',7);
    end \$\$; select true as prepared;''', readOnly: false);
  }

  Future<void> cleanup(List<String> users) async {
    if (users.isEmpty) return;
    final actors = 'array[${users.map(uuid).join(',')}]::uuid[]';
    // Chỉ xóa domain gắn hai account vừa tạo và có đúng hậu tố của lần chạy.
    // Không dọn theo prefix toàn cục, không chạm khóa ký QR hoặc dữ liệu nhóm.
    await query(
      'cleanup',
      '''do \$\$ declare actors uuid[]:=$actors; txns uuid[];
    begin
      if exists(select 1 from auth.users where id=any(actors)
        and email not in ('n4-a-$suffix@example.test','n4-b-$suffix@example.test')) then
        raise exception 'Fixture scope mismatch'; end if;
      select array_agg(id) into txns from public.transactions
        where owner_at_acceptance=any(actors) and receiver_id=any(actors);
      delete from public.borrowing_records where transaction_id=any(txns);
      delete from public.handover_evidence where handover_id in (select id from public.handovers where transaction_id=any(txns));
      delete from public.handovers where transaction_id=any(txns);
      delete from public.transaction_events where transaction_id=any(txns);
      delete from public.payment_confirmations where transaction_id=any(txns);
      delete from public.transactions where id=any(txns);
      delete from public.exchange_requests where listing_id in
        (select l.id from public.listings l join public.materials m on m.id=l.material_id where m.owner_id=any(actors));
      delete from public.listing_snapshot_images where listing_id in
        (select l.id from public.listings l join public.materials m on m.id=l.material_id where m.owner_id=any(actors));
      delete from public.listings where material_id in (select id from public.materials where owner_id=any(actors));
      delete from public.material_qr_credentials where material_id in (select id from public.materials where owner_id=any(actors));
      delete from public.materials where owner_id=any(actors);
      delete from public.command_receipts where actor_id=any(actors);
    end \$\$; select true as cleaned;''',
      readOnly: false,
    );
  }
}
