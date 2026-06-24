import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../models/pad.dart';
import '../services/database_service.dart';
import '../services/file_service.dart';
import '../services/audio_service.dart';

class EditPadScreen extends StatefulWidget {
  final Pad pad;

  const EditPadScreen({super.key, required this.pad});

  @override
  State<EditPadScreen> createState() => _EditPadScreenState();
}

class _EditPadScreenState extends State<EditPadScreen> {
  late TextEditingController _nameController;
  String? _imagePath;
  String? _audioPath;
  late int _color;

  // v0.2 audio settings
  late double _volume;
  late double _playbackRate;
  late bool _isLoop;

  final AudioService _audioService = AudioService.instance;
  final FileService _fileService = FileService.instance;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.pad.name);
    _imagePath = widget.pad.imagePath;
    _audioPath = widget.pad.audioPath;
    _color = widget.pad.color;

    // Load audio settings
    _volume = widget.pad.volume;
    _playbackRate = widget.pad.playbackRate;
    _isLoop = widget.pad.isLoop;

    // Live preview when typing name
    _nameController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final newPath = await _fileService.pickAndCopyImage();
    if (newPath != null) {
      setState(() {
        _imagePath = newPath;
      });
    }
  }

  Future<void> _pickAudio() async {
    final newPath = await _fileService.pickAndCopyAudio();
    if (newPath != null) {
      setState(() {
        _audioPath = newPath;
      });
    }
  }

  Future<void> _removeImage() async {
    // Optionally delete old file, but skip for v0.1
    setState(() {
      _imagePath = null;
    });
  }

  Future<void> _removeAudio() async {
    setState(() {
      _audioPath = null;
    });
  }

  /// Test playback using the current slider values (without saving)
  Future<void> _testPlayAudioWithSettings() async {
    if (_audioPath == null || _audioPath!.isEmpty) return;

    // Create a temporary pad with current settings for testing
    final tempPad = widget.pad.copyWith(
      audioPath: _audioPath,
      volume: _volume,
      playbackRate: _playbackRate,
      isLoop: _isLoop,
    );

    await _audioService.playPad(tempPad);
  }

  Future<void> _pickColor() async {
    Color pickerColor = Color(_color);

    await showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('Escolher Cor do Pad'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: pickerColor,
              onColorChanged: (Color color) {
                pickerColor = color;
              },
              enableAlpha: false,
              labelTypes: const [],
              pickerAreaHeightPercent: 0.75,
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            ElevatedButton(
              child: const Text('Selecionar'),
              onPressed: () {
                setState(() {
                  _color = pickerColor.value;
                });
                Navigator.of(ctx).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _savePad() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('O nome do pad não pode estar vazio')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final updatedPad = widget.pad.copyWith(
      name: name,
      imagePath: _imagePath,
      audioPath: _audioPath,
      color: _color,
      volume: _volume,
      playbackRate: _playbackRate,
      isLoop: _isLoop,
    );

    await DatabaseService.instance.savePad(updatedPad);

    setState(() => _isSaving = false);

    if (mounted) {
      Navigator.pop(context, true); // Signal that pad was updated
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = _imagePath != null && _imagePath!.isNotEmpty;
    final hasAudio = _audioPath != null && _audioPath!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text('Editar ${widget.pad.name}'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _savePad,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('SALVAR', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Preview
            Center(
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  color: Color(_color),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  image: hasImage
                      ? DecorationImage(
                          image: ResizeImage(FileImage(File(_imagePath!)), width: 320),
                          fit: BoxFit.cover,
                          colorFilter: ColorFilter.mode(
                            Colors.black.withOpacity(0.3),
                            BlendMode.darken,
                          ),
                        )
                      : null,
                ),
                child: Center(
                  child: Text(
                    _nameController.text.trim().isEmpty ? 'Pad' : _nameController.text.trim(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(blurRadius: 8, color: Colors.black87)],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Nome
            const Text('Nome do Pad', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                hintText: 'Ex: Kick, Snare, Vocal Hook...',
                prefixIcon: Icon(Icons.label_rounded),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 28),

            // Imagem
            const Text('Imagem (Opcional)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (hasImage)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(_imagePath!),
                      height: 140,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      cacheHeight: 320,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton.filled(
                      style: IconButton.styleFrom(backgroundColor: Colors.black54),
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                      onPressed: _removeImage,
                    ),
                  ),
                ],
              )
            else
              OutlinedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.image_outlined),
                label: const Text('Selecionar Imagem da Galeria'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
            const SizedBox(height: 24),

            // Áudio
            const Text('Áudio (Opcional)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (hasAudio)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.audiotrack_rounded, color: Color(0xFF00BCD4)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Áudio selecionado', style: TextStyle(fontSize: 13, color: Colors.white70)),
                          Text(
                            _audioPath!.split('/').last,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.play_circle_filled_rounded, color: Color(0xFF00BCD4), size: 32),
                      onPressed: _testPlayAudioWithSettings,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                      onPressed: _removeAudio,
                    ),
                  ],
                ),
              )
            else
              OutlinedButton.icon(
                onPressed: _pickAudio,
                icon: const Icon(Icons.audiotrack_outlined),
                label: const Text('Selecionar Áudio da Galeria'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
            const SizedBox(height: 24),

            // Cor
            const Text('Cor do Pad', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Color(_color),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24, width: 2),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickColor,
                    icon: const Icon(Icons.color_lens_outlined),
                    label: const Text('Escolher Cor Personalizada'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // ==================== v0.2: Configurações de Áudio ====================
            const Text('Configurações de Reprodução', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),

            // Volume
            Row(
              children: [
                const Icon(Icons.volume_up_rounded, size: 20),
                const SizedBox(width: 8),
                const Text('Volume', style: TextStyle(fontWeight: FontWeight.w500)),
                const Spacer(),
                Text('${(_volume * 100).round()}%', style: const TextStyle(color: Colors.white70)),
              ],
            ),
            Slider(
              value: _volume,
              min: 0.0,
              max: 1.0,
              divisions: 20,
              label: '${(_volume * 100).round()}%',
              onChanged: (val) => setState(() => _volume = val),
            ),

            const SizedBox(height: 12),

            // Playback Rate (Pitch/Speed)
            Row(
              children: [
                const Icon(Icons.speed_rounded, size: 20),
                const SizedBox(width: 8),
                const Text('Velocidade / Pitch', style: TextStyle(fontWeight: FontWeight.w500)),
                const Spacer(),
                Text('${_playbackRate.toStringAsFixed(1)}x', style: const TextStyle(color: Colors.white70)),
              ],
            ),
            Slider(
              value: _playbackRate,
              min: 0.5,
              max: 2.0,
              divisions: 15,
              label: '${_playbackRate.toStringAsFixed(1)}x',
              onChanged: (val) => setState(() => _playbackRate = val),
            ),
            const SizedBox(height: 4),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('0.5x (mais grave)', style: TextStyle(fontSize: 11, color: Colors.white38)),
                Text('2.0x (mais agudo)', style: TextStyle(fontSize: 11, color: Colors.white38)),
              ],
            ),

            const SizedBox(height: 16),

            // Loop toggle
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: SwitchListTile(
                title: const Text('Loop (repetir continuamente)'),
                subtitle: const Text('O áudio toca em loop até parar manualmente'),
                value: _isLoop,
                onChanged: (val) => setState(() => _isLoop = val),
                secondary: const Icon(Icons.repeat_rounded),
                activeColor: const Color(0xFF7C4DFF),
              ),
            ),

            const SizedBox(height: 24),

            // Quick test button
            if (_audioPath != null && _audioPath!.isNotEmpty)
              OutlinedButton.icon(
                onPressed: _testPlayAudioWithSettings,
                icon: const Icon(Icons.play_circle_outline_rounded),
                label: const Text('Testar com estas configurações'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),

            const SizedBox(height: 32),

            // Save button big
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _savePad,
                icon: const Icon(Icons.save_rounded),
                label: Text(_isSaving ? 'Salvando...' : 'Salvar Alterações'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
