# 🎵 Metrónomo

Metrónomo profesional para músicos con motor de audio nativo C++, soporte para birritmia, tuplets, subdivisiones complejas y visualización en tiempo real.

## ✨ Características

### 🔊 Motor de Audio
- **Engine nativo C++** — Timing ultra-preciso con [miniaudio](https://miniaud.io/) y procesamiento DSP con [SoundTouch](https://www.surina.net/soundtouch/)
- **Sets de Sonidos Sintéticos** — Generación procedural en Dart de clicks clásicos, Woodblock (FM synthesis) y Digital (Square waves)
- **Silencios al Azar** — Simulación interna en el loop de renderizado C++ con RNG hardware-level (`std::mt19937`) para entrenar el timing interno
- **Pipeline de audio atómica** — Posición de reproducción sincronizada con `std::atomic` para visualización sin latencia

### 🎼 Patrones Rítmicos
- **Multi-patrón simultáneo** — Ejecutá múltiples patrones rítmicos en paralelo, cada uno con su propia estructura y volumen
- **Birritmia** — Patrones preconfigurados de 3/4 contra 6/8 para práctica de poliritmia
- **Notación de tuplets** — Sintaxis flexible `A:B/C` (ej: `2:3/3` = 2 pulsos en tiempo de 3, cada uno subdividido en 3)
- **Subdivisiones con acentos** — Cada subdivisión soporta 4 niveles: Alto (rojo), Bajo (naranja), Medio (verde) y Silencio
- **Límites seguros** — Máximo 32 pulsos por grupo, 12 subdivisiones por pulso, 64 pulsos totales por patrón

### 🎛️ Controles
- **Tap Tempo** — Detecta el BPM tocando rítmicamente (promedio de últimos 4 taps, auto-reset a los 2s)
- **Rango BPM amplio** — De 1 a 999 BPM con slider logarítmico de 3 zonas para precisión en rangos musicales
- **Ajuste fino** — Botones de ±1 y ±5 BPM para control preciso
- **Por patrón** — Volumen (knob rotativo), Mute (M) y Solo (S) individuales por cada instancia

### 📊 Visualización
- **Macro Ciclo** — Visualizador matricial que muestra todos los patrones alineados al MCM de sus duraciones
- **Playhead 60fps** — Cursor de reproducción animado con `Ticker` + `ValueNotifier` (sin rebuilds innecesarios)
- **Secuenciador responsivo** — Grilla de pulsos con auto-wrap a 2-3 filas cuando el espacio es limitado
- **Estructura formateada** — Display estilo fracción (numerador/denominador) para subdivisiones

### ⌨️ Teclado Métrico
- Teclado numérico custom con teclas `+`, `/`, `:` para ingresar estructuras rítmicas
- Edición en vivo — El patrón se actualiza mientras se escribe
- Límite de 2 dígitos consecutivos por slot numérico

### 🎨 Diseño y UI
- **Tema oscuro premium** — Paleta cálida con fondo `#1E1A17` y acento naranja `#F98533`
- **Soporte dual tema** — Colores adaptativos para dark y light mode
- **Knob rotativo custom** — `CustomPainter` con indicador de posición, reset por doble tap y sensibilidad ajustada
- **Escala de UI ajustable** — Soporte para zoom manual in/out desde la configuración (80% al 150%)
- **Orientación fija** — Solo portrait para UX optimizada

### ⚙️ Configuración y Persistencia
- **Reproducción en Segundo Plano** — Gestión inteligente del ciclo de vida (`WidgetsBindingObserver`) que permite que la app continúe sonando al minimizarla o apagarse (si el usuario así lo decide)
- **Mantener Pantalla Encendida** — Integración nativa con `wakelock_plus` para evitar bloqueos del dispositivo durante ensayos y prácticas
- **Storage persistente** — Guardado automático de configuraciones, sets y patrones vía `shared_preferences`

## 📐 Arquitectura

```
lib/
├── main.dart                          # Entry point, tema Material3 y Provider
├── constants/
│   └── app_colors.dart                # Paleta de colores adaptativa dark/light
├── providers/
│   └── metronome_provider.dart        # Estado global, parser de estructuras, tap tempo, macro ciclo
├── screens/
│   └── metronome_screen.dart          # UI: secuenciador, controles, visualizador, teclado custom
└── widgets/
    └── knob_control.dart              # Control rotativo con CustomPainter

packages/native_audio_engine/
├── lib/
│   ├── live_mixer.dart                # API pública (export condicional por plataforma)
│   ├── live_mixer_native.dart         # Implementación FFI (Android/iOS/Windows)
│   ├── live_mixer_web.dart            # Implementación Web Audio API
│   ├── live_mixer_bindings.dart       # Bindings FFI generados para C++
│   ├── soundtouch_bindings.dart       # Bindings FFI para SoundTouch
│   └── soundtouch_processor.dart      # Wrapper Dart para pitch shifting
└── src/
    ├── live_mixer.cpp                 # Engine C++ (~44KB): scheduling, mixing, metrónomo
    ├── live_mixer.h                   # Header con API C exportada
    ├── miniaudio.h                    # Librería de audio multiplataforma
    ├── soundtouch_wrapper.cpp         # Wrapper C para SoundTouch
    ├── Vocoder.cpp/h                  # Procesador vocoder con KissFFT
    ├── kiss_fft.c/h                   # FFT para procesamiento espectral
    └── soundtouch/                    # Librería SoundTouch (pitch/tempo)
```

## 🎶 Notación de Estructuras Métricas

| Notación | Significado | Uso musical |
|----------|-------------|-------------|
| `4` | 4 pulsos simples | Compás de 4/4 |
| `3/2` | 3 pulsos, cada uno subdividido en 2 | 3/4 con corcheas |
| `3+2` | Grupo de 3 + grupo de 2 | Compás asimétrico 5/4 |
| `2:3/3` | 2 pulsos en tiempo de 3, subdivididos en 3 | Birritmia tipo 6/8 |
| `3/2+2:3/3` | Combinación de ambos | 3/4 vs 6/8 simultáneo |

### Cómo funciona el parser

1. Se separa por `+` en grupos independientes
2. Cada grupo se evalúa como `[count][:ratio][/subdivision]`
3. Si hay `ratio`, la duración de cada pulso es `ratio / count` beats
4. Si no hay `ratio`, cada pulso dura 1 beat
5. Las subdivisiones generan sub-celdas con acentos automáticos (1° del grupo = primario, resto = secundario)

## 🛠️ Stack Tecnológico

| Componente | Tecnología |
|-----------|------------|
| Framework | Flutter 3.10+ (Material3) |
| Estado | Provider (ChangeNotifier) |
| Audio Engine | C++ con miniaudio (callback-based) |
| DSP | SoundTouch (pitch/tempo shifting) |
| FFT | KissFFT (procesamiento espectral) |
| FFI | dart:ffi (nativo) / Web Audio API (web) |
| Rendering | CustomPainter (knobs), Ticker (animaciones) |
| Plataformas | Android, iOS, Windows, Web |

## 🚀 Build

```bash
# Desarrollo
flutter run

# Release Android (AAB para Play Store)
flutter build appbundle --release

# Release APK
flutter build apk --release

# Windows
flutter build windows --release

# Web (requiere compilación WASM del engine)
# Ver packages/native_audio_engine/build_wasm.bat
flutter build web --release
```

## 📋 Requisitos

- Flutter SDK ≥ 3.10.4
- Dart SDK ≥ 3.10.4
- Android: minSdk 24 (Android 7.0+)
- iOS: 13.0+
- CMake (para compilar el engine nativo C++)
- Emscripten (solo para build web)

## 📄 Licencia

Proyecto privado — © Saroo
