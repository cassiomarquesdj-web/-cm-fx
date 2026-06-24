import 'package:flutter/material.dart';
import '../models/project.dart';
import '../models/pad.dart';
import '../services/database_service.dart';
import '../services/audio_service.dart';
import '../widgets/pad_widget.dart';
import 'edit_pad_screen.dart';
import 'stage_mode_screen.dart';

class ProjectScreen extends StatefulWidget {
  final Project project;

  const ProjectScreen({super.key, required this.project});

  @override
  State<ProjectScreen> createState() => _ProjectScreenState();
}

class _ProjectScreenState extends State<ProjectScreen> {
  List<Pad> _pads = [];
  bool _isLoading = true;
  final AudioService _audioService = AudioService.instance;

  @override
  void initState() {
    super.initState();
    _loadPads();
    _audioService.addListener(_onAudioStateChanged);
  }

  @override
  void dispose() {
    _audioService.removeListener(_onAudioStateChanged);
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
            content: Text('Nenhum áudio atribuído ao "${pad.name}"'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }

  Future<void> _editPad(Pad pad) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditPadScreen(pad: pad),
      ),
    );

    if (updated == true) {
      await _loadPads();
    }
  }

  void _openStageMode() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StageModeScreen(project: widget.project),
      ),
    );
  }

  Future<void> _stopAllAudio() async {
    await _audioService.stopAll();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Todos os áudios parados'), duration: Duration(seconds: 1)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.project.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.stop_circle_outlined),
            tooltip: 'Parar todos os áudios',
            onPressed: _stopAllAudio,
          ),
          IconButton(
            icon: const Icon(Icons.fullscreen_rounded),
            tooltip: 'Modo Palco',
            onPressed: _openStageMode,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // === Now Playing Bar (very useful during performance) ===
                if (_audioService.playingPositions.isNotEmpty)
                  Container(
                    height: 52,
                    margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF7C4DFF).withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.graphic_eq_rounded, color: Color(0xFF7C4DFF), size: 20),
                        const SizedBox(width: 8),
                        const Text('Tocando agora:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: _pads
                                  .where((p) => _audioService.isPlaying(p.position))
                                  .map((playingPad) => Padding(
                                        padding: const EdgeInsets.only(right: 8),
                                        child: Chip(
                                          label: Text(
                                            playingPad.name,
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                          ),
                                          backgroundColor: Color(playingPad.color).withOpacity(0.85),
                                          labelStyle: const TextStyle(color: Colors.white),
                                          deleteIcon: const Icon(Icons.close_rounded, size: 16, color: Colors.white70),
                                          onDeleted: () => _audioService.stop(playingPad.position),
                                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                      ))
                                  .toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        const cols = 4;
                        const spacing = 10.0;
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
                              onEdit: () => _editPad(pad),
                              onStop: isCurrentlyPlaying ? () => _audioService.stop(pad.position) : null,
                              isLarge: false,
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
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _stopAllAudio,
                  icon: const Icon(Icons.stop_rounded),
                  label: const Text('PARAR TODOS',
                      style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _openStageMode,
                  icon: const Icon(Icons.fullscreen_rounded),
                  label: const Text('MODO PALCO',
                      style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
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
