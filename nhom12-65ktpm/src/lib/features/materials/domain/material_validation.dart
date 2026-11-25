import '../../../core/contracts/command_inputs.dart';

class MaterialValidation {
  static const maxImages = 5;
  static const maxImageBytes = 5242880;
  static bool text(String value, int max) {
    final v = value.trim();
    return v.isNotEmpty &&
        v.runes.length <= max &&
        !RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]').hasMatch(v);
  }

  static String normalizeIsbn(String value) =>
      value.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();
  static bool isbn(String value) {
    final v = normalizeIsbn(value);
    if (v.isEmpty) return true;
    if (RegExp(r'^\d{9}[\dX]$').hasMatch(v)) {
      var sum = 0;
      for (var i = 0; i < 10; i++) {
        sum += (10 - i) * (v[i] == 'X' ? 10 : int.parse(v[i]));
      }
      return sum % 11 == 0;
    }
    if (!RegExp(r'^97[89]\d{10}$').hasMatch(v)) return false;
    var sum = 0;
    for (var i = 0; i < 13; i++) {
      sum += int.parse(v[i]) * (i.isEven ? 1 : 3);
    }
    return sum % 10 == 0;
  }

  static bool input(CreateMaterialInput v) =>
      text(v.title, 200) &&
      text(v.subject, 100) &&
      text(v.condition, 100) &&
      (v.description == null ||
          v.description!.trim().isEmpty ||
          text(v.description!, 2000)) &&
      isbn(v.isbn ?? '') &&
      v.imageIds.length <= maxImages &&
      v.imageIds.toSet().length == v.imageIds.length;
}
