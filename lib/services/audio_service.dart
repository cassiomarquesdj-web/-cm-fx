import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/pad.dart';
import '../models/fx_type.dart';

class AudioService extends ChangeNotifier {
  static final AudioService instance = AudioService._internal();
  AudioService._internal();

  final Map<int, AudioPlayer> _players = {};
  final Map<int, List<StreamSubscription>> _trimSubs = {};
  final Set<int> _playingPositions = {};
  bool _isDisposed = false;

  // Banco de FX: players extras para ecos + timers das animações de efeito
  final List<AudioPlayer> _fxPool = [];
  final List<Timer> _fxTimers = [];

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

  /// Toca uma vinheta aplicando um efeito do banco de FX.
  Future<void> playPadWithFx(Pad pad, FxType fx) async {
    if (_isDisposed || pad.audioPath == null || pad.audioPath!.isEmpty) return;
    _clearFxTimers();
    final path = pad.audioPath!;
    final start = pad.startMs;
    final vol = pad.volume.clamp(0.0, 1.0);

    switch (fx) {
      case FxType.pitch:
        // Sobe o tom (e a velocidade junto, limitação do motor atual)
        await playPad(pad.copyWith(
          playbackRate: (pad.playbackRate * 1.4).clamp(0.5, 2.0),
        ));
        break;

      case FxType.delay:
        // Eco de DJ: o som seco + repetições decrescentes
        await playPad(pad);
        _echoTap(path, startMs: start, volume: vol * 0.55, rate: pad.playbackRate, delayMs: 240, slot: 0);
        _echoTap(path, startMs: start, volume: vol * 0.32, rate: pad.playbackRate, delayMs: 480, slot: 1);
        _echoTap(path, startMs: start, volume: vol * 0.18, rate: pad.playbackRate, delayMs: 720, slot: 2);
        break;

      case FxType.reverb:
        // Ambiência (aproximação): micro-ecos curtos e baixos formando uma cauda
        await playPad(pad);
        const offsets = [60, 110, 165, 225, 300, 390];
        for (int i = 0; i < offsets.length; i++) {
          final v = (vol * (0.22 - i * 0.028)).clamp(0.03, 0.22);
          _echoTap(path, startMs: start, volume: v, rate: pad.playbackRate, delayMs: offsets[i], slot: i);
        }
        break;

      case FxType.scroll:
        // Sweep/riser: começa grave e sobe o tom (build-up)
        await playPad(pad.copyWith(playbackRate: 0.7));
        final p1 = _players[pad.position];
        if (p1 != null) {
          double rate = 0.7;
          _fxTimers.add(Timer.periodic(const Duration(milliseconds: 60), (t) async {
            rate += 0.05;
            if (rate >= 1.6) {
              rate = 1.6;
              t.cancel();
            }
            try {
              await p1.setPlaybackRate(rate);
            } catch (_) {}
          }));
        }
        break;

      case FxType.stutter:
        // Repique/gate: retrigger rápido do início do trecho
        await playPad(pad);
        final p2 = _players[pad.position];
        if (p2 != null) {
          int count = 0;
          _fxTimers.add(Timer.periodic(const Duration(milliseconds: 95), (t) async {
            count++;
            if (count > 6) {
              t.cancel();
              return;
            }
            try {
              await p2.seek(Duration(milliseconds: start));
            } catch (_) {}
          }));
        }
        break;
    }
  }

  void _clearFxTimers() {
    for (final t in _fxTimers) {
      t.cancel();
    }
    _fxTimers.clear();
  }

  Future<void> _stopFxPool() async {
    for (final p in _fxPool) {
      try {
        await p.stop();
      } catch (_) {}
    }
  }

  Future<void> _echoTap(
    String path, {
    required int startMs,
    required double volume,
    required double rate,
    required int delayMs,
    required int slot,
  }) async {
    _fxTimers.add(Timer(Duration(milliseconds: delayMs), () async {
      try {
        while (_fxPool.length <= slot) {
          _fxPool.add(AudioPlayer());
        }
        final p = _fxPool[slot];
        await p.stop();
        await p.setReleaseMode(ReleaseMode.stop);
        await p.setVolume(volume.clamp(0.0, 1.0));
        await p.setPlaybackRate(rate.clamp(0.5, 2.0));
        await p.play(DeviceFileSource(path));
        if (startMs > 0) {
          await p.seek(Duration(milliseconds: startMs));
        }
      } catch (_) {}
    }));
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
    _clearFxTimers();
    await _stopFxPool();
    await _cancelTrim(position);
    if (_players.containsKey(position)) {
      await _players[position]!.stop();
      _playingPositions.remove(position);
      notifyListeners();
    }
  }

  Future<void> stopAll() async {
    _clearFxTimers();
    await _stopFxPool();
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
    _clearFxTimers();
    for (final p in _fxPool) {
      await p.dispose();
    }
    _fxPool.clear();
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
