/// Tipos de efeito do banco de FX.
/// Aplicados na próxima vinheta disparada (arma o FX, toca a vinheta).
enum FxType {
  pitch,
  delay,
  reverb,
  scroll,
  stutter,
}

extension FxTypeInfo on FxType {
  String get label {
    switch (this) {
      case FxType.pitch:
        return 'PITCH';
      case FxType.delay:
        return 'DELAY';
      case FxType.reverb:
        return 'REVERB';
      case FxType.scroll:
        return 'SCROLL';
      case FxType.stutter:
        return 'STUTTER';
    }
  }
}
