import 'package:flutter/material.dart';
import '../models/fx_type.dart';

/// Trilha de efeitos. Toque um FX para "armar" (acende),
/// depois toque uma vinheta para tocar com o efeito.
class FxRail extends StatelessWidget {
  final FxType? armed;
  final ValueChanged<FxType?> onSelect;

  const FxRail({super.key, required this.armed, required this.onSelect});

  IconData _icon(FxType fx) {
    switch (fx) {
      case FxType.pitch:
        return Icons.graphic_eq_rounded;
      case FxType.delay:
        return Icons.surround_sound_rounded;
      case FxType.reverb:
        return Icons.blur_on_rounded;
      case FxType.scroll:
        return Icons.trending_up_rounded;
      case FxType.stutter:
        return Icons.flash_on_rounded;
    }
  }

  Color _color(FxType fx) {
    switch (fx) {
      case FxType.pitch:
        return const Color(0xFF7C4DFF);
      case FxType.delay:
        return const Color(0xFF00BCD4);
      case FxType.reverb:
        return const Color(0xFF26C6DA);
      case FxType.scroll:
        return const Color(0xFFFFB300);
      case FxType.stutter:
        return const Color(0xFFEC407A);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            armed == null ? 'EFEITOS — toque um, depois a vinheta' : 'FX ARMADO: ${armed!.label}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: armed == null ? Colors.white38 : _color(armed!),
            ),
          ),
        ),
        Row(
          children: FxType.values.map((fx) {
            final isArmed = armed == fx;
            final c = _color(fx);
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: GestureDetector(
                  onTap: () => onSelect(isArmed ? null : fx),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: isArmed ? c.withOpacity(0.22) : const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isArmed ? c : Colors.white12,
                        width: isArmed ? 2 : 1,
                      ),
                      boxShadow: isArmed
                          ? [BoxShadow(color: c.withOpacity(0.5), blurRadius: 12, spreadRadius: 1)]
                          : null,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_icon(fx), size: 20, color: isArmed ? c : Colors.white60),
                        const SizedBox(height: 4),
                        Text(
                          fx.label,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                            color: isArmed ? Colors.white : Colors.white54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
