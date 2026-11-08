import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import '../units.dart';

/// Sonido de alarma al terminar el descanso (assets/sounds/alarma.wav).
class AlarmSound {
  static AudioPlayer? _player;

  static Future<void> play() async {
    try {
      final p = _player ??= AudioPlayer()..setReleaseMode(ReleaseMode.stop);
      await p.stop();
      await p.play(AssetSource('sounds/alarma.wav'), volume: 1);
    } catch (e) {
      debugPrint('No se pudo reproducir la alarma: $e');
    }
  }
}

/// Temporizador de descanso. Calcula el tiempo restante a partir de la hora
/// de término, así no se desfasa si la app pasa a segundo plano.
class RestTimer extends ChangeNotifier {
  RestTimer({this.soundEnabled});

  /// Indica si debe sonar la alarma al terminar (ajuste del usuario).
  final bool Function()? soundEnabled;

  DateTime? _end;
  Timer? _ticker;
  Timer? _hideTimer;
  int total = 0;
  String label = '';
  bool finished = false;

  bool get visible => _end != null || finished;

  int get remaining {
    final end = _end;
    if (end == null) return 0;
    return max(0, (end.difference(DateTime.now()).inMilliseconds / 1000).ceil());
  }

  void start(int seconds, String label) {
    _hideTimer?.cancel();
    total = seconds;
    this.label = label;
    finished = false;
    _end = DateTime.now().add(Duration(seconds: seconds));
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) => _tick());
    notifyListeners();
  }

  void addSeconds(int s) {
    final end = _end;
    if (end == null) return;
    _end = end.add(Duration(seconds: s));
    if (remaining <= 0) {
      _complete();
      return;
    }
    total = max(total, remaining);
    notifyListeners();
  }

  void stop() {
    _ticker?.cancel();
    _hideTimer?.cancel();
    _end = null;
    finished = false;
    notifyListeners();
  }

  void _tick() {
    if (remaining <= 0) {
      _complete();
    } else {
      notifyListeners();
    }
  }

  void _complete() {
    _ticker?.cancel();
    _end = null;
    finished = true;
    HapticFeedback.heavyImpact();
    if (soundEnabled?.call() ?? true) AlarmSound.play();
    notifyListeners();
    _hideTimer = Timer(const Duration(seconds: 6), () {
      finished = false;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _hideTimer?.cancel();
    super.dispose();
  }
}

/// Barra inferior que muestra la cuenta regresiva del descanso.
class RestTimerBar extends StatelessWidget {
  const RestTimerBar({super.key, required this.timer});

  final RestTimer timer;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: timer,
        builder: (context, _) {
          if (!timer.visible) return const SizedBox.shrink();
          final rem = timer.remaining;
          final progress = timer.total == 0 ? 0.0 : rem / timer.total;
          return Material(
            color: timer.finished ? Colors.white : AppColors.header,
            elevation: 8,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                child: timer.finished
                    ? Row(
                        children: [
                          Icon(Icons.notifications_active, color: AppColors.background),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '¡Descanso terminado! A por la siguiente serie.',
                              style: TextStyle(
                                color: AppColors.background,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: timer.stop,
                            icon: Icon(Icons.close, color: AppColors.background),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          SizedBox(
                            width: 56,
                            height: 56,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox.expand(
                                  child: CircularProgressIndicator(
                                    value: progress,
                                    strokeWidth: 5,
                                    color: Colors.white,
                                    backgroundColor: const Color(0x33FFFFFF),
                                  ),
                                ),
                                Text(
                                  fmtRest(rem),
                                  style: const TextStyle(fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('Descanso',
                                    style: TextStyle(color: AppColors.muted, fontSize: 12)),
                                Text(
                                  timer.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () => timer.addSeconds(-15),
                            child: const Text('−15'),
                          ),
                          TextButton(
                            onPressed: () => timer.addSeconds(15),
                            child: const Text('+15'),
                          ),
                          IconButton(
                            tooltip: 'Saltar descanso',
                            onPressed: timer.stop,
                            icon: const Icon(Icons.skip_next),
                          ),
                        ],
                      ),
              ),
            ),
          );
        },
      );
}
