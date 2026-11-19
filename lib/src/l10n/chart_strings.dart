import 'package:flutter/widgets.dart';

/// Minimal localized strings used inside chart widgets (`en`, `pt-BR`, `th`).
extension ReportsViewStrings on BuildContext {
  String tr(String key, [Map<String, String> params = const {}]) {
    final locale = Localizations.maybeLocaleOf(this);
    final lang = locale?.languageCode ?? 'en';
    final isPt = lang == 'pt';
    final isTh = lang == 'th';
    var template = switch (key) {
      'other' => isPt ? 'Outros' : (isTh ? 'อื่น ๆ' : 'Other'),
      'no_data' => isPt
          ? 'Sem dados'
          : (isTh ? 'ไม่มีข้อมูลสำหรับตัวเลือกนี้' : 'No data for this selection'),
      'share_of' => isPt
          ? '{share} de {name}'
          : (isTh ? '{share} ของ {name}' : '{share} of {name}'),
      'rows_range' => isPt
          ? 'Linhas {from} a {to} de {total}'
          : (isTh ? 'แถว {from} ถึง {to} จาก {total}' : 'Rows {from} to {to} of {total}'),
      'previous_page' => isPt ? 'Página anterior' : (isTh ? 'หน้าก่อนหน้า' : 'Previous page'),
      'next_page' => isPt ? 'Próxima página' : (isTh ? 'หน้าถัดไป' : 'Next page'),
      _ => key,
    };
    params.forEach((k, v) {
      template = template.replaceAll('{$k}', v);
    });
    return template;
  }
}
