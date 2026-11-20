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
      'source_unavailable' => isPt
          ? 'Fonte indisponível'
          : (isTh ? 'ไม่มีแหล่งข้อมูล' : 'Source unavailable'),
      'source_label' => isPt
          ? 'Fonte: {source}'
          : (isTh ? 'แหล่งที่มา: {source}' : 'Source: {source}'),
      'period_unavailable' => isPt
          ? 'Período indisponível'
          : (isTh ? 'ไม่มีช่วงเวลา' : 'Period unavailable'),
      'period_range' => isPt
          ? 'Período: {start} a {end} ({tz})'
          : (isTh ? 'ช่วงเวลา: {start} ถึง {end} ({tz})' : 'Period: {start} to {end} ({tz})'),
      'period_single' => isPt
          ? 'Período: {value} ({tz})'
          : (isTh ? 'ช่วงเวลา: {value} ({tz})' : 'Period: {value} ({tz})'),
      'snapshot_label' => isPt
          ? 'Captura: {value}'
          : (isTh ? 'ภาพรวม: {value}' : 'Snapshot: {value}'),
      'offline_updated' => isPt
          ? 'Offline, última atualização {value} ({tz})'
          : (isTh ? 'ออฟไลน์ อัปเดตล่าสุด {value} ({tz})' : 'Offline, last updated {value} ({tz})'),
      'updated_label' => isPt
          ? 'Atualizado: {value} ({tz})'
          : (isTh ? 'อัปเดต: {value} ({tz})' : 'Updated: {value} ({tz})'),
      'last_update_unavailable' => isPt
          ? 'Última atualização indisponível'
          : (isTh ? 'ไม่มีเวลาอัปเดตล่าสุด' : 'Last update unavailable'),
      'tier_real' => isPt ? 'Real' : (isTh ? 'ข้อมูลจริง' : 'Real'),
      'tier_hybrid' => isPt ? 'Híbrido' : (isTh ? 'ข้อมูลผสม' : 'Hybrid'),
      'tier_sample' => isPt ? 'Amostra' : (isTh ? 'ตัวอย่าง' : 'Sample'),
      'loading_chart' => isPt
          ? 'Carregando gráfico...'
          : (isTh ? 'กำลังโหลดแผนภูมิ...' : 'Loading chart...'),
      'no_data_period' => isPt
          ? 'Sem dados para este período'
          : (isTh ? 'ไม่มีข้อมูลสำหรับช่วงเวลานี้' : 'No data for this period'),
      'restricted_chart' => isPt
          ? 'Gráfico restrito'
          : (isTh ? 'แผนภูมิจำกัดสิทธิ์' : 'Restricted chart'),
      'error_chart' => isPt
          ? 'Não foi possível carregar o gráfico'
          : (isTh ? 'ไม่สามารถโหลดแผนภูมิได้' : 'Could not load chart'),
      'retry' => isPt ? 'Tentar novamente' : (isTh ? 'ลองใหม่' : 'Retry'),
      'show_as_chart' => isPt
          ? 'Mostrar como gráfico'
          : (isTh ? 'แสดงเป็นแผนภูมิ' : 'Show as chart'),
      'show_as_table' => isPt
          ? 'Mostrar como tabela'
          : (isTh ? 'แสดงเป็นตาราง' : 'Show as table'),
      'see_all' => isPt ? 'Ver tudo' : (isTh ? 'ดูทั้งหมด' : 'See all'),
      _ => key,
    };
    params.forEach((k, v) {
      template = template.replaceAll('{$k}', v);
    });
    return template;
  }
}
