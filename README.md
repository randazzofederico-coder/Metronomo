# 🎵 Metrónomo

Metrónomo profesional para músicos con motor de audio nativo C++, soporte para birritmia, tuplets y subdivisiones complejas.

## Características

- **Motor de audio nativo C++** — Timing preciso con [miniaudio](https://miniaud.io/) y procesamiento DSP con [SoundTouch](https://www.surina.net/soundtouch/)
- **Multi-patrón** — Ejecutá múltiples patrones rítmicos simultáneamente (ej: 3/4 vs 6/8)
- **Birritmia** — Patrones preconfigurados de 3/4 contra 6/8 para práctica de poliritmia
- **Notación de tuplets** — Sintaxis flexible `A:B/C` (ej: `2:3/3` = 2 pulsos en tiempo de 3, cada uno subdividido en 3)
- **Subdivisiones** — Cada pulso puede subdividirse con acentos independientes (alto, bajo, medio, silencio)
- **Tap Tempo** — Detecta el BPM tocando el botón rítmicamente
- **Rango BPM** — De 1 a 999 BPM con slider logarítmico para precisión en rangos musicales comunes
- **Controles por patrón** — Volumen, Mute (M) y Solo (S) individuales por cada instancia
- **Visualizador de macro ciclo** — Muestra el progreso del ciclo combinado de todos los patrones en tiempo real
- **Teclado métrico personalizado** — Teclado numérico diseñado para ingresar estructuras rítmicas con `+`, `:`, `/`
- **Tema oscuro premium** — Paleta cálida (#1E1A17 fondo, #F98533 acento naranja)

## Arquitectura

```
lib/
├── main.dart                          # Entry point, tema y providers
├── constants/
│   └── app_colors.dart                # Paleta de colores con soporte dark/light
├── providers/
│   └── metronome_provider.dart        # Estado global, parsing de estructuras, tap tempo
├── screens/
│   └── metronome_screen.dart          # UI principal: secuenciador, controles, visualizador
└── widgets/
    └── knob_control.dart              # Control rotativo custom con CustomPainter

packages/native_audio_engine/
├── lib/
│   ├── live_mixer.dart                # API pública del mixer
│   ├── live_mixer_native.dart         # Implementación FFI (Android/iOS/Windows)
│   └── live_mixer_web.dart            # Implementación Web Audio API
└── src/
    ├── live_mixer.cpp                 # Engine C++ (~44KB): scheduling, mixing, metrónomo
    ├── live_mixer.h                   # Header del engine
    ├── miniaudio.h                    # Librería de audio multiplataforma
    ├── soundtouch_wrapper.cpp         # Wrapper para pitch shifting
    └── soundtouch/                    # Librería SoundTouch
```

## Notación de Estructuras Métricas

| Notación | Significado | Ejemplo |
|----------|------------|---------|
| `4` | 4 pulsos simples | Compás de 4/4 |
| `3/2` | 3 pulsos, cada uno subdividido en 2 | Compás de 3/4 con corcheas |
| `3+2` | Grupo de 3 + grupo de 2 | Compás asimétrico 5/4 |
| `2:3/3` | 2 pulsos en tiempo de 3, subdivididos en 3 | Birritmia 6/8 |
| `3/2+2:3/3` | Combinación compleja | 3/4 vs 6/8 simultáneo |

## Stack Tecnológico

| Componente | Tecnología |
|-----------|-----------|
| Framework | Flutter 3.10+ |
| Audio Engine | C++ con miniaudio |
| DSP | SoundTouch |
| FFI | dart:ffi (nativo) / Web Audio API (web) |
| Estado | Provider (ChangeNotifier) |
| Plataformas | Android, iOS, Windows, Web |

## Build

```bash
# Desarrollo
flutter run

# Release Android (AAB para Play Store)
flutter build appbundle --release

# Release APK
flutter build apk --release
```

## Requisitos

- Flutter SDK >= 3.10.4
- Android: minSdk 24 (Android 7.0+)
- iOS: 13.0+
- CMake (para compilar el engine nativo)

## Licencia

Proyecto privado — © Saroo
