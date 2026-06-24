import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/project.dart';
import '../models/pad.dart';
import '../services/database_service.dart';
import '../services/audio_service.dart';
import '../widgets/pad_widget.dart';

class StageModeScreen extends StatefulWidget {
  final Project project;

  const StageModeScreen({super.key, required this.project});

  @override
  State<StageModeScreen> createState() => _StageModeScreenState();
}

class _StageModeScreenState extends State<StageModeScreen> {
  List<Pad> _pads = [];
  bool _isLoading = true;
  final AudioService _audioService = AudioService.instance;

  @override
  void initState() {
    super.initState();
    // Force landscape for stage mode
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _loadPads();
    _audioService.addListener(_onAudioStateChanged);
  }

  @override
  void dispose() {
    _audioService.removeListener(_onAudioStateChanged);
    // Restore portrait when leaving
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  void _onAudioStateChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadPads() async {
    setState(() => _isLoading = true);
    final pads = await DatabaseService.instance.getPadsForProject(widget.project.id!);
    setState(() {
      _pads = pads;
      _isLoading = false;
    });
  }

  Future<void> _playPad(Pad pad) async {
    if (pad.audioPath != null && pad.audioPath!.isNotEmpty) {
      // If already playing and looping → stop it (very useful in live performance)
      if (_audioService.isPlaying(pad.position) && pad.isLoop) {
        await _audioService.stop(pad.position);
      } else {
        await _audioService.playPad(pad);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sem áudio em "${pad.name}"'),
            duration: const Duration(milliseconds: 800),
          ),
        );
      }
    }
  }

  Future<void> _stopAll() async {
    await _audioService.stopAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(widget.project.name, style: const TextStyle(fontSize: 18)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.stop_circle_outlined, size: 28),
            onPressed: _stopAll,
            tooltip: 'Parar todos',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  // Compact Now Playing + Fade Out in Stage Mode (performance critical)
                  if (_audioService.playingPositions.isNotEmpty)
                    Container(
                      height: 42,
                      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.graphic_eq_rounded, color: Colors.redAccent, size: 18),
                          const SizedBox(width: 8),
                          Text('${_audioService.playingPositions.length} tocando',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () => _audioService.fadeOutAll(),
                            icon: const Icon(Icons.volume_down_rounded, size: 18),
                            label: const Text('FADE OUT',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.orangeAccent,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Pad grid — sized to fit the screen (no scroll, no overflow)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          const cols = 4;
                          const spacing = 12.0;
                          final rows = (_pads.length / cols).ceil().clamp(1, 99);

                          final cellW = (constraints.maxWidth - spacing * (cols - 1)) / cols;
                          final cellH = (constraints.maxHeight - spacing * (rows - 1)) / rows;
                          final aspect = cellH > 0 ? cellW / cellH : 1.0;

                          return GridView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: cols,
                              crossAxisSpacing: spacing,
                              mainAxisSpacing: spacing,
                              childAspectRatio: aspect,
                            ),
                            itemCount: _pads.length,
                            itemBuilder: (context, index) {
                              final pad = _pads[index];
                              final isCurrentlyPlaying = _audioService.isPlaying(pad.position);
                              return PadWidget(
                                pad: pad,
                                onTap: () => _playPad(pad),
                                onEdit: null,
                                onStop: isCurrentlyPlaying
                                    ? () => _audioService.stop(pad.position)
                                    : null,
                                isLarge: true,
                                isPlaying: isCurrentlyPlaying,
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _stopAll,
                  icon: const Icon(Icons.stop_rounded),
                  label: const Text('PARAR TUDO'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // PANIC button - essential for live performance
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await _audioService.stopAll();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('PANIC! Todos os áudios parados'),
                          backgroundColor: Colors.redAccent,
                          duration: Duration(milliseconds: 900),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.warning_amber_rounded),
                  label: const Text('PANIC'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
