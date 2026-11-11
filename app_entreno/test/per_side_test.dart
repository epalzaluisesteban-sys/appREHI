import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:registro_entreno/main.dart';
import 'package:registro_entreno/models.dart';
import 'package:registro_entreno/screens/progress_screen.dart';
import 'package:registro_entreno/screens/workout_screen.dart';
import 'package:registro_entreno/store.dart';
import 'package:registro_entreno/warmup.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Copia de seguridad tal como la genera la versión 1.2.0
/// (con aproximaciones y sin peso por lado).
const _backupV120 = '''
{
 "app": "REHI",
 "format": 1,
 "exportedAt": "2026-11-10T10:00:00.000",
 "data": {
  "unit": "kg",
  "palette": "pizarra",
  "alarmSound": false,
  "routines": [
   {
    "id": "r1", "name": "Torso-Pierna", "split": "torso_pierna", "daysPerWeek": 4,
    "days": [
     {
      "id": "d2", "name": "Pierna A",
      "exercises": [
       {"id": "e1", "name": "Prensa de piernas", "sets": 3, "repsMin": 10, "repsMax": 12,
        "restSeconds": 150, "notes": "", "warmup": [40, 60, 80]},
       {"id": "e2", "name": "Curl femoral", "sets": 3, "repsMin": 10, "repsMax": 15,
        "restSeconds": 90, "notes": ""}
      ]
     }
    ],
    "createdAt": "2026-11-01T09:00:00.000"
   }
  ],
  "sessions": [
   {
    "id": "s1", "routineId": "r1", "routineName": "Torso-Pierna",
    "dayId": "d2", "dayName": "Pierna A", "date": "2026-11-09T18:00:00.000",
    "exercises": [
     {"exerciseId": "e1", "name": "Prensa de piernas", "repsMin": 10, "repsMax": 12,
      "restSeconds": 150,
      "sets": [{"w": 100, "r": 12, "rir": 2, "done": true}, {"w": 100, "r": 10, "rir": 1, "done": true}]}
    ],
    "startedAt": "2026-11-09T18:00:00.000",
    "durationSeconds": 3000
   }
  ],
  "active": null,
  "lastBackupAt": "2026-11-10T10:00:00.000"
 }
}
''';

Future<AppStore> _newStore() async {
  SharedPreferences.setMockInitialValues({});
  await initializeDateFormatting('es');
  return AppStore(await SharedPreferences.getInstance());
}

Widget _app(AppStore store) =>
    ChangeNotifierProvider.value(value: store, child: const EntrenoApp());

