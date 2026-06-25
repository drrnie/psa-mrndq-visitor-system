// lib/services/audio_service.dart
//
// Plays the two kiosk chime tones:
//   • ding  — played when a QR scan routes to check-in
//   • dong  — played when a QR scan routes to check-out
//
// Failures are swallowed silently so audio never crashes the kiosk.

import 'package:audioplayers/audioplayers.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final _player = AudioPlayer();

  Future<void> playDing() => _play('audio/ding.wav');
  Future<void> playDong() => _play('audio/dong.wav');

  /// Easter egg — played after 5 consecutive invalid QR scans.
  Future<void> playFahhh() => _play('audio/fahhh.mp3');

  Future<void> _play(String asset) async {
    try {
      await _player.stop();
      await _player.play(AssetSource(asset));
    } catch (_) {
      // Audio must never crash the kiosk — fail silently.
    }
  }
}