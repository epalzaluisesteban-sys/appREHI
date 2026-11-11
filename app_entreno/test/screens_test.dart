import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:registro_entreno/export.dart';
import 'package:registro_entreno/main.dart';
import 'package:registro_entreno/models.dart';
import 'package:registro_entreno/screens/progress_screen.dart';
import 'package:registro_entreno/screens/workout_screen.dart';
import 'package:registro_entreno/store.dart';
import 'package:registro_entreno/theme.dart';
import 'package:registro_entreno/widgets/rehi_logo.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppStore> _storeWithData() async {
  SharedPreferences.setMockInitialValues({});
  await initializeDateFormatting('es');
  final store = AppStore(await SharedPreferences.getInstance());
  final routine = Routine(
    name: 'Torso-Pierna',
    split: 'torso_pierna',
    daysPerWeek: 4,
    days: [
      for (final n in splitByKey('torso_pierna').dayNames(4)) RoutineDay(name: n),
    ],
  );
  routine.days.first.exercises.addAll([
    PlannedExercise(name: 'Press banca inclinado con mancuernas', sets: 3, restSeconds: 150),
    PlannedExercise(name: 'Remo con barra', sets: 4),
  ]);
  store.addRoutine(routine);
  // Dos sesiones pasadas para la gráfica.
  for (final (date, kg) in [(DateTime(2026, 10, 27), 30.0), (DateTime(2026, 11, 3), 32.5)]) {
    final s = store.startSession(routine, routine.days.first, date: date);
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

Widget _app(AppStore store, Widget home) => ChangeNotifierProvider.value(
      value: store,
      child: Builder(builder: (_) => const EntrenoApp()),
    );

void main() {
  testWidgets('crear rutina no genera días automáticamente', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting('es');
    final store = AppStore(await SharedPreferences.getInstance());
    await tester.pumpWidget(_app(store, const SizedBox()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Nueva rutina'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Mi rutina');
    await tester.tap(find.text('Crear rutina'));
    await tester.pumpAndSettle();

    final r = store.routines.single;
    expect(r.name, 'Mi rutina');
    expect(r.days, isEmpty);
    expect(find.textContaining('frecuencia'), findsNothing);
  });

  testWidgets('cambiar el color actualiza el tema', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting('es');
    final store = AppStore(await SharedPreferences.getInstance());
    await tester.pumpWidget(_app(store, const SizedBox()));
    await tester.pumpAndSettle();

    store.setPalette('pizarra');
    await tester.pumpAndSettle();
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    final ctx = tester.element(find.byWidget(scaffold));
    expect(Theme.of(ctx).scaffoldBackgroundColor, paletteById('pizarra').background);
  });

  testWidgets('el logo cambia de color al instante', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting('es');
    final store = AppStore(await SharedPreferences.getInstance());
    await tester.pumpWidget(_app(store, const SizedBox()));
    await tester.pumpAndSettle();

    RehiLogoPainter logoPainter() => tester
        .widget<CustomPaint>(find.descendant(
          of: find.byType(RehiLogo),
          matching: find.byType(CustomPaint),
        ))
        .painter! as RehiLogoPainter;

    expect(logoPainter().palette.id, 'rojo');
    for (final id in ['salvia', 'grafito']) {
      store.setPalette(id);
      await tester.pump();
      expect(logoPainter().palette.id, id);
    }
  });

  testWidgets('ajustes: exportar y copia de seguridad', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = await _storeWithData();
    await tester.pumpWidget(_app(store, const SizedBox()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Ajustes'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Restaurar copia'), 200);
    expect(find.text('Exportar a Excel'), findsOneWidget);
    expect(find.text('Aún no has guardado ninguna copia'), findsOneWidget);

    await tester.tap(find.text('Exportar a PDF'));
    await tester.pumpAndSettle();
    expect(find.text('2 entrenamientos · pesos en kg'), findsOneWidget);
    // El resultado depende de la fecha de hoy: se compara con el filtro real.
    await tester.tap(find.text('30 días'));
    await tester.pumpAndSettle();
    final n = sessionsInPeriod(store, ExportPeriod.last30).length;
    expect(
      find.text(n == 0
          ? 'No hay entrenamientos en este periodo.'
          : '$n entrenamiento${n == 1 ? '' : 's'} · pesos en kg'),
      findsOneWidget,
    );
    expect(find.text('Guardar'), findsOneWidget);
    expect(find.text('Compartir'), findsOneWidget);
  });

  testWidgets('aproximaciones: se configuran y se ven al entrenar', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final store = await _storeWithData();
    await tester.pumpWidget(_app(store, const SizedBox()));
    await tester.pumpAndSettle();
    final routine = store.routines.single;
    final day = routine.days.first;

    // Activar en el editor del ejercicio (3 series: 40, 60, 80 %) y agregar una cuarta.
    await tester.tap(find.text('Torso A'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remo con barra'));
    await tester.pumpAndSettle();
    final sw = find.text('Calcular series de aproximación');
    await tester.scrollUntilVisible(sw, 200, scrollable: find.byType(Scrollable).last);
    await tester.tap(sw);
    await tester.pumpAndSettle();
    expect(find.text('80 %'), findsOneWidget);
    final more = find.descendant(
      of: find.ancestor(of: find.text('Series de aproximación'), matching: find.byType(Row)),
      matching: find.byTooltip('Más'),
    );
    await tester.ensureVisible(more);
    await tester.tap(more);
    await tester.pumpAndSettle();
    expect(find.text('Aproximación 4'), findsOneWidget);
    expect(find.text('90 %'), findsOneWidget);
    await tester.ensureVisible(find.text('Guardar ejercicio'));
    await tester.tap(find.text('Guardar ejercicio'));
    await tester.pumpAndSettle();
    expect(day.exercises.last.warmupPercents, [40, 60, 80, 90]);
    expect(day.exercises.first.hasWarmup, isFalse);
    expect(find.textContaining('Aproximación: 40 · 60 · 80 · 90 %'), findsOneWidget);

    // En el entrenamiento solo el remo muestra los pesos (base: 32.5 kg de la vez anterior).
    startWorkoutFlow(tester.element(find.byType(Scaffold).last), routine, day);
    await tester.pumpAndSettle();
    expect(find.text('Aproximación'), findsOneWidget);
    expect(find.text('13 · 20 · 26 · 29 kg'), findsOneWidget);

    // Al escribir un peso de trabajo más alto se recalcula al instante.
    final remoCard = find.ancestor(of: find.text('Remo con barra'), matching: find.byType(Card));
    await tester.scrollUntilVisible(remoCard, 200, scrollable: find.byType(Scrollable).first);
    await tester.enterText(
        find.descendant(of: remoCard, matching: find.byType(TextField)).first, '50');
    await tester.pump();
    expect(find.text('20 · 30 · 40 · 45 kg'), findsOneWidget);

    store.discardActive();
    await tester.pump(const Duration(seconds: 1));
  });

  for (final size in [const Size(360, 780), const Size(1280, 800)]) {
    testWidgets('pantallas sin desbordes a ${size.width.toInt()} px', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final store = await _storeWithData();
      await tester.pumpWidget(_app(store, const SizedBox()));
      await tester.pumpAndSettle();

      // Pantalla principal con la rutina y sus 4 días.
      expect(find.text('Torso A'), findsOneWidget);
      expect(find.text('Pierna B'), findsOneWidget);

      // Iniciar entrenamiento: series programadas y fila "anterior".
      final ctx = tester.element(find.text('Torso A'));
      final routine = store.routines.single;
      startWorkoutFlow(ctx, routine, routine.days.first);
      await tester.pumpAndSettle();
      expect(find.byType(WorkoutScreen), findsOneWidget);
      expect(find.text('32.5×10 @2'), findsWidgets);
      // El encabezado "Serie" cabe en una sola línea (antes la "e" bajaba).
      expect(tester.getSize(find.text('Serie').first).height, lessThan(20));

      // Completar una serie vacía usa los valores anteriores y lanza el descanso.
      await tester.tap(find.byTooltip('Completar serie').first);
      await tester.pump();
      expect(store.active!.exercises.first.sets.first.done, isTrue);
      expect(store.active!.exercises.first.sets.first.weightKg, 32.5);
      expect(find.text('Descanso'), findsOneWidget);
      expect(find.text('2:30'), findsWidgets);

      // Gráfica de progreso en libras.
      store.setUnit(WeightUnit.lb);
      await tester.pump();
      Navigator.of(tester.element(find.byType(WorkoutScreen))).push(MaterialPageRoute(
          builder: (_) => const ProgressScreen(exerciseName: 'Remo con barra')));
      await tester.pumpAndSettle();
      expect(find.text('1RM estimado'), findsOneWidget);
      expect(find.text('¿Cómo leer esta gráfica?'), findsOneWidget);
      // El historial queda debajo de la explicación de la gráfica.
      await tester.scrollUntilVisible(find.text('HISTORIAL'), 300,
          scrollable: find.byType(Scrollable).last);
      expect(find.text('HISTORIAL'), findsOneWidget);
      expect(find.textContaining('lb'), findsWidgets);

      store.discardActive();
      await tester.pump(const Duration(seconds: 10));
    });
  }
}