void main() {
  group('Peso por lado (X×2)', () {
    test('desactivado por defecto y no cambia el formato guardado', () {
      final e = PlannedExercise(name: 'Prensa');
      expect(e.perSide, isFalse);
      expect(e.loadFactor, 1);
      expect(e.toJson().containsKey('perSide'), isFalse);
    });

    test('se guarda y se lee', () {
      final e = PlannedExercise(name: 'Prensa', perSide: true);
      expect(e.loadFactor, 2);
      expect(e.toJson()['perSide'], isTrue);
      expect(PlannedExercise.fromJson(e.toJson()).perSide, isTrue);
      expect(e.copy().perSide, isTrue);
    });

    test('aproximaciones por lado: la mitad, redondeada', () {
      expect(warmupWeights(100, defaultWarmupPercents, WeightUnit.kg, perSide: true),
          [20, 30, 40]);
      expect(warmupWeights(90, [40, 60, 80], WeightUnit.kg, perSide: true), [18, 27, 36]);
      // 100 kg ≈ 220.5 lb → 110 lb por lado; 50 % = 55 lb.
      expect(warmupWeights(100, [50], WeightUnit.lb, perSide: true), [55]);
    });
  });

  group('Copia de seguridad de la 1.2.0', () {
    test('se restaura completa y sin peso por lado', () async {
      final store = await _newStore();
      store.restoreBackup(AppStore.readBackup(_backupV120));

      final exs = store.routines.single.days.single.exercises;
      expect(exs.map((e) => e.name), ['Prensa de piernas', 'Curl femoral']);
      expect(exs.first.warmupPercents, [40, 60, 80]);
      expect(exs.every((e) => !e.perSide), isTrue);
      expect(store.sessions.single.exercises.single.maxWeightKg, 100);
      expect(store.paletteId, 'pizarra');
      expect(store.alarmSound, isFalse);

      // Sin activar la opción, cada ejercicio se guarda exactamente igual que antes.
      final raw = (AppStore.readBackup(_backupV120).data['routines'] as List).first['days'][0]
          ['exercises'] as List;
      for (var i = 0; i < exs.length; i++) {
        expect(exs[i].toJson(), raw[i]);
      }
    });

    test('el peso por lado viaja en la copia nueva', () async {
      final store = await _newStore();
      store.restoreBackup(AppStore.readBackup(_backupV120));
      store.routines.single.days.single.exercises.first.perSide = true;
      final raw = store.exportBackup();

      final other = await _newStore();
      other.restoreBackup(AppStore.readBackup(raw));
      final exs = other.routines.single.days.single.exercises;
      expect(exs.first.perSide, isTrue);
      expect(exs.first.warmupPercents, [40, 60, 80]);
      expect(exs.last.perSide, isFalse);
    });
  });

  group('Lectura rápida de la gráfica', () {
    test('menos de 3 sesiones: sin tendencia', () {
      expect(chartVerdict([100, 105]).trend, Trend.tooFew);
    });
    test('última sesión = mejor marca: vas bien', () {
      expect(chartVerdict([100, 102, 105]).trend, Trend.good);
      expect(chartVerdict([100, 105, 105]).trend, Trend.good);
    });
    test('un poco por debajo: normal', () {
      final v = chartVerdict([100, 105, 103]);
      expect(v.trend, Trend.normal);
      expect(v.text, contains('1.9 %'));
    });
    test('3 sesiones sin superar la mejor marca: revisar', () {
      final v = chartVerdict([100, 110, 105, 104, 100]);
      expect(v.trend, Trend.warning);
      expect(v.text, contains('3 sesiones'));
    });
  });

  testWidgets('peso por lado: se activa, se escribe un lado y se guarda el total',
      (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final store = await _newStore();
    store.restoreBackup(AppStore.readBackup(_backupV120));
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();
    final routine = store.routines.single;
    final day = routine.days.single;

    // Activar la opción en el editor de la prensa.
    await tester.tap(find.text('Pierna A'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Prensa de piernas'));
    await tester.pumpAndSettle();
    final sw = find.text('Peso por lado (X×2)');
    await tester.scrollUntilVisible(sw, 200, scrollable: find.byType(Scrollable).last);
    await tester.tap(sw);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Guardar ejercicio'));
    await tester.tap(find.text('Guardar ejercicio'));
    await tester.pumpAndSettle();
    expect(day.exercises.first.perSide, isTrue);
    expect(day.exercises.last.perSide, isFalse);
    expect(find.textContaining('Peso por lado (×2)'), findsOneWidget);

    // En el entrenamiento: anterior y aproximaciones por lado (100 kg → 50 por lado).
    startWorkoutFlow(tester.element(find.byType(Scaffold).last), routine, day);
    await tester.pumpAndSettle();
    expect(find.text('kg/lado'), findsOneWidget);
    expect(find.text('Peso por lado ×2 · se registra el total'), findsOneWidget);
    expect(find.text('50×12'), findsOneWidget);
    expect(find.text('RIR 2'), findsOneWidget);
    expect(find.text('20 · 30 · 40 kg/lado'), findsOneWidget);

    // Se escribe un lado (60) y se registra el total (120).
    final card = find.ancestor(of: find.text('Prensa de piernas'), matching: find.byType(Card));
    await tester.enterText(find.descendant(of: card, matching: find.byType(TextField)).first, '60');
    await tester.pump();
    final log = store.active!.exercises.first;
    expect(log.sets.first.weightKg, 120);
    expect(find.text('total 120 kg'), findsOneWidget);

    // El campo del peso queda alineado con los de reps y RIR de la misma fila.
    final fields = find.descendant(of: card, matching: find.byType(TextField));
    final weightBox = tester.getRect(fields.at(0));
    expect(tester.getRect(fields.at(1)).center.dy, closeTo(weightBox.center.dy, 0.5));
    expect(tester.getRect(fields.at(2)).center.dy, closeTo(weightBox.center.dy, 0.5));
    expect(tester.getRect(fields.at(1)).height, closeTo(weightBox.height, 0.5));
    expect(find.text('24 · 36 · 48 kg/lado'), findsOneWidget);

    // Marcar una serie vacía copia la anterior (100 kg total → se ve 50).
    await tester.tap(find.byTooltip('Completar serie').at(1));
    await tester.pump();
    expect(log.sets[1].weightKg, 100);
    expect(find.text('total 100 kg'), findsOneWidget);

    // El ejercicio normal sigue igual.
    final curl = find.ancestor(of: find.text('Curl femoral'), matching: find.byType(Card));
    await tester.scrollUntilVisible(curl, 200, scrollable: find.byType(Scrollable).first);
    expect(find.descendant(of: curl, matching: find.text('kg')), findsOneWidget);

    store.discardActive();
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('la gráfica explica cómo leerla', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final store = await _newStore();
    store.restoreBackup(AppStore.readBackup(_backupV120));
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.text('Pierna A'))).push(MaterialPageRoute(
        builder: (_) => const ProgressScreen(exerciseName: 'Prensa de piernas')));
    await tester.pumpAndSettle();

    // Debajo de la gráfica solo está el botón «?»; la explicación no ocupa la pantalla.
    expect(find.text('¿Cómo leer esta gráfica?'), findsOneWidget);
    expect(find.byIcon(Icons.help_outline), findsOneWidget);
    expect(find.text('Vas bien'), findsNothing);

    // Al tocarlo se abre la ventana flotante.
    await tester.tap(find.text('¿Cómo leer esta gráfica?'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.textContaining('Tu lectura ahora'), findsOneWidget);
    expect(find.text('Qué mide: 1RM estimado'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Ojo, revisa'), 200,
        scrollable: find.descendant(of: find.byType(Dialog), matching: find.byType(Scrollable)));
    expect(find.text('Vas bien'), findsOneWidget);

    // Se cierra con la X.
    await tester.tap(find.byTooltip('Cerrar'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);

    // Cambia con la métrica.
    await tester.tap(find.text('Volumen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('¿Cómo leer esta gráfica?'));
    await tester.pumpAndSettle();
    expect(find.text('Qué mide: Volumen'), findsOneWidget);
  });
}
