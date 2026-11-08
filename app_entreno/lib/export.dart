import 'dart:typed_data';

import 'package:excel/excel.dart' as xl;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'models.dart';
import 'store.dart';
import 'theme.dart';
import 'units.dart';

/// Periodo de registros a exportar.
enum ExportPeriod {
  all('Todo', null),
  last30('30 días', 30),
  last90('90 días', 90),
  year('12 meses', 365);

  const ExportPeriod(this.label, this.days);

  final String label;
  final int? days;

  String get description =>
      days == null ? 'Todo el historial' : 'Últimos ${label.toLowerCase()}';
}

/// Sesiones dentro del periodo, de la más antigua a la más reciente.
List<WorkoutSession> sessionsInPeriod(AppStore store, ExportPeriod period, {DateTime? now}) {
  final days = period.days;
  if (days == null) return store.sessions.toList();
  final today = now ?? DateTime.now();
  final from = DateTime(today.year, today.month, today.day).subtract(Duration(days: days - 1));
  return store.sessions.where((s) => !s.date.isBefore(from)).toList();
}

/// Totales de un ejercicio en el periodo exportado.
class ExerciseSummary {
  ExerciseSummary(this.name);

  final String name;
  int sessions = 0;
  int sets = 0;
  double maxWeightKg = 0;
  double bestE1rmKg = 0;
  double volumeKg = 0;
  DateTime? last;
}

List<ExerciseSummary> summarizeExercises(List<WorkoutSession> sessions) {
  final byName = <String, ExerciseSummary>{};
  for (final s in sessions) {
    for (final e in s.exercises) {
      final done = e.doneSets.toList();
      if (done.isEmpty) continue;
      final sum = byName.putIfAbsent(e.name.trim().toLowerCase(), () => ExerciseSummary(e.name.trim()));
      sum
        ..sessions += 1
        ..sets += done.length
        ..volumeKg += e.volumeKg
        ..last = s.date;
      if (e.maxWeightKg > sum.maxWeightKg) sum.maxWeightKg = e.maxWeightKg;
      if (e.bestE1rmKg > sum.bestE1rmKg) sum.bestE1rmKg = e.bestE1rmKg;
    }
  }
  return byName.values.toList()..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
}

String exportFileName(String kind, String extension, {DateTime? now}) =>
    'REHI-$kind-${DateFormat('yyyy-MM-dd').format(now ?? DateTime.now())}.$extension';

double _round(double v) => (v * 100).roundToDouble() / 100;

// ---------------------------------------------------------------------------
// Excel
// ---------------------------------------------------------------------------

/// Libro de Excel con tres hojas: Series, Sesiones y Ejercicios.
Uint8List buildExcel(AppStore store, ExportPeriod period, {DateTime? now}) {
  final sessions = sessionsInPeriod(store, period, now: now);
  final u = store.unit.label;
  double w(double kg) => _round(kgToUnit(kg, store.unit));

  final book = xl.Excel.createExcel();
  final first = book.getDefaultSheet()!;
  book.rename(first, 'Series');

  final hex = paletteById(store.paletteId).header.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase();
  final headerStyle = xl.CellStyle(
    bold: true,
    fontColorHex: xl.ExcelColor.white,
    backgroundColorHex: xl.ExcelColor.fromHexString(hex),
  );

  void sheet(String name, List<(String, double)> columns, List<List<xl.CellValue?>> rows) {
    final sh = book[name];
    sh.appendRow([for (final c in columns) xl.TextCellValue(c.$1)]);
    for (var i = 0; i < columns.length; i++) {
      sh.cell(xl.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).cellStyle = headerStyle;
      sh.setColumnWidth(i, columns[i].$2);
    }
    rows.forEach(sh.appendRow);
  }

  xl.DateCellValue date(DateTime d) => xl.DateCellValue(year: d.year, month: d.month, day: d.day);
  xl.CellValue num(double v) => xl.DoubleCellValue(v);

  sheet('Series', [
    ('Fecha', 12), ('Rutina', 18), ('Día', 16), ('Ejercicio', 30), ('Serie', 7),
    ('Peso ($u)', 10), ('Reps', 7), ('RIR', 6), ('1RM estimado ($u)', 17), ('Volumen ($u)', 13),
  ], [
    for (final s in sessions)
      for (final e in s.exercises)
        for (final (i, set) in e.doneSets.indexed)
          [
            date(s.date),
            xl.TextCellValue(s.routineName),
            xl.TextCellValue(s.dayName),
            xl.TextCellValue(e.name),
            xl.IntCellValue(i + 1),
            num(w(set.weightKg!)),
            xl.IntCellValue(set.reps!),
            set.rir == null ? null : xl.IntCellValue(set.rir!),
            num(w(set.e1rmKg)),
            num(w(set.volumeKg)),
          ],
  ]);

  sheet('Sesiones', [
    ('Fecha', 12), ('Rutina', 18), ('Día', 16), ('Duración (min)', 14),
    ('Ejercicios', 10), ('Series', 8), ('Volumen ($u)', 13),
  ], [
    for (final s in sessions)
      [
        date(s.date),
        xl.TextCellValue(s.routineName),
        xl.TextCellValue(s.dayName),
        s.durationSeconds == null ? null : xl.IntCellValue((s.durationSeconds! / 60).round()),
        xl.IntCellValue(s.exercises.where((e) => e.doneSets.isNotEmpty).length),
        xl.IntCellValue(s.doneSetCount),
        num(w(s.volumeKg)),
      ],
  ]);

  sheet('Ejercicios', [
    ('Ejercicio', 30), ('Sesiones', 9), ('Series', 8), ('Peso máximo ($u)', 16),
    ('Mejor 1RM est. ($u)', 18), ('Volumen total ($u)', 17), ('Última vez', 12),
  ], [
    for (final e in summarizeExercises(sessions))
      [
        xl.TextCellValue(e.name),
        xl.IntCellValue(e.sessions),
        xl.IntCellValue(e.sets),
        num(w(e.maxWeightKg)),
        num(w(e.bestE1rmKg)),
        num(w(e.volumeKg)),
        date(e.last!),
      ],
  ]);

  book.setDefaultSheet('Series');
  return Uint8List.fromList(book.encode()!);
}

