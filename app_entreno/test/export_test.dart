import 'dart:convert';

import 'package:excel/excel.dart' as xl;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:registro_entreno/export.dart';
import 'package:registro_entreno/models.dart';
import 'package:registro_entreno/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppStore> _newStore() async {
  SharedPreferences.setMockInitialValues({});
  return AppStore(await SharedPreferences.getInstance());
}

/// Rutina con dos sesiones: hace 100 días y hace 5 días.
Future<AppStore> _storeWithData(DateTime now) async {
  await initializeDateFormatting('es');
  final store = await _newStore();
  final routine = Routine(name: 'Torso-Pierna', split: 'personalizada', daysPerWeek: 2, days: [
    RoutineDay(name: 'Torso', exercises: [
      PlannedExercise(name: 'Press banca', sets: 2),
      PlannedExercise(name: 'Remo con barra', sets: 1),
    ]),
  ]);
  store.addRoutine(routine);
  for (final (daysAgo, kg) in [(100, 60.0), (5, 70.0)]) {
    final s = store.startSession(routine, routine.days.first, date: now.subtract(Duration(days: daysAgo)));
    s.startedAt = DateTime.now().subtract(const Duration(minutes: 50));
    for (final e in s.exercises) {
      for (final set in e.sets) {
        set
          ..weightKg = kg
          ..reps = 10
          ..rir = 2
          ..done = true;
      }
    }
    store.finishActive();
  }
  return store;
}

/// Valor numérico de una celda (Excel guarda 60.0 como entero al leerlo).
num _num(xl.CellValue? v) => switch (v) {
      xl.IntCellValue(:final value) => value,
      xl.DoubleCellValue(:final value) => value,
      _ => throw StateError('No es un número: $v'),
    };

void main() {
  final now = DateTime(2026, 11, 8, 12);

  group('Copia de seguridad', () {
    test('se guarda y se restaura en otra instalación', () async {
      final store = await _storeWithData(now);
      store.setPalette('pizarra');
      final raw = store.exportBackup(now: now);
      expect(store.lastBackupAt, now);

      // "Reinstalación": almacenamiento vacío.
      final fresh = await _newStore();
      final info = AppStore.readBackup(raw);
      expect(info.routineCount, 1);
      expect(info.sessionCount, 2);
      expect(info.exportedAt, now);
      fresh.restoreBackup(info);

      expect(fresh.routines.single.name, 'Torso-Pierna');
      expect(fresh.sessions.length, 2);
      expect(fresh.paletteId, 'pizarra');
      expect(fresh.progressFor('Press banca').last.maxWeightKg, 70);

      // Y queda guardado en el almacenamiento.
      final again = AppStore(await SharedPreferences.getInstance())..load();
      expect(again.sessions.length, 2);
    });

    test('rechaza archivos que no son copias de REHI', () {
      for (final raw in ['hola', '{}', '[1,2]', jsonEncode({'app': 'Otra', 'data': {}})]) {
        expect(() => AppStore.readBackup(raw), throwsFormatException, reason: raw);
      }
    });

    test('una copia dañada no borra los datos actuales', () async {
      final store = await _storeWithData(now);
      final bad = AppStore.readBackup(jsonEncode({
        'app': 'REHI',
        'data': {
          'routines': [
            {'nombre': 'sin id'},
          ],
        },
      }));
      expect(() => store.restoreBackup(bad), throwsFormatException);
      expect(store.routines.single.name, 'Torso-Pierna');
      expect(store.sessions.length, 2);
    });
  });

  group('Exportar', () {
    test('Excel con hojas Series, Sesiones y Ejercicios', () async {
      final store = await _storeWithData(now);
      final book = xl.Excel.decodeBytes(buildExcel(store, ExportPeriod.all, now: now));
      expect(book.tables.keys, containsAll(['Series', 'Sesiones', 'Ejercicios']));

      final series = book.tables['Series']!;
      expect(series.maxRows, 1 + 2 * 3); // encabezado + 3 series por sesión
      expect(series.row(0).map((c) => c?.value.toString()).take(4),
          ['Fecha', 'Rutina', 'Día', 'Ejercicio']);
      expect(series.row(1)[3]?.value.toString(), 'Press banca');
      expect(_num(series.row(1)[5]?.value), 60);

      final ejercicios = book.tables['Ejercicios']!;
      expect(ejercicios.maxRows, 3);
      expect(book.tables['Sesiones']!.maxRows, 3);
    });

    test('Excel respeta libras y el periodo elegido', () async {
      final store = await _storeWithData(now);
      store.setUnit(WeightUnit.lb);
      final book = xl.Excel.decodeBytes(buildExcel(store, ExportPeriod.last30, now: now));
      final series = book.tables['Series']!;
      expect(series.maxRows, 1 + 3); // solo la sesión de hace 5 días
      expect(series.row(0)[5]?.value.toString(), 'Peso (lb)');
      expect(_num(series.row(1)[5]?.value), closeTo(154.32, 0.01));
    });

    test('PDF válido, también sin registros en el periodo', () async {
      final store = await _storeWithData(now);
      final pdf = await buildPdf(store, ExportPeriod.all, now: now);
      expect(ascii.decode(pdf.sublist(0, 5)), '%PDF-');
      expect(pdf.length, greaterThan(2000));

      final empty = await _newStore();
      final pdfEmpty = await buildPdf(empty, ExportPeriod.last30, now: now);
      expect(ascii.decode(pdfEmpty.sublist(0, 5)), '%PDF-');
    });

    test('nombres de archivo con la fecha', () {
      expect(exportFileName('registros', 'xlsx', now: now), 'REHI-registros-2026-11-08.xlsx');
    });
  });
}
