# CM FX - v0.3 (Pronto para Performance ao Vivo)

**Sistema de Performance de Áudio para DJs**  
by Marques Lab

App Flutter completo com **16 pads**, controle individual de **Volume + Pitch + Loop**, **Modo Palco** otimizado, **Now Playing** em tempo real, **Fade Out** suave e **Panic Button**.

## O que mudou nesta build (correção + leve)

**Correções que destravam o build do APK:**
- `stage_mode_screen.dart` estava com erro de sintaxe (declaração de variável dentro do construtor do `SizedBox` + `Column`/`SafeArea` sem fechar) — **não compilava**. Reescrito e o grid do Modo Palco agora se ajusta à tela sem overflow.
- `edit_pad_screen.dart` chamava `AudioService.play()`, um método que não existe mais (só existe `playPad`) — removido o método morto que causava erro de compilação.

**Mais leve (memória/runtime):**
- Imagens dos pads agora são decodificadas no tamanho de exibição (`ResizeImage` / `cacheHeight`) em vez de carregar a foto em resolução cheia. Evita estouro de memória com 16 pads usando fotos grandes — principal ganho de desempenho.
- `print()` trocado por `debugPrint()` (não polui o release).

**APK menor:** ver seção "Gerar o APK LEVE" abaixo (`--split-per-abi` + R8).

## Como Importar e Rodar (Passo a Passo)

### Opção 1 - Mais Fácil (Recomendada)

1. **Baixe** o arquivo `cm_fx_v0.3.zip` que foi gerado
2. Extraia a pasta `cm_fx`
3. Abra o terminal **dentro** da pasta `cm_fx` e rode:

```bash
flutter create .          # Gera as pastas android/ios (não sobrescreve seu código)
flutter pub get           # Instala as dependências
flutter run               # Roda no dispositivo/emulador
```

### Opção 2 - Se já tiver o Flutter

```bash
cd cm_fx
flutter create .
flutter pub get
flutter run
```

> **Dica**: Depois de rodar `flutter create .`, você pode abrir o projeto no **Android Studio** ou **VS Code** normalmente.

---

## Gerar o APK LEVE (release otimizado)

Depois do `flutter create .` + `flutter pub get`, gere o APK assim:

```bash
# APK separado por arquitetura (cada um ~8 MB em vez de ~20 MB num só)
flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/symbols
```

Os APKs saem em `build/app/outputs/flutter-apk/`:
- `app-arm64-v8a-release.apk` → use este na maioria dos celulares atuais
- `app-armeabi-v7a-release.apk` → aparelhos mais antigos (32 bits)
- `app-x86_64-release.apk` → emulador

> Se quiser um único APK que roda em qualquer aparelho (mais pesado), use só `flutter build apk --release`.

### Encolher ainda mais (minify + shrink resources)

Depois do `flutter create .`, abra `android/app/build.gradle` e dentro de `android { buildTypes { release { ... } } }` deixe assim:

```gradle
buildTypes {
    release {
        signingConfig signingConfigs.debug // troque pela sua chave ao publicar
        minifyEnabled true
        shrinkResources true
        proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
    }
}
```

Isso ativa o R8 (remove código/recursos não usados). Combinado com `--split-per-abi`, é o menor APK possível sem mexer no app.

---

## Funcionalidades da v0.3 (Melhorias para Palco)

- **Now Playing Bar** — Mostra todos os pads tocando no momento com chips coloridos
- **Fade Out All** — Transição suave de volume (botão no Modo Palco)
- **Stop individual** — Botão vermelho aparece automaticamente nos pads que estão tocando
- **Glowing pads** — Pads brilham quando estão reproduzindo
- **Indicadores visuais** — Ícones de Loop, Pitch e Volume baixo em cada pad
- **Tap inteligente** — Tocar novamente em pad com loop = para ele
- **Panic Button** — Botão grande vermelho para parar tudo instantaneamente
- Controle completo por pad: **Volume • Pitch (0.5x~2.0x) • Loop**
- Persistência total em SQLite + migração automática
- Tema escuro Material 3 com visual DJ profissional

---

## Como Usar (Fluxo Rápido)

1. Abra o app → **Novo Projeto**
2. Toque em um pad → **Editar**
3. Coloque um áudio + ajuste **Volume**, **Velocidade/Pitch** e **Loop**
4. Toque no pad para ouvir
5. Vá para **Modo Palco** (tela cheia horizontal)
6. Use o botão **FADE OUT** para transições suaves
7. Use o botão **PANIC** se precisar parar tudo rápido

---

## Observações Importantes

- Áudios e imagens são copiados para o armazenamento interno do app
- Funciona melhor em **dispositivo físico** (melhor latência de áudio)
- O app já tem tratamento de múltiplos áudios simultâneos
- Banco de dados migra automaticamente entre versões

---

Desenvolvido com Flutter + SQLite + audioplayers + file_picker  
**by Marques Lab — 2026**

## Permissões Android (Importante)

No arquivo `android/app/src/main/AndroidManifest.xml`, adicione dentro da tag `<manifest>`:

```xml
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
```

Para Android 13+ (API 33+), o `file_picker` geralmente usa o Photo Picker nativo e funciona bem sem permissões explícitas antigas. O código já inclui `permission_handler` caso precise solicitar em runtime.

## Estrutura do Projeto

```
lib/
├── main.dart                 # Entry point + inicialização DB
├── theme/
│   └── app_theme.dart        # Tema escuro Material 3
├── models/
│   ├── project.dart
│   └── pad.dart
├── services/
│   ├── database_service.dart # SQLite + CRUD completo
│   ├── audio_service.dart    # Singleton para reprodução multi-pad
│   └── file_service.dart     # Picker + cópia segura de arquivos
├── widgets/
│   ├── pad_widget.dart       # Widget reutilizável (normal + large/stage)
│   └── project_card.dart
└── screens/
    ├── home_screen.dart
    ├── project_screen.dart
    ├── edit_pad_screen.dart
    └── stage_mode_screen.dart
```

## Observações da v0.2

- Áudios e imagens são copiados para o diretório interno do app (`/data/data/.../files/`)
- Configurações de volume, pitch e loop são salvas por pad e aplicadas automaticamente na reprodução
- Modo Palco força orientação landscape e volta ao portrait ao sair
- Recomendado testar em dispositivo físico para melhor performance de áudio
- Migração de banco de dados é automática (ALTER TABLE)

## Próximos Passos Sugeridos (v0.3+)

- Sequencer / BPM sync com metronome visual
- Exportar projeto como ZIP
- Histórico de sets recentes + favoritos
- Integração com controladores MIDI (flutter_midi ou similar)
- Efeitos adicionais (fade, reverse, EQ básico)

---

Desenvolvido com Flutter + SQLite + audioplayers + file_picker  
by Marques Lab — 2026
