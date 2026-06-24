class Pad {
  final int? id;
  final int projectId;
  final int position;
  final String name;
  final String? imagePath;
  final String? audioPath;
  final int color; // ARGB value

  // Audio playback settings
  final double volume;        // 0.0 to 1.0
  final double playbackRate;  // 0.5x to 2.0x (affects pitch and speed)
  final bool isLoop;          // whether to loop the audio

  // Trim / corte do áudio (v0.3.2) — em milissegundos
  final int startMs;          // onde o trecho começa
  final int endMs;            // onde o trecho termina (0 = até o fim do arquivo)

  Pad({
    this.id,
    required this.projectId,
    required this.position,
    required this.name,
    this.imagePath,
    this.audioPath,
    required this.color,
    this.volume = 1.0,
    this.playbackRate = 1.0,
    this.isLoop = false,
    this.startMs = 0,
    this.endMs = 0,
  });

  bool get hasTrim => startMs > 0 || endMs > 0;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'project_id': projectId,
      'position': position,
      'name': name,
      'image_path': imagePath,
      'audio_path': audioPath,
      'color': color,
      'volume': volume,
      'playback_rate': playbackRate,
      'is_loop': isLoop ? 1 : 0,
      'start_ms': startMs,
      'end_ms': endMs,
    };
  }

  factory Pad.fromMap(Map<String, dynamic> map) {
    return Pad(
      id: map['id'] as int?,
      projectId: map['project_id'] as int,
      position: map['position'] as int,
      name: map['name'] as String,
      imagePath: map['image_path'] as String?,
      audioPath: map['audio_path'] as String?,
      color: map['color'] as int,
      volume: (map['volume'] as num?)?.toDouble() ?? 1.0,
      playbackRate: (map['playback_rate'] as num?)?.toDouble() ?? 1.0,
      isLoop: (map['is_loop'] as int? ?? 0) == 1,
      startMs: (map['start_ms'] as int?) ?? 0,
      endMs: (map['end_ms'] as int?) ?? 0,
    );
  }

  Pad copyWith({
    int? id,
    int? projectId,
    int? position,
    String? name,
    String? imagePath,
    String? audioPath,
    int? color,
    double? volume,
    double? playbackRate,
    bool? isLoop,
    int? startMs,
    int? endMs,
  }) {
    return Pad(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      position: position ?? this.position,
      name: name ?? this.name,
      imagePath: imagePath ?? this.imagePath,
      audioPath: audioPath ?? this.audioPath,
      color: color ?? this.color,
      volume: volume ?? this.volume,
      playbackRate: playbackRate ?? this.playbackRate,
      isLoop: isLoop ?? this.isLoop,
      startMs: startMs ?? this.startMs,
      endMs: endMs ?? this.endMs,
    );
  }
}
