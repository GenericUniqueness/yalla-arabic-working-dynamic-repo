import 'package:just_audio/just_audio.dart';

const _pronunciationR2Base =
    'https://pub-9071b083f7474a3083519acf9f8e8dbe.r2.dev';

class PronunciationAudioService {
  final AudioPlayer _player = AudioPlayer();

  static String normaliseLookupKey(String raw) {
    return raw
        .toLowerCase()
        // Normalise curly/smart apostrophes to straight apostrophe so that
        // "he’s" looks up the same audio file as "he's".
        .replaceAll('‘', "'")
        .replaceAll('’', "'")
        .replaceAll(RegExp(r'[.,!?;:]'), '')
        .replaceAll(RegExp(r"^'+|'+$"), '')
        .trim();
  }

  static String pronunciationUrl(String rawWord) {
    final key = normaliseLookupKey(rawWord);
    return '$_pronunciationR2Base/assets/pronunciation/$key.opus';
  }

  Future<bool> play(String rawWord, {double speed = 1.0}) async {
    final key = normaliseLookupKey(rawWord);
    if (key.isEmpty) return false;
    try {
      await _player.stop();
      await _player.setUrl(pronunciationUrl(key));
      await _player.setSpeed(speed.clamp(0.5, 1.0).toDouble());
      await _player.play();
      await _player.playerStateStream
          .firstWhere((s) => s.processingState == ProcessingState.completed)
          .timeout(const Duration(seconds: 8));
      return true;
    } catch (_) {
      try {
        await _player.stop();
      } catch (_) {}
      return false;
    }
  }

  void dispose() {
    _player.dispose();
  }
}
