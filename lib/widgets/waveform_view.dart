import 'package:flutter/material.dart';

/// Visualizador de waveform desenhado a partir de uma envoltória de amplitude.
/// A região fora do trecho [startFraction, endFraction] aparece esmaecida.
///
/// Obs: para arquivos comprimidos (mp3/m4a) a envoltória é uma aproximação
/// visual estável (não o PCM decodificado), suficiente como guia de corte.
class WaveformView extends StatelessWidget {
  final List<double> bars;
  final double startFraction; // 0..1
  final double endFraction; // 0..1
  final Color activeColor;
  final Color inactiveColor;
  final double height;

  const WaveformView({
    super.key,
    required this.bars,
    required this.startFraction,
    required this.endFraction,
    this.activeColor = const Color(0xFF00BCD4),
    this.inactiveColor = const Color(0xFF3A3A3A),
    this.height = 64,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _WavePainter(bars, startFraction, endFraction, activeColor, inactiveColor),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  final List<double> bars;
  final double startF;
  final double endF;
  final Color active;
  final Color inactive;

  _WavePainter(this.bars, this.startF, this.endF, this.active, this.inactive);

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty) return;
    final n = bars.length;
    const gap = 1.5;
    final barW = (size.width - gap * (n - 1)) / n;
    final mid = size.height / 2;
    final paintActive = Paint()..color = active;
    final paintInactive = Paint()..color = inactive;

    for (int i = 0; i < n; i++) {
      final frac = n > 1 ? i / (n - 1) : 0.0;
      final inRange = frac >= startF && frac <= endF;
      final h = (bars[i].clamp(0.0, 1.0)) * (size.height * 0.92);
      final x = i * (barW + gap);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, mid - h / 2, barW < 1 ? 1 : barW, h < 2 ? 2 : h),
        const Radius.circular(1.5),
      );
      canvas.drawRRect(rect, inRange ? paintActive : paintInactive);
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter old) =>
      old.startF != startF || old.endF != endF || old.bars != bars;
}
