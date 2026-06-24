import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/pad.dart';

class AudioService extends ChangeNotifier {
  static final AudioService instance = AudioService._internal();
  AudioService._internal();

  final Map<int, AudioPlayer> _players = {};
  final Set<int> _playingPositions = {};
  bool _isDisposed = false;

  /// Currently playing pad positions (for UI indicators)
  Set<int> get playingPositions => Set.unmodifiable(_playingPositions);

  bool isPlaying(int position) => _playingPositions.contains(position);

  /// Play a pad with its saved settings (volume, playbackRate, loop)
  Future<void> playPad(Pad pad) async {
    if (_isDisposed || pad.audioPath == null || pad.audioPath!.isEmpty) return;

    final position = pad.position;

    if (!_players.containsKey(position)) {
      _players[position] = AudioPlayer();
    }

    final player = _players[position]!;

    try {
      await player.stop();

      // Apply per-pad settings (v0.2)
      await player.setVolume(pad.volume.clamp(0.0, 1.0));
      await player.setPlaybackRate(pad.playbackRate.clamp(0.5, 2.0));
      await player.setReleaseMode(
        pad.isLoop ? ReleaseMode.loop : ReleaseMode.stop,
      );

      await player.play(DeviceFileSource(pad.audioPath!));

      _playingPositions.add(position);
      notifyListeners();
    } catch (e) {
      debugPrint('Error playing pad ${pad.name} (pos $position): $e');
    }
  }

  Future<void> stop(int position) async {
    if (_players.containsKey(position)) {
      await _players[position]!.stop();
      _playingPositions.remove(position);
      notifyListeners();
    }
  }

  Future<void> stopAll() async {
    for (final player in _players.values) {
      await player.stop();
    }
    _playingPositions.clear();
    notifyListeners();
  }

  /// Smooth fade out all playing pads (professional DJ transition)
  Future<void> fadeOutAll({Duration duration = const Duration(milliseconds: 900)}) async {
    if (_playingPositions.isEmpty) return;

    const steps = 14;
    final stepDuration = Duration(milliseconds: (duration.inMilliseconds / steps).round());

    for (int i = steps; i >= 0; i--) {
      final vol = i / steps;
      for (final pos in List<int>.from(_playingPositions)) {
        if (_players.containsKey(pos)) {
          try {
            await _players[pos]!.setVolume(vol);
          } catch (_) {}
        }
      }
      await Future.delayed(stepDuration);
    }

    await stopAll();
  }

  Future<void> dispose() async {
    _isDisposed = true;
    _playingPositions.clear();
    for (final player in _players.values) {
      await player.dispose();
    }
    _players.clear();
  }
}

