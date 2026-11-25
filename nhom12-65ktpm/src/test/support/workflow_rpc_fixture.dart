import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const workflowActorA = 'a5100000-0000-4000-8000-000000000001';
const workflowActorB = 'a5100000-0000-4000-8000-000000000002';

Map<String, dynamic> transactionRpcFixture() => {
  'transaction': {
    'id': 'transaction-1',
    'listingId': 'listing-1',
    'requestId': 'request-1',
    'materialId': 'material-1',
    'type': 'SELL',
    'ownerAtAcceptance': workflowActorA,
    'receiverId': workflowActorB,
    'status': 'AWAITING_PAYMENT',
    'agreedBorrowDays': null,
    'agreedPriceVnd': 85000,
  },
  'materialTitle': 'Sách kiểm tra adapter',
  'materialSubject': 'Lập trình',
  'ownerDisplayName': 'Người bán',
  'receiverDisplayName': 'Người mua',
  'viewerRole': 'OWNER',
  'createdAt': '2026-11-25T09:30:00+07:00',
  'borrowing': null,
  'payment': {
    'transactionId': 'transaction-1',
    'buyerReportedAt': null,
    'sellerConfirmedAt': null,
    'refundReportedAt': null,
    'buyerRefundConfirmedAt': null,
  },
  'openIssueCount': 0,
  'cancellationProposal': null,
  'allowedActions': [
    'CAN_CONFIRM_SELLER_PAYMENT',
    'CAN_PROPOSE_CANCELLATION',
    'CAN_REPORT_ISSUE',
  ],
};

Map<String, dynamic> issueRpcFixture() => {
  'issue': {
    'id': 'issue-1',
    'transactionId': 'transaction-1',
    'reporterId': workflowActorB,
    'type': 'WRONG_CONDITION',
    'reason': 'Bìa có ghi chú cần đối chiếu.',
    'handoverId': null,
    'status': 'OPEN',
    'openedAt': '2026-11-25T03:00:00Z',
    'resolvedAt': null,
  },
  'materialTitle': 'Sách kiểm tra adapter',
  'reporterDisplayName': 'Người mua',
  'counterpartyDisplayName': 'Người bán',
  'relation': 'COUNTERPARTY',
  'proposal': {
    'revision': 2,
    'summary': 'Đối chiếu ghi chú và thống nhất tiếp tục.',
    'proposedByDisplayName': 'Người bán',
    'proposedAt': '2026-11-25T04:00:00Z',
    'consents': [
      {
        'participantDisplayName': 'Người bán',
        'approvedAt': '2026-11-25T04:10:00Z',
      },
      {'participantDisplayName': 'Người mua', 'approvedAt': null},
    ],
  },
  'evidenceCount': 0,
  'canViewEvidence': false,
  'canViewTransaction': true,
  'allowedActions': ['CAN_PROPOSE_ISSUE_RESOLUTION'],
};

http.Response workflowResponse(Object? value, {int status = 200}) =>
    http.Response(
      jsonEncode(value),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

/// HTTP giả chỉ trong test; không dùng tài khoản/fixture Cloud hay service key.
class WorkflowTestBackend {
  WorkflowTestBackend() {
    client = SupabaseClient(
      'http://127.0.0.1:54321',
      'unit-test-public-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/token')) {
          final input = jsonDecode(request.body) as Map;
          final actor = input['email'] == 'b@example.test'
              ? workflowActorB
              : workflowActorA;
          final expiry =
              DateTime.now()
                  .toUtc()
                  .add(const Duration(hours: 1))
                  .millisecondsSinceEpoch ~/
              1000;
          String part(Object value) => base64Url
              .encode(utf8.encode(jsonEncode(value)))
              .replaceAll('=', '');
          final jwt =
              '${part({'alg': 'none', 'typ': 'JWT'})}.${part({'sub': actor, 'exp': expiry, 'aud': 'authenticated'})}.test';
          return workflowResponse({
            'access_token': jwt,
            'refresh_token': 'unit-refresh',
            'token_type': 'bearer',
            'expires_in': 3600,
            'expires_at': expiry,
            'user': {
              'id': actor,
              'aud': 'authenticated',
              'role': 'authenticated',
              'email': input['email'],
              'app_metadata': {},
              'user_metadata': {},
              'created_at': '2026-11-25T00:00:00Z',
            },
          });
        }
        if (request.url.path.endsWith('/logout')) return workflowResponse({});
        if (!request.url.path.startsWith('/rest/v1/rpc/')) {
          throw StateError('Unexpected non-RPC data access');
        }
        requests.add(request);
        final response = await onRpc(request);
        return http.Response.bytes(
          response.bodyBytes,
          response.statusCode,
          request: request,
          headers: response.headers,
        );
      }),
    );
  }

  late final SupabaseClient client;
  final requests = <http.Request>[];
  FutureOr<http.Response> Function(http.Request) onRpc = (_) =>
      workflowResponse([]);

  Future<void> login({bool asB = false}) async {
    await client.auth.signInWithPassword(
      email: asB ? 'b@example.test' : 'a@example.test',
      password: 'unit-only',
    );
  }

  Future<void> dispose() => client.dispose();
}
