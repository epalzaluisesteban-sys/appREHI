import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:registro_entreno/widgets/rest_timer.dart';

void main() {
  test('la alarma no pausa la música de otras apps', () {
    final ctx = AlarmSound.audioContext;
    // Foco temporal que solo baja el volumen de la música (no la pausa).
    expect(ctx.android.audioFocus, AndroidAudioFocus.gainTransientMayDuck);
    expect(ctx.android.audioFocus, isNot(AndroidAudioFocus.gain));
    // En iPhone se mezcla con la música en vez de interrumpirla.
    expect(ctx.iOS.options, contains(AVAudioSessionOptions.mixWithOthers));
  });
}
