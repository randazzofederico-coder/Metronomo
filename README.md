# 🎵 Metrónomo

Metrónomo profesional para músicos con motor de audio nativo C++, soporte para birritmia, tuplets, subdivisiones complejas y visualización en tiempo real.

## ✨ Características

### 🔊 Motor de Audio
- **Engine nativo C++** — Timing ultra-preciso con [miniaudio](https://miniaud.io/) y procesamiento DSP con [SoundTouch](https://www.surina.net/soundtouch/)
- **Sample Rate Dinámico** — El engine detecta y adopta automáticamente la frecuencia de muestreo del dispositivo (44.1kHz, 48kHz, etc.) garantizando sincronización perfecta en cualquier hardware, tanto en nativo (vía miniaudio) como en PWA (vía AudioWorklet `sampleRate`)
- **Sets de Sonidos Sintéticos** — Generación procedural en Dart de clicks clásicos, Woodblock (FM synthesis) y Digital (Square waves)
- **Silencios al Azar** — Simulación interna en el loop de renderizado C++ con RNG hardware-level (`std::mt19937`) para entrenar el timing interno. Funcional en todas las plataformas incluyendo PWA (exportado a WASM via `_live_mixer_set_random_silence_percent`)
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
- **Escala de UI ajustable** — Zoom manual desde configuración (80% al 150%). Los controles de precisión (secuenciador, barra BPM, teclado métrico, knobs, macro ciclo) mantienen tamaño fijo vía `TextScaler.noScaling` para evitar desborde, mientras que títulos, diálogos y ajustes escalan normalmente
- **Orientación fija** — Solo portrait para UX optimizada

### ⚙️ Configuración y Persistencia
- **Reproducción en Segundo Plano** — Activada por defecto. Gestión inteligente del ciclo de vida (`WidgetsBindingObserver` con `paused`/`hidden`/`inactive`) que permite que la app continúe sonando al minimizarla. Si el usuario desactiva la opción, el metrónomo se detiene automáticamente al perder foco
- **Mantener Pantalla Encendida** — Activada por defecto. Integración nativa con `wakelock_plus` para evitar bloqueos del dispositivo durante ensayos y prácticas
- **Storage persistente** — Guardado automático de configuraciones, sets y patrones vía `shared_preferences`

### ☁️ Cloud & Autenticación
- **Firebase Auth** — Sistema de autenticación integrado con Google Sign-In y Email/Password.
- **Sincronización Multiplataforma** — Los usuarios comparten la misma cuenta en las versiones Web, Android y iOS.
- **Control de Acceso** — Verificación de permisos basada en Firestore.

### 🔗 Compartir Sesiones y Patrones (Deep Links)
- **Compartir via Deep Link** — Sesiones y patrones se comparten con URLs limpias tipo `federicorandazzo.com.ar/metronomo/?share=xk9mp2nq&name=chacarera` respaldadas por Firestore
- **Exportación inteligente** — Al compartir una sesión, se empaquetan automáticamente todos los patrones referenciados como un bundle completo
- **Importación automática** — Al abrir un link compartido, la app detecta el parámetro `?share=`, descarga los datos de Firestore, genera IDs nuevos (para evitar colisiones) y los guarda en la biblioteca local
- **Limpieza de URL** — Después de importar, el parámetro `?share=` se elimina de la barra de direcciones con `history.replaceState` para evitar re-importaciones al refrescar
- **Share nativo** — Integración con la Web Share API / share sheet nativo del OS con fallback a clipboard
- **Firestore como backend de links** — Colección `shared_links` con lectura pública y escritura autenticada

### 🌐 Web & PWA
- **Soporte Web Completo** — La aplicación es accesible desde cualquier navegador moderno.
- **WebAssembly (WASM)** — El motor de audio C++ está compilado a WASM usando Emscripten para correr de forma nativa en la web con mínima latencia y soporte de Web Audio API.
- **Progressive Web App (PWA)** — Instalable desde el navegador con un botón dedicado en configuración, con soporte para uso offline.
- **AudioWorklet Bridge** — Comunicación completa Dart → JS → WASM para todas las funciones del engine (metrónomo, silencios al azar, sound sets, patterns) vía `postMessage` comandos tipados

### 💾 Gestión de Estado y Flujo de Trabajo
- **Seguimiento 'Dirty State'** — Detección automática y profunda de alteraciones en vivo (BPM, estructuras, faders, mute/solo). La UI reacciona orgánicamente a los cambios pendientes marcando las sesiones y patrones en cursiva con un asterisco (`*`).
- **Edición Dinámica de Patrones** — Renombrado in-situ de pistas con cajas delimitadas dinámicamente (`IntrinsicWidth`) y tracking visual milimétrico del asterisco de edición.
- **Guardado Inteligente** — Discriminación contextual en la App Bar: sistema de guardado rápido para sobrescribir (pisar) datos modificados, o "Guardar Como..." (`Uuid().v4()`) para versionado de bibliotecas limpias.
- **Aislamiento de Periféricos (Gestos y Foco)** —
  - **Foco Seguro**: Prevención estricta de superposición de teclados (Android Nativo vs Numérico Métrico) purgando la jerarquía de foco antes de despachar diálogos modales. Visibilidad garantizada vía `Scrollable.ensureVisible`.
  - **Arena de Gestos de Alta Precisión**: Controladores The perillas (Knobs) con monopolio asertivo sobre los arreglos `onVerticalDragUpdate` y `onHorizontalDragUpdate`. Esto neutraliza el reconocedor nativo del `ListView`, inhibiendo el scroll inercial padre mientras se manipulan los parámetros de mezcla.

## 📐 Arquitectura

```
lib/
├── main.dart                          # Entry point, tema Material3 y Provider
├── constants/
│   └── app_colors.dart                # Paleta de colores adaptativa dark/light
├── models/
│   ├── pattern_model.dart             # Modelo de patrón rítmico (estructura, pulsos, subdivisiones)
│   └── session_model.dart             # Modelo de sesión (patrones, BPM, configuración de mezcla)
├── providers/
│   ├── metronome_provider.dart        # Estado global, parser de estructuras, tap tempo, macro ciclo
│   ├── settings_provider.dart         # Configuración persistente (sonido, silencio, UI scale)
│   ├── pattern_editor_provider.dart   # CRUD de la biblioteca de patrones
│   └── session_provider.dart          # CRUD de la biblioteca de sesiones
├── screens/
│   ├── metronome_screen.dart          # UI: secuenciador, controles, visualizador, teclado custom
│   ├── auth_gate.dart                 # Gate de autenticación y verificación de permisos
│   ├── login_screen.dart              # Pantalla de login (Google/Email)
│   ├── onboarding_screen.dart         # Onboarding para nuevos usuarios
│   └── settings_screen.dart           # Pantalla de configuración
├── services/
│   ├── deep_link_service.dart         # Compartir via deep links (Firestore + Web Share API)
│   ├── deep_link_web.dart             # JS interop: lectura/limpieza de URL (?share=)
│   ├── deep_link_stub.dart            # Stub para plataformas no-web
│   ├── pwa_install_service.dart       # Servicio de instalación PWA
│   ├── pwa_install_web.dart           # JS interop: beforeinstallprompt
│   ├── pwa_install_stub.dart          # Stub para plataformas no-web
│   ├── pattern_repository.dart        # Persistencia de patrones (SharedPreferences)
│   └── session_repository.dart        # Persistencia de sesiones (SharedPreferences)
└── widgets/
    └── knob_control.dart              # Control rotativo con CustomPainter

packages/native_audio_engine/
├── lib/
│   ├── live_mixer.dart                # API pública (export condicional por plataforma)
│   ├── live_mixer_native.dart         # Implementación FFI (Android/iOS/Windows) — sampleRate fijo 44100
│   ├── live_mixer_web.dart            # Implementación Web Audio API — sampleRate dinámico del AudioContext
│   ├── live_mixer_bindings.dart       # Bindings FFI generados para C++ (acepta sampleRate)
│   ├── soundtouch_bindings.dart       # Bindings FFI para SoundTouch
│   └── soundtouch_processor.dart      # Wrapper Dart para pitch shifting
└── src/
    ├── live_mixer.cpp                 # Engine C++ (~44KB): scheduling, mixing, metrónomo (sampleRate paramétrico)
    ├── live_mixer.h                   # Header con API C exportada (_engineSampleRate)
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
| Audio Engine | C++ con miniaudio (callback-based) / WASM |
| DSP | SoundTouch (pitch/tempo shifting) |
| FFT | KissFFT (procesamiento espectral) |
| FFI | dart:ffi (nativo) / Web Audio API (web) |
| Backend y Auth | Firebase Auth, Cloud Firestore |
| Web Build | Emscripten, JS Interop |
| Rendering | CustomPainter (knobs), Ticker (animaciones) |
| Plataformas | Android, iOS, Windows, Web (PWA) |

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