// ---------------------------------------------------------------------------
// PDF
// ---------------------------------------------------------------------------

/// Informe en PDF: resumen, tabla por ejercicio y detalle de cada sesión.
Future<Uint8List> buildPdf(AppStore store, ExportPeriod period, {DateTime? now}) {
  final sessions = sessionsInPeriod(store, period, now: now);
  final unit = store.unit;
  final palette = paletteById(store.paletteId);
  final main = PdfColor.fromInt(palette.background.toARGB32());
  final dark = PdfColor.fromInt(palette.header.toARGB32());
  const grey = PdfColor.fromInt(0xFF6B6B6B);
  const line = PdfColor.fromInt(0xFFDDDDDD);
  final generated = now ?? DateTime.now();
  final dateFmt = DateFormat("EEEE d 'de' MMMM yyyy", 'es');

  String w(double kg) => fmtWeight(kg, unit);
  String cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  final totalSets = sessions.fold<int>(0, (t, s) => t + s.doneSetCount);
  final totalVolume = sessions.fold<double>(0, (t, s) => t + s.volumeKg);
  final timed = sessions.where((s) => s.durationSeconds != null).toList();
  final avgDuration = timed.isEmpty
      ? null
      : (timed.fold<int>(0, (t, s) => t + s.durationSeconds!) / timed.length).round();

  pw.Widget stat(String label, String value) => pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: line),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: grey)),
              pw.SizedBox(height: 2),
              pw.Text(value, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: dark)),
            ],
          ),
        ),
      );

  pw.Widget table(List<String> headers, List<List<String>> rows, Map<int, pw.TableColumnWidth> widths,
          {Set<int> right = const {}}) =>
      pw.TableHelper.fromTextArray(
        headers: headers,
        data: rows,
        columnWidths: widths,
        border: const pw.TableBorder(horizontalInside: pw.BorderSide(color: line, width: 0.5)),
        headerDecoration: pw.BoxDecoration(color: main),
        headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9),
        cellStyle: const pw.TextStyle(fontSize: 9),
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        headerAlignments: {
          for (var i = 0; i < headers.length; i++)
            i: right.contains(i) ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
        },
        cellAlignments: {for (final i in right) i: pw.Alignment.centerRight},
      );

  String setsText(ExerciseLog e) => e.doneSets
      .map((s) => '${fmtNum(kgToUnit(s.weightKg!, unit))} × ${s.reps}${s.rir == null ? '' : ' (RIR ${s.rir})'}')
      .join('   ');

  final doc = pw.Document(title: 'REHI - Registro de entrenamiento', author: 'REHI', creator: 'REHI');
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 30),
      header: (ctx) => ctx.pageNumber == 1
          ? pw.SizedBox()
          : pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 10),
              child: pw.Text('REHI · Registro de entrenamiento',
                  style: const pw.TextStyle(fontSize: 8, color: grey)),
            ),
      footer: (ctx) => pw.Container(
        alignment: pw.Alignment.centerRight,
        margin: const pw.EdgeInsets.only(top: 8),
        child: pw.Text('Página ${ctx.pageNumber} de ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: grey)),
      ),
      build: (ctx) => [
        pw.Container(
          padding: const pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(color: main, borderRadius: pw.BorderRadius.circular(8)),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('REHI',
                      style: pw.TextStyle(
                          fontSize: 26, fontWeight: pw.FontWeight.bold, color: PdfColors.white, letterSpacing: 2)),
                  pw.Text('Registro de entrenamiento',
                      style: const pw.TextStyle(fontSize: 11, color: PdfColors.white)),
                ],
              ),
              pw.Spacer(),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(period.description, style: const pw.TextStyle(fontSize: 10, color: PdfColors.white)),
                  pw.Text('Generado el ${DateFormat('d/MM/yyyy', 'es').format(generated)} · pesos en ${unit.label}',
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.white)),
                ],
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 14),
        pw.Row(children: [
          stat('Sesiones', '${sessions.length}'),
          pw.SizedBox(width: 8),
          stat('Series', '$totalSets'),
          pw.SizedBox(width: 8),
          stat('Volumen total', fmtVolume(totalVolume, unit)),
          pw.SizedBox(width: 8),
          stat('Duración promedio', avgDuration == null ? '-' : fmtDuration(avgDuration)),
        ]),
        if (sessions.isEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 24),
            child: pw.Text('No hay entrenamientos registrados en este periodo.',
                style: const pw.TextStyle(color: grey)),
          )
        else ...[
          pw.SizedBox(height: 18),
          pw.Text('Resumen por ejercicio',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: dark)),
          pw.SizedBox(height: 6),
          table(
            ['Ejercicio', 'Sesiones', 'Series', 'Peso máx.', 'Mejor 1RM est.', 'Volumen'],
            [
              for (final e in summarizeExercises(sessions))
                [e.name, '${e.sessions}', '${e.sets}', w(e.maxWeightKg), w(e.bestE1rmKg), fmtVolume(e.volumeKg, unit)],
            ],
            const {
              0: pw.FlexColumnWidth(3.2),
              1: pw.FlexColumnWidth(1.1),
              2: pw.FlexColumnWidth(1),
              3: pw.FlexColumnWidth(1.4),
              4: pw.FlexColumnWidth(1.6),
              5: pw.FlexColumnWidth(1.6),
            },
            right: {1, 2, 3, 4, 5},
          ),
          pw.SizedBox(height: 18),
          pw.Text('Sesiones',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: dark)),
          for (final s in sessions.reversed)
            ..._keepTogether(
              s.exercises.length <= 20,
              [
                pw.SizedBox(height: 10),
                pw.Text(cap(dateFmt.format(s.date)),
                    style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: main)),
                pw.Text(
                  [
                    '${s.routineName} · ${s.dayName}',
                    if (s.durationSeconds != null) fmtDuration(s.durationSeconds!),
                    '${s.doneSetCount} series',
                    'volumen ${fmtVolume(s.volumeKg, unit)}',
                  ].join(' · '),
                  style: const pw.TextStyle(fontSize: 8.5, color: grey),
                ),
                pw.SizedBox(height: 4),
                table(
                  ['Ejercicio', 'Series (${unit.label} × reps)', 'Mejor 1RM est.'],
                  [
                    for (final e in s.exercises)
                      if (e.doneSets.isNotEmpty) [e.name, setsText(e), w(e.bestE1rmKg)],
                  ],
                  const {
                    0: pw.FlexColumnWidth(2.4),
                    1: pw.FlexColumnWidth(5),
                    2: pw.FlexColumnWidth(1.5),
                  },
                  right: {2},
                ),
              ],
            ),
        ],
      ],
    ),
  );
  return doc.save();
}

/// Mantiene el título de una sesión junto a su tabla (no la deja sola al final
/// de una página). Una sesión enorme se deja partir para que quepa.
List<pw.Widget> _keepTogether(bool together, List<pw.Widget> children) => together
    ? [pw.Inseparable(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: children))]
    : children;
