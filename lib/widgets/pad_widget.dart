import 'dart:io';
import 'package:flutter/material.dart';
import '../models/pad.dart';

class PadWidget extends StatelessWidget {
  final Pad pad;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onStop; // Stop this specific pad (shown when playing)
  final bool isLarge;
  final bool isPlaying; // Shows glowing + playing indicator

  const PadWidget({
    super.key,
    required this.pad,
    required this.onTap,
    this.onEdit,
    this.onStop,
    this.isLarge = false,
    this.isPlaying = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = pad.imagePath != null && pad.imagePath!.isNotEmpty;
    final hasAudio = pad.audioPath != null && pad.audioPath!.isNotEmpty;
    final textColor = Colors.white;
    final fontSize = isLarge ? 16.0 : 11.0;
    final iconSize = isLarge ? 28.0 : 18.0;

    // Dynamic glow when playing (makes the app feel alive during performance)
    final glowColor = isPlaying ? Colors.white.withOpacity(0.6) : Colors.black.withOpacity(0.4);
    final glowBlur = isPlaying ? (isLarge ? 28.0 : 18.0) : (isLarge ? 12.0 : 6.0);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onEdit,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: Color(pad.color),
          borderRadius: BorderRadius.circular(isLarge ? 20 : 14),
          border: isPlaying
              ? Border.all(color: Colors.white.withOpacity(0.85), width: isLarge ? 3.5 : 2.5)
              : null,
          boxShadow: [
            BoxShadow(
              color: glowColor,
              blurRadius: glowBlur,
              spreadRadius: isPlaying ? 1.5 : 0,
              offset: const Offset(0, 4),
            ),
            if (isPlaying)
              BoxShadow(
                color: Color(pad.color).withOpacity(0.6),
                blurRadius: isLarge ? 20 : 12,
                spreadRadius: 2,
              ),
          ],
          image: hasImage
              ? DecorationImage(
                  image: ResizeImage(FileImage(File(pad.imagePath!)), width: 360),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Colors.black.withOpacity(0.35),
                    BlendMode.darken,
                  ),
                )
              : null,
        ),
        child: Stack(
          children: [
            // Center content
            Center(
              child: Padding(
                padding: EdgeInsets.all(isLarge ? 12 : 6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (hasAudio)
                      Icon(
                        Icons.music_note_rounded,
                        color: textColor.withOpacity(0.9),
                        size: iconSize,
                      ),
                    const SizedBox(height: 4),
                    Text(
                      pad.name,
                      textAlign: TextAlign.center,
                      maxLines: isLarge ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textColor,
                        fontSize: fontSize,
                        fontWeight: FontWeight.w700,
                        shadows: const [
                          Shadow(
                            blurRadius: 6,
                            color: Colors.black87,
                            offset: Offset(1, 1),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // === Status indicators (makes the app much more usable) ===
            // Top-left: Playing indicator + Stop button
            if (isPlaying)
              Positioned(
                top: 6,
                left: 6,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 15,
                      ),
                    ),
                    if (onStop != null)
                      const SizedBox(width: 4),
                    if (onStop != null)
                      GestureDetector(
                        onTap: onStop,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Icons.stop_rounded,
                            color: Colors.white,
                            size: 15,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

            // Top-right: Edit button (only in normal mode)
            if (onEdit != null && !isLarge)
              Positioned(
                top: 6,
                right: 6,
                child: GestureDetector(
                  onTap: onEdit,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.edit_rounded,
                      size: 14,
                      color: textColor.withOpacity(0.9),
                    ),
                  ),
                ),
              ),

            // Bottom indicators row (loop + pitch + volume deviation)
            if (hasAudio)
              Positioned(
                bottom: 6,
                left: 6,
                right: 6,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Loop indicator
                    if (pad.isLoop)
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.repeat_rounded, size: 13, color: Colors.white),
                      ),

                    // Pitch indicator (only if not 1.0x)
                    if (pad.playbackRate != 1.0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${pad.playbackRate.toStringAsFixed(1)}x',
                          style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                      ),

                    // Volume indicator (only if significantly different from 100%)
                    if (pad.volume < 0.95)
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          pad.volume < 0.3 ? Icons.volume_mute_rounded : Icons.volume_down_rounded,
                          size: 13,
                          color: Colors.white,
                        ),
                      ),
                  ],
                ),
              ),

            // Large mode bottom hint
            if (isLarge && hasAudio && !isPlaying)
              Positioned(
                bottom: 8,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'TOQUE PARA REPRODUZIR',
                      style: TextStyle(
                        color: textColor.withOpacity(0.85),
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
