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
      'no_data' =>
        isPt
            ? 'Sem dados'
            : (isTh
                  ? 'ไม่มีข้อมูลสำหรับตัวเลือกนี้'
                  : 'No data for this selection'),
      'share_of' =>
        isPt
            ? '{share} de {name}'
            : (isTh ? '{share} ของ {name}' : '{share} of {name}'),
      'rows_range' =>
        isPt
            ? 'Linhas {from} a {to} de {total}'
            : (isTh
                  ? 'แถว {from} ถึง {to} จาก {total}'
                  : 'Rows {from} to {to} of {total}'),
      'previous_page' =>
        isPt ? 'Página anterior' : (isTh ? 'หน้าก่อนหน้า' : 'Previous page'),
      'next_page' =>
        isPt ? 'Próxima página' : (isTh ? 'หน้าถัดไป' : 'Next page'),
      'source_unavailable' =>
        isPt
            ? 'Fonte indisponível'
            : (isTh ? 'ไม่มีแหล่งข้อมูล' : 'Source unavailable'),
      'source_label' =>
        isPt
            ? 'Fonte: {source}'
            : (isTh ? 'แหล่งที่มา: {source}' : 'Source: {source}'),
      'period_unavailable' =>
        isPt
            ? 'Período indisponível'
            : (isTh ? 'ไม่มีช่วงเวลา' : 'Period unavailable'),
      'period_range' =>
        isPt
            ? 'Período: {start} a {end} ({tz})'
            : (isTh
                  ? 'ช่วงเวลา: {start} ถึง {end} ({tz})'
                  : 'Period: {start} to {end} ({tz})'),
      'period_single' =>
        isPt
            ? 'Período: {value} ({tz})'
            : (isTh ? 'ช่วงเวลา: {value} ({tz})' : 'Period: {value} ({tz})'),
      'snapshot_label' =>
        isPt
            ? 'Captura: {value}'
            : (isTh ? 'ภาพรวม: {value}' : 'Snapshot: {value}'),
      'offline_updated' =>
        isPt
            ? 'Offline, última atualização {value} ({tz})'
            : (isTh
                  ? 'ออฟไลน์ อัปเดตล่าสุด {value} ({tz})'
                  : 'Offline, last updated {value} ({tz})'),
      'updated_label' =>
        isPt
            ? 'Atualizado: {value} ({tz})'
            : (isTh ? 'อัปเดต: {value} ({tz})' : 'Updated: {value} ({tz})'),
      'last_update_unavailable' =>
        isPt
            ? 'Última atualização indisponível'
            : (isTh ? 'ไม่มีเวลาอัปเดตล่าสุด' : 'Last update unavailable'),
      'tier_real' => isPt ? 'Real' : (isTh ? 'ข้อมูลจริง' : 'Real'),
      'tier_hybrid' => isPt ? 'Híbrido' : (isTh ? 'ข้อมูลผสม' : 'Hybrid'),
      'tier_sample' => isPt ? 'Amostra' : (isTh ? 'ตัวอย่าง' : 'Sample'),
      'loading_chart' =>
        isPt
            ? 'Carregando gráfico...'
            : (isTh ? 'กำลังโหลดแผนภูมิ...' : 'Loading chart...'),
      'no_data_period' =>
        isPt
            ? 'Sem dados para este período'
            : (isTh
                  ? 'ไม่มีข้อมูลสำหรับช่วงเวลานี้'
                  : 'No data for this period'),
      'restricted_chart' =>
        isPt
            ? 'Gráfico restrito'
            : (isTh ? 'แผนภูมิจำกัดสิทธิ์' : 'Restricted chart'),
      'error_chart' =>
        isPt
            ? 'Não foi possível carregar o gráfico'
            : (isTh ? 'ไม่สามารถโหลดแผนภูมิได้' : 'Could not load chart'),
      'retry' => isPt ? 'Tentar novamente' : (isTh ? 'ลองใหม่' : 'Retry'),
      'show_as_chart' =>
        isPt
            ? 'Mostrar como gráfico'
            : (isTh ? 'แสดงเป็นแผนภูมิ' : 'Show as chart'),
      'show_as_table' =>
        isPt
            ? 'Mostrar como tabela'
            : (isTh ? 'แสดงเป็นตาราง' : 'Show as table'),
      'see_all' => isPt ? 'Ver tudo' : (isTh ? 'ดูทั้งหมด' : 'See all'),
      'roc_single_class_summary' =>
        isPt
            ? 'ROC indisponível (classe única)'
            : (isTh
                  ? 'ROC ไม่พร้อมใช้งาน (มีคลาสเดียว)'
                  : 'ROC unavailable (single class)'),
      'roc_pr_unavailable_summary' =>
        isPt
            ? 'ROC / PR indisponíveis'
            : (isTh ? 'ROC / PR ไม่พร้อมใช้งาน' : 'ROC / PR unavailable'),
      'roc_single_class_banner' =>
        isPt
            ? 'ROC N/D (classe única) | PR AUC ${params['pr'] ?? ''}'
            : (isTh
                  ? 'ROC ไม่มีค่า (มีคลาสเดียว) | PR AUC ${params['pr'] ?? ''}'
                  : 'ROC N/A (single class) | PR AUC ${params['pr'] ?? ''}'),
      'roc_pr_missing_data' =>
        isPt
            ? 'ROC / PR indisponíveis (dados pareados ausentes)'
            : (isTh
                  ? 'ROC / PR ไม่พร้อมใช้งาน (ขาดข้อมูลคู่)'
                  : 'ROC / PR unavailable (missing paired data)'),
      'roc_pr_single_class' =>
        isPt
            ? 'ROC / PR indisponíveis (classe única)'
            : (isTh
                  ? 'ROC / PR ไม่พร้อมใช้งาน (มีคลาสเดียว)'
                  : 'ROC / PR unavailable (single class)'),
      'no_valid_probability_samples' =>
        isPt
            ? 'Sem amostras de probabilidade válidas'
            : (isTh
                  ? 'ไม่มีตัวอย่างความน่าจะเป็นที่ใช้ได้'
                  : 'No valid probability samples'),
      'calibration_unavailable' =>
        isPt
            ? 'Calibração indisponível (dados ausentes)'
            : (isTh
                  ? 'การสอบเทียบไม่พร้อมใช้งาน (ขาดข้อมูล)'
                  : 'Calibration unavailable (missing data)'),
      'confusion_matrix_unavailable' =>
        isPt
            ? 'Matriz de confusão indisponível (dados ausentes)'
            : (isTh
                  ? 'เมทริกซ์ความสับสนไม่พร้อมใช้งาน (ขาดข้อมูล)'
                  : 'Confusion matrix unavailable (missing data)'),
      'no_valid_learning_curve_samples' =>
        isPt
            ? 'Sem amostras válidas da curva de aprendizado'
            : (isTh
                  ? 'ไม่มีตัวอย่างกราฟการเรียนรู้ที่ใช้ได้'
                  : 'No valid learning curve samples'),
      'no_valid_irt_item_parameters' =>
        isPt
            ? 'Sem parâmetros de item IRT válidos'
            : (isTh
                  ? 'ไม่มีพารามิเตอร์ข้อสอบ IRT ที่ใช้ได้'
                  : 'No valid IRT item parameters'),
      'no_valid_wright_map_logits' =>
        isPt
            ? 'Sem logits válidos para o mapa de Wright'
            : (isTh
                  ? 'ไม่มีค่า logit ของแผนภาพ Wright ที่ใช้ได้'
                  : 'No valid Wright map logits'),
      'no_valid_item_difficulty_pairs' =>
        isPt
            ? 'Sem pares válidos de dificuldade de item'
            : (isTh
                  ? 'ไม่มีคู่ค่าความยากของข้อสอบที่ใช้ได้'
                  : 'No valid item difficulty pairs'),
      'kaplan_meier_unavailable' =>
        isPt
            ? 'Kaplan-Meier indisponível (dados ausentes)'
            : (isTh
                  ? 'Kaplan-Meier ไม่พร้อมใช้งาน (ขาดข้อมูล)'
                  : 'Kaplan-Meier unavailable (missing data)'),
      _ => key,
    };
    params.forEach((k, v) {
      template = template.replaceAll('{$k}', v);
    });
    return template;
  }
}
