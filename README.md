# 🎵 Metrónomo

Metrónomo profesional para músicos con motor de audio nativo C++, soporte para birritmia, tuplets, subdivisiones complejas y visualización en tiempo real. Disponible como app nativa Android y como PWA instalable desde cualquier navegador moderno.

## ✨ Características

### 🔊 Motor de Audio
- **Engine nativo C++** — Timing ultra-preciso con [miniaudio](https://miniaud.io/) y procesamiento DSP con [SoundTouch](https://www.surina.net/soundtouch/)
- **Sample Rate Dinámico** — El engine detecta y adopta automáticamente la frecuencia de muestreo del dispositivo (44.1kHz, 48kHz, etc.) garantizando sincronización perfecta en cualquier hardware, tanto en nativo (vía miniaudio) como en PWA (vía AudioWorklet `sampleRate`)
- **7 Sets de Sonidos Sintéticos** — Generación procedural en Dart (`lib/audio/click_synth.dart`), cada set con 3 variantes (una por tipo de evento):

  | Set | Variantes | Síntesis |
  |-----|-----------|----------|
  | Clásico | agudo · grave · medio (2.5 / 1.5 / 1.9 kHz) | Transiente de ruido + cuerpo con 2 parciales |
  | Madera | agudo · grave · medio (1600 / 850 / 1150 Hz) | Woodblock modal (parciales inarmónicos 1 · 2.71 · 5.4) |
  | Claves | agudo · grave · medio (3 / 1.9 / 2.4 kHz) | Seno resonante con sustain + transiente |
  | Beep | agudo · grave · medio (2 / 1 / 1.5 kHz) | Armónicos impares (cuadrada suavizada) |
  | Hi-hat | abierto · semiabierto · cerrado | Estilo TR-808: 6 cuadradas inarmónicas + ruido filtrado |
  | Bombo | grave · medio · agudo (50 / 70 / 100 Hz) | Seno con barrido de pitch + *beater* agudo y saturación (para que se perciba en parlantes de celular) |
  | Redoblante | con bordona · sin bordona · aro | Parche modal + bordona (ruido filtrado) / cross-stick |

- **Diseño orientado a claridad** — Energía concentrada en 1.5–4 kHz (zona de máxima sensibilidad del oído y de los parlantes de celular), transiente para un ataque preciso, saturación suave (`tanh`) para subir el RMS sin subir el pico y normalización a −1 dBFS. Resultado: entre ~+8 y +16 dB de RMS respecto de los clicks senoidales anteriores (medido con el volumen por defecto). Los sonidos se generan al **sample rate real del engine** (ej. 48 kHz en la web) y los nombres viejos (Default / Woodblock / Digital) migran automáticamente a Clásico / Madera / Beep
- **Limitador suave en la salida** — Curva lineal hasta 0.8 y rodilla `tanh` hasta 1.0: permite eventos por encima del 100% y golpes superpuestos sin distorsión
- **Fade de re-disparo (3 ms)** — Si una voz se vuelve a disparar antes de terminar (ej. hi-hat abierto o bombo a tempo rápido), la cola anterior se desvanece en lugar de cortarse, evitando *pops*
- **Bancos de sonido (sonido por patrón)** — El engine tiene 16 bancos de 3 voces (`kMaxSoundBanks`); cada patrón (track de metrónomo) dispara las voces de su propio banco, así patrones simultáneos pueden sonar con sets distintos. Índice de banco = posición del set en `ClickSynth.soundSets`; cada banco se genera y carga de forma lazy la primera vez que se usa. API: `live_mixer_set_metronome_bank_sound(bank, slot, data)` y `live_mixer_set_metronome_pattern_sound_bank(id, bank)` (nativo y WASM). `live_mixer_set_metronome_sound` sigue existiendo como alias del banco 0
- **Silencios al Azar** — Simulación interna en el loop de renderizado C++ con RNG hardware-level (`std::mt19937`) para entrenar el timing interno. Funcional en todas las plataformas incluyendo PWA (exportado a WASM via `_live_mixer_set_random_silence_percent`)
- **Pipeline de audio atómica** — Posición de reproducción sincronizada con `std::atomic` para visualización sin latencia

### 🎼 Patrones Rítmicos
- **Multi-patrón simultáneo** — Ejecutá múltiples patrones rítmicos en paralelo, cada uno con su propia estructura y volumen
- **Birritmia** — Patrones preconfigurados de 3/4 contra 6/8 para práctica de poliritmia
- **Notación de tuplets** — Sintaxis flexible `A:B/C` (ej: `2:3/3` = 2 pulsos en tiempo de 3, cada uno subdividido en 3)
- **Subdivisiones con acentos** — Cada subdivisión soporta 4 estados identificados solo por color: rojo (acento), naranja (pulso), verde (subdivisión) y silencio
- **Volumen por golpe (0–150%)** — Cada evento tiene su propio volumen. Toque rápido = cambia el tipo de sonido; **mantener apretado** = entra en *modo volumen*: arrastrando hacia arriba sube y hacia abajo baja, en pasos de 5% (con feedback háptico). Una leyenda en la esquina inferior derecha muestra el % y la intensidad/saturación del color de cada evento refleja su volumen (en la grilla, el macro ciclo y el reproductor de playlists). El volumen final de un golpe es `volumen del patrón × volumen del evento`. Se persiste en patrones, sesiones y links compartidos solo cuando difiere de 100% (formato retrocompatible)
- **Límites seguros** — Máximo 32 pulsos por grupo, 12 subdivisiones por pulso, 64 pulsos totales por patrón

### 🎛️ Controles
- **Golpe actual resaltado** — Mientras suena, la celda del evento que está sonando se ilumina en cada patrón (y en el reproductor de playlists). Un único `Ticker` por pantalla (`widgets/playback_clock.dart`) publica la posición; cada grilla solo se redibuja cuando cambia el evento activo
- **Leyenda de golpes** — Debajo del ciclo macro: colores de Acento / Normal / Suave / Silencio y los gestos de edición de las celdas
- **Tap Tempo** — Detecta el BPM tocando rítmicamente (promedio de últimos 4 taps, auto-reset a los 2s)
- **Rango BPM amplio** — De 1 a 999 BPM con slider logarítmico de 3 zonas para precisión en rangos musicales
- **Ajuste fino** — Botones de ±1 y ±5 BPM (mantener apretado repite, acelerando). **Tocar el número de BPM** abre un diálogo para escribir el tempo exacto
- **Por patrón** — Volumen (knob rotativo), Mute (M) y Solo (S) individuales por cada instancia
- **Sonido por patrón** — Botón 🎵 junto a M/S en cada patrón: *Global* (sigue el sonido elegido en Configuración, valor por defecto) o cualquiera de los 7 sets. Un patrón con sonido propio muestra el botón resaltado en cyan. Es un atributo de la **sesión** (`SessionPatternConfig.soundSet`), no del patrón de la biblioteca: cambiarlo marca la sesión con `*` pero no el patrón. Se guarda en el estado de trabajo, en sesiones y en links compartidos (solo cuando difiere de *Global*, formato retrocompatible) y se conserva al entrar/salir del reproductor de playlists
- **Barra espaciadora = Play/Stop** — En el metrónomo y en el reproductor de playlists (mixin `SpacePlayShortcut`, `utils/space_play_shortcut.dart`). Usa `HardwareKeyboard.addHandler`, así no activa el botón que tenga foco. Se ignora mientras se escribe en un campo de texto o se edita una estructura, si hay un diálogo u otra pantalla encima (`ModalRoute.isCurrent`) o con modificadores (Ctrl/Alt/Shift/Meta); el auto-repeat no vuelve a alternar

### 📊 Visualización
- **Macro Ciclo** — Visualizador matricial que muestra todos los patrones alineados al MCM de sus duraciones
- **Playhead 60fps** — Cursor de reproducción animado con `Ticker` + `ValueNotifier` (sin rebuilds innecesarios)
- **Secuenciador responsivo** — Grilla de pulsos con auto-wrap a 2-3 filas cuando el espacio es limitado
- **Estructura formateada** — Display estilo fracción (numerador/denominador) para subdivisiones

### ⌨️ Teclado Métrico
- **Teclado físico + keypad en pantalla** — El campo de estructura es un `TextField` real con `TextInputType.none`: en PC se escribe directamente desde el teclado (cursor, selección, flechas, Supr, pegar) y en móvil no se abre el teclado del sistema, se usa el keypad propio
- **Keypad siempre visible durante la edición** — Teclas `0-9`, `+`, `/`, `:`, borrar y OK. Las teclas que producirían una estructura inválida se muestran atenuadas, así el keypad documenta la sintaxis
- **Layout adaptativo** — Desde 600 px de ancho el keypad es un popover compacto (232 px) anclado debajo del campo (`CompositedTransformFollower`) con la ayuda de atajos; en móvil es una barra inferior con ancho máximo de 480 px
- **Solo entradas válidas** — `StructureInputFormatter` (`utils/structure_input.dart`) filtra caracteres y secuencias imposibles (`++`, `+` inicial, `3:/`, `//`, ceros a la izquierda) y respeta los límites del parser (pulsos 1–32, ratio 1–64, subdivisión 1–12). Al pegar se descartan los espacios; borrar siempre está permitido. Teclado físico y keypad pasan por la misma validación
- **Commit al confirmar** — El patrón se recalcula solo al confirmar y solo si el valor cambió (no se pierden acentos editados a mano mientras se escribe). Un valor incompleto (`3+`, `3:`) se muestra en rojo y no se puede confirmar
- **Atajos** — `Enter` confirma · `Esc` cancela y restaura el valor original · `Tab` / `Shift+Tab` confirma y pasa al patrón siguiente/anterior · tocar fuera confirma (o revierte si está incompleto)

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
- **Firebase Auth** — Sistema de autenticación integrado con Google Sign-In y Email/Password
- **Sincronización Multiplataforma** — Los usuarios comparten la misma cuenta en las versiones Web, Android e iOS
- **Control de Acceso** — Verificación de permisos basada en Firestore con roles, trial y suscripciones
- **Período de Prueba** — Trial de 30 días activable por el usuario. Notificación automática al admin vía `consultas_web`
- **App libre (estado actual)** — El `AuthGate` está desactivado en `main.dart` (`home: MetronomeScreen`); el código de login/permisos se conserva para reactivarlo en el futuro. El único uso de Auth hoy es el **login anónimo** al compartir links
- **Usuarios reales vs anónimos** — Las reglas de Firestore distinguen cuentas reales (Google/Email) de sesiones anónimas (`sign_in_provider != 'anonymous'`): los anónimos solo pueden crear `shared_links`, nunca `usuarios` ni `consultas_web`

### 📴 Login Offline
- **Cache local de permisos** — Después del primer login exitoso, el estado de permisos se cachea en `SharedPreferences` con validez de 30 días
- **Acceso sin conexión** — Si no hay internet pero existe un cache válido, la app abre normalmente
- **Revalidación forzada** — Si el cache tiene más de 30 días, se requiere conexión a internet para revalidar
- **Banner de advertencia** — Cuando quedan ≤5 días para la expiración del cache, aparece un banner naranja gradiente con `wifi_off` indicando los días restantes
- **Pantalla "Conexión necesaria"** — Sin cache o con cache expirado, se muestra una pantalla dedicada con botón de reintentar y cerrar sesión
- **Lectura forzada del servidor** — `GetOptions(source: Source.server)` para evitar falsos positivos del cache interno de Firestore
- **Detección de errores de red** — String matching en `login_screen.dart` (sin `dart:io`, compatible web) para mostrar mensajes claros cuando no hay internet
- **Sección "Sesión" en Settings** — Fecha de última verificación online y contador de días restantes con indicadores de color (🟢 >5d, 🟠 ≤5d, 🔴 expirado)
- **Logout limpia el cache** — Al cerrar sesión se borran todos los datos de permisos cacheados

### 🔗 Compartir Sesiones y Patrones (Deep Links)
- **Compartir via Deep Link** — Sesiones, patrones y playlists se comparten con URLs limpias tipo `federicorandazzo.com.ar/metronomo/?share=xk9mp2nq&name=chacarera` respaldadas por Firestore
- **Exportación inteligente** — Las sesiones llevan sus patrones embebidos. Igual se envía la lista plana `patterns` para que versiones anteriores de la app puedan abrir links nuevos. Al importar una sesión/playlist sus patrones quedan dentro de la sesión (no se agregan a la librería de patrones); solo un *patrón* compartido va a la librería
- **Sheet de compartir unificado** (`widgets/share_sheet.dart`) — Genera el link con spinner y ofrece *Compartir en…* (share sheet nativo / Web Share API, disparado por un tap fresco para respetar la activación de usuario) y *Copiar link*. Errores siempre visibles con reintento
- **ID por contenido** — El ID del link es un hash SHA-256 (10 chars) del contenido + autor: compartir lo mismo dos veces reutiliza el mismo link
- **Login anónimo** — Para crear links se usa Firebase Anonymous Auth (lazy, solo al compartir). La cuenta anónima puede promoverse a cuenta formal con `linkWithCredential` conservando el `uid` (`ownerUid` del link)
- **Importación idempotente** (`services/share_import_service.dart`) — IDs locales derivados (UUID v5 de `shareId + idOriginal`): reabrir el mismo link no duplica nada; si el contenido es propio (mismo ID local) se reutiliza
- **Flujo al abrir** — Se importa a la biblioteca y se pregunta *¿Abrir ahora?*. Si la sesión actual tiene cambios sin guardar ofrece Guardar / Descartar / Cancelar. Patrón → sesión nueva con ese patrón; Sesión → se carga; Playlist → abre el reproductor
- **Android App Links** — Verificación de dominio via `assetlinks.json` con prioridad: app nativa (Play Store) → PWA instalada → versión web. Intent filter con `autoVerify="true"`; captura única del link inicial en `main.dart` + stream con deduplicación
- **PWA de escritorio** — `launch_handler: focus-existing` + `handle_links: preferred`; el link llega a la ventana abierta vía `launchQueue` (`web/index.html`)
- **Limpieza de URL** — Después de capturar el link, el parámetro `?share=` se elimina de la barra de direcciones con `history.replaceState` para evitar re-importaciones al refrescar
- **Firestore como backend de links** — Colección `shared_links` (schema v2: `type`, `name`, `ownerUid`, `summary`, `payload` JSON string, `createdAt`, `expiresAt`). Lectura pública por ID, creación autenticada (anónima o formal)
- **TTL (30 días)** — `expiresAt` se renueva con cada apertura. Como el proyecto está en plan Spark (sin TTL Policies), la limpieza es lazy desde el cliente: hasta 10 links vencidos al crear uno nuevo, y cualquier link vencido que se abra. Las reglas solo permiten listar/borrar docs ya vencidos

#### Prioridad de apertura de un link
| Plataforma | Comportamiento |
|---|---|
| Android con app instalada | Abre la app nativa (App Link verificado; `assetlinks.json` contiene el SHA-256 de la clave de firma de Play) |
| Android sin app, con PWA | Chrome abre la PWA instalada (WebAPK) |
| Desktop con PWA instalada | La ventana abierta de la PWA recibe el link (`launchQueue`) |
| Resto | Versión web |
| iOS | Siempre Safari: Apple no abre links en PWAs instaladas y no hay app iOS |

#### Reglas de seguridad de `shared_links` (Firestore Console)
> Las reglas se editan a mano en Firebase Console (no están versionadas en este repo).

| Operación | Permitido a |
|---|---|
| `get` | Público (la app y la web/foro pueden abrir cualquier link por ID) |
| `list` | Admin, o queries que solo devuelvan links ya vencidos (`limit ≤ 20`) |
| `create` | Usuario autenticado (anónimo o real) con `ownerUid == auth.uid`, `type` válido, `payload` string < 200 KB y `expiresAt` timestamp |
| `update` | Admin, o cualquiera tocando **solo** `expiresAt` (tope ~31 días) |
| `delete` | Admin, el dueño, o cualquiera si el link ya venció |

#### Pendiente / ideas a futuro
- **Foro en la web** — Login formal compartido con la web; los links anónimos quedan atribuidos al usuario al promover la cuenta (`linkWithCredential`). La web puede leer `shared_links/{id}` y mostrar `name`/`type`/`summary` sin depender de la app
- **Preview dinámico por link** (OG tags tipo "Sesión Chacarera · 3 patrones") — Requiere render server-side (Cloud Function → plan Blaze) o resolverlo desde la web
- **Banner "Abrir en la app"** para navegadores in-app (Instagram/Facebook), que no disparan App Links

### 🎶 Playlists (Listas de Reproducción)
- **Gestión de Playlists** — Crear, renombrar, eliminar y duplicar listas de reproducción. Cada playlist contiene una lista ordenada de sesiones
- **Edición de Contenido** — Agregar sesiones desde un bottom sheet con toda la biblioteca disponible, eliminar sesiones individuales, y reordenar con drag & drop (`ReorderableListView`)
- **Reproducción Secuencial** — Al presionar Play se abre el player dedicado (`PlaylistPlayerScreen`) que carga y reproduce automáticamente la primera sesión
- **Navegación entre Sesiones** — Deslizar horizontalmente (`PageView`) en móvil, o usar las flechas `‹` `›` en PC/desktop para avanzar/retroceder entre sesiones. Al cambiar de sesión, se detiene la anterior y se auto-reproduce la nueva
- **Modo Solo Lectura** — Todo bloqueado por defecto: BPM (botones ±1/±5, slider), volumen (knob), mute, solo, estructura, nombre, añadir/eliminar patrones. Solo activos: Play/Stop, toggle de edición y swipe
- **Toggle Modo Edición** — Switch en el AppBar que desbloquea todos los controles. Los controles bloqueados se muestran con opacidad reducida (50%) usando `IgnorePointer` + `Opacity`
- **Dirty Tracking** — Misma lógica de sesiones: nombre en *itálica* con `*` cuando hay cambios pendientes
- **Conservación de Estado** — Al entrar al player, se guarda el estado completo del metrónomo (sesión activa, BPM, instancias, volumen, mute/solo, dirty state). Al salir, se restaura íntegramente
- **Indicador de Posición** — Dots animados en la parte superior muestran la sesión actual, y flechas circulares con contador `1/N` en la barra inferior permiten navegación directa con animación suave (300ms)
- **Compartir Playlists** — Deep links que empaquetan la playlist + todas las sesiones + todos los patrones referenciados

### 🔄 Actualización Automática de Versión
- **Verificación al inicio** — Al abrir la app, se consulta Firebase Remote Config para obtener la versión mínima requerida (`metronomo_min_version`)
- **Comparación semántica** — Se compara `major.minor.patch` de la versión actual (embebida en build) contra la mínima remota
- **Web/PWA: auto-update** — Si hay actualización, se limpia el cache del Service Worker y se recarga la página automáticamente, descargando el build más nuevo
- **Android/iOS: redirección a Store** — Se muestra pantalla bloqueante con botón que abre la tienda correspondiente
- **Mensaje customizable** — El parámetro `metronomo_force_update_message` permite cambiar el mensaje de actualización desde Firebase Console sin publicar una nueva versión
- **Tolerante a fallos** — Si no hay conexión, la verificación se omite silenciosamente y la app abre normalmente

### 🌐 Web & PWA
- **Soporte Web Completo** — La aplicación es accesible desde cualquier navegador moderno
- **WebAssembly (WASM)** — El motor de audio C++ está compilado a WASM usando Emscripten para correr de forma nativa en la web con mínima latencia y soporte de Web Audio API
- **Progressive Web App (PWA)** — Instalable desde el navegador con un botón dedicado en configuración, con soporte para uso offline
- **AudioWorklet Bridge** — Comunicación completa Dart → JS → WASM para todas las funciones del engine (metrónomo, silencios al azar, sound sets, patterns) vía `postMessage` comandos tipados

### 💾 Gestión de Estado y Flujo de Trabajo
- **Seguimiento 'Dirty State'** — Detección automática y profunda de alteraciones en vivo (BPM, estructuras, faders, mute/solo). La UI reacciona orgánicamente a los cambios pendientes marcando las sesiones y patrones en cursiva con un asterisco (`*`)
- **Edición Dinámica de Patrones** — Renombrado in-situ de pistas con cajas delimitadas dinámicamente (`IntrinsicWidth`) y tracking visual milimétrico del asterisco de edición
- **Guardado simplificado** — 💾 sobrescribe la sesión activa directamente (snackbar con *DESHACER*); si la sesión no existe todavía pide un nombre. *Guardar como…*, *Nueva*, *Abrir*, *Compartir sesión*, *Playlists* y *Ajustes* están en el menú ⋮ de la App Bar
- **Sesiones independientes de la librería** — Cada sesión guarda una copia de sus patrones (`SessionPatternConfig.name/structure/pulses`). Editar o borrar un patrón de la librería nunca cambia una sesión. Guardar una sesión no toca la librería; para tener un patrón en la librería se usa *Guardar en la librería* desde el menú ⋮ del patrón (actualiza la misma entrada si ya existe). Las sesiones viejas se migran automáticamente al iniciar (`SessionProvider.embedMissingPatterns`, idempotente)
- **Menú por patrón (⋮)** — Renombrar (también tocando el título), Guardar en la librería, Compartir patrón, Duplicar y Quitar de la sesión (con *DESHACER*)
- **Aislamiento de Periféricos (Gestos y Foco)** —
  - **Foco Seguro**: Prevención estricta de superposición de teclados (Android Nativo vs Numérico Métrico) purgando la jerarquía de foco antes de despachar diálogos modales; abrir un diálogo confirma la estructura en edición. Visibilidad garantizada vía `Scrollable.ensureVisible`
  - **Arena de Gestos de Alta Precisión**: Controladores de perillas (Knobs) con monopolio asertivo sobre los arreglos `onVerticalDragUpdate` y `onHorizontalDragUpdate`. Esto neutraliza el reconocedor nativo del `ListView`, inhibiendo el scroll inercial padre mientras se manipulan los parámetros de mezcla

## 📐 Arquitectura

```
lib/
├── main.dart                          # Entry point y Providers
├── firebase_options.dart              # Configuración Firebase auto-generada
├── audio/
│   └── click_synth.dart               # Sintetizador procedural de los 7 sets de sonidos (biquads RBJ, modal, 808)
├── constants/
│   └── app_colors.dart                # Paleta de colores (solo tema oscuro) + intensidad de eventos por volumen
├── models/
│   ├── pattern_model.dart             # Modelo de patrón rítmico (estructura, pulsos, subdivisiones, volumen por evento)
│   ├── session_model.dart             # Modelo de sesión (patrones, BPM, configuración de mezcla, sonido por patrón)
│   ├── playlist_model.dart            # Modelo de playlist (lista ordenada de session IDs)
│   └── permission_cache.dart          # Cache de permisos para acceso offline (30 días TTL)
├── providers/
│   ├── metronome_provider.dart        # Estado global, parser de estructuras, tap tempo, macro ciclo
│   ├── settings_provider.dart         # Configuración persistente + cache de permisos offline
│   ├── pattern_editor_provider.dart   # CRUD de la biblioteca de patrones
│   ├── session_provider.dart          # CRUD de la biblioteca de sesiones
│   └── playlist_provider.dart         # CRUD de playlists + reordenar sesiones internas
├── screens/
│   ├── metronome_screen.dart          # UI: secuenciador, controles, visualizador, edición de estructuras y atajos
│   ├── playlists_screen.dart          # Gestión de playlists: crear, editar, eliminar, reordenar sesiones
│   ├── playlist_player_screen.dart    # Reproductor: PageView, flechas de navegación, modo solo lectura, toggle edición
│   ├── auth_gate.dart                 # Gate de autenticación, permisos y fallback offline
│   ├── login_screen.dart              # Login (Google/Email) con detección de errores de red
│   ├── onboarding_screen.dart         # Onboarding para nuevos usuarios
│   └── settings_screen.dart           # Configuración + sección sesión + logout
├── theme/
│   ├── app_theme.dart                 # ThemeData oscuro + component themes (diálogos, snackbars, bottom sheets)
│   └── beat_colors.dart               # Colores por tipo de evento (silencio/acento/normal/suave)
├── services/
│   ├── deep_link_service.dart         # Crear/leer links (Firestore, auth anónima, ID por contenido, captura y dedupe de links entrantes)
│   ├── deep_link_web.dart             # JS interop: URL (?share=), Web Share API, launchQueue (PWA)
│   ├── deep_link_stub.dart            # Stub para plataformas no-web
│   ├── share_import_service.dart      # Importación idempotente de patrones/sesiones/playlists compartidos
│   ├── pwa_install_service.dart       # Servicio de instalación PWA
│   ├── pwa_install_web.dart           # JS interop: beforeinstallprompt
│   ├── pwa_install_stub.dart          # Stub para plataformas no-web
│   ├── version_check_service.dart     # Verificación de versión mínima (Firebase Remote Config)
│   ├── version_check_web.dart         # JS interop: limpieza de cache y reload para actualización web
│   ├── version_check_stub.dart        # Stub para plataformas no-web
│   ├── pattern_repository.dart        # Persistencia de patrones (SharedPreferences)
│   ├── session_repository.dart        # Persistencia de sesiones (SharedPreferences)
│   └── playlist_repository.dart       # Persistencia de playlists (SharedPreferences)
├── utils/
│   ├── bpm_scale.dart                 # Mapeo no lineal slider ↔ BPM (1–999)
│   ├── structure_input.dart           # Validación de estructuras (parcial/completa) + TextInputFormatter
│   └── space_play_shortcut.dart       # Mixin: barra espaciadora → Play/Stop
└── widgets/
    ├── formatted_structure.dart       # Estructura en formato fracción (solo lectura)
    ├── knob_control.dart              # Control rotativo con CustomPainter
    ├── macro_cycle.dart               # Visualizador del ciclo macro con playhead (metrónomo + player)
    ├── mixer_strip.dart               # Volumen + Mute + Solo por patrón
    ├── pattern_card.dart              # Contenedor de patrón: encabezado + secuenciador + mixer
    ├── playback_clock.dart            # Ticker único que publica la posición de reproducción (resaltado de golpes)
    ├── pattern_keypad.dart            # Keypad de estructuras (barra inferior móvil / popover desktop)
    ├── sequencer_grid.dart            # Celdas del secuenciador (tap / long-press de volumen opcionales)
    ├── share_sheet.dart               # Bottom sheet unificado: generar link → Compartir en… / Copiar link
    ├── transport_bar.dart             # Barra inferior: Play/Stop, BPM, slider, TAP
    └── update_required_screen.dart    # Pantalla bloqueante de actualización obligatoria

packages/native_audio_engine/
├── lib/
│   ├── live_mixer.dart                # API pública (export condicional por plataforma)
│   ├── live_mixer_native.dart         # Implementación FFI (Android/iOS/Windows) — sampleRate fijo 44100
│   ├── live_mixer_web.dart            # Implementación Web Audio API — sampleRate dinámico del AudioContext
│   ├── live_mixer_bindings.dart       # Bindings FFI generados para C++ (acepta sampleRate)
│   ├── soundtouch_bindings.dart       # Bindings FFI para SoundTouch
│   └── soundtouch_processor.dart      # Wrapper Dart para pitch shifting
└── src/
    ├── live_mixer.cpp                 # Engine C++ (~45KB): scheduling, mixing, metrónomo, bancos de sonido por patrón, volumen por evento, limitador
    ├── live_mixer.h                   # Header con API C exportada (_engineSampleRate, eventVolumes, sound banks)
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
6. Límites: `count` 1–32, `ratio` 1–64, `subdivision` 1–12, máximo 64 pulsos totales. La UI no permite ingresar valores fuera de rango (`StructureInput`); el parser es único (`HomeMetronomeInstance._parseStructureInitial`) y lo usan tanto la creación como la edición de patrones

## 🛠️ Stack Tecnológico

| Componente | Tecnología |
|-----------|------------|
| Framework | Flutter 3.10+ (Material3) |
| Estado | Provider (ChangeNotifier) |
| Audio Engine | C++ con miniaudio (callback-based) / WASM |
| DSP | SoundTouch (pitch/tempo shifting) |
| FFT | KissFFT (procesamiento espectral) |
| FFI | dart:ffi (nativo) / Web Audio API (web) |
| Backend y Auth | Firebase Auth, Cloud Firestore, Remote Config |
| Persistencia local | SharedPreferences (settings, patrones, sesiones, playlists, cache offline) |
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
