import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/pad.dart';

class AudioService extends ChangeNotifier {
  static final AudioService instance = AudioService._internal();
  AudioService._internal();

  final Map<int, AudioPlayer> _players = {};
  final Map<int, List<StreamSubscription>> _trimSubs = {};
  final Set<int> _playingPositions = {};
  bool _isDisposed = false;

  /// Currently playing pad positions (for UI indicators)
  Set<int> get playingPositions => Set.unmodifiable(_playingPositions);

  bool isPlaying(int position) => _playingPositions.contains(position);

  /// Play a pad with its saved settings (volume, playbackRate, loop, trim)
  Future<void> playPad(Pad pad) async {
    if (_isDisposed || pad.audioPath == null || pad.audioPath!.isEmpty) return;

    final position = pad.position;
    _players.putIfAbsent(position, () => AudioPlayer());
    final player = _players[position]!;

    // Clear any previous trim watchers for this pad
    await _cancelTrim(position);

    try {
      await player.stop();

      await player.setVolume(pad.volume.clamp(0.0, 1.0));
      await player.setPlaybackRate(pad.playbackRate.clamp(0.5, 2.0));

      if (pad.hasTrim) {
        // Trecho cortado: gerenciamos início, fim e loop manualmente
        await player.setReleaseMode(ReleaseMode.stop);
        await player.play(DeviceFileSource(pad.audioPath!));
        if (pad.startMs > 0) {
          await player.seek(Duration(milliseconds: pad.startMs));
        }

        final subs = <StreamSubscription>[];

        // Para no fim do trecho (ou volta pro início se for loop)
        if (pad.endMs > 0) {
          subs.add(player.onPositionChanged.listen((pos) async {
            if (pos.inMilliseconds >= pad.endMs) {
              if (pad.isLoop) {
                await player.seek(Duration(milliseconds: pad.startMs));
              } else {
                await stop(position);
              }
            }
          }));
        }

        // Loop quando o áudio termina naturalmente (endMs == 0) → reinicia o trecho
        if (pad.isLoop) {
          subs.add(player.onPlayerComplete.listen((_) async {
            await player.seek(Duration(milliseconds: pad.startMs));
            await player.resume();
          }));
        }

        _trimSubs[position] = subs;
      } else {
        // Sem corte: comportamento simples
        await player.setReleaseMode(
          pad.isLoop ? ReleaseMode.loop : ReleaseMode.stop,
        );
        await player.play(DeviceFileSource(pad.audioPath!));
      }

      _playingPositions.add(position);
      notifyListeners();
    } catch (e) {
      debugPrint('Error playing pad ${pad.name} (pos $position): $e');
    }
  }

  Future<void> _cancelTrim(int position) async {
    final subs = _trimSubs.remove(position);
    if (subs != null) {
      for (final s in subs) {
        await s.cancel();
      }
    }
  }

  Future<void> stop(int position) async {
    await _cancelTrim(position);
    if (_players.containsKey(position)) {
      await _players[position]!.stop();
      _playingPositions.remove(position);
      notifyListeners();
    }
  }

  Future<void> stopAll() async {
    for (final pos in _trimSubs.keys.toList()) {
      await _cancelTrim(pos);
    }
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

  /// Lê a duração de um arquivo de áudio (para a régua de corte).
  Future<Duration?> getAudioDuration(String path) async {
    final p = AudioPlayer();
    try {
      final c = Completer<Duration?>();
      final sub = p.onDurationChanged.listen((d) {
        if (!c.isCompleted) c.complete(d);
      });
      await p.setSourceDeviceFile(path);
      Duration? d = await c.future.timeout(
        const Duration(seconds: 3),
        onTimeout: () => null,
      );
      d ??= await p.getDuration();
      await sub.cancel();
      return d;
    } catch (_) {
      return null;
    } finally {
      await p.dispose();
    }
  }

  Future<void> dispose() async {
    _isDisposed = true;
    for (final pos in _trimSubs.keys.toList()) {
      await _cancelTrim(pos);
    }
    _playingPositions.clear();
    for (final player in _players.values) {
      await player.dispose();
    }
    _players.clear();
  }
}
