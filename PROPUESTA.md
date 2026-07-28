# Propuesta — Migración de Calendario SaaS a Flutter

> Documento de diseño y planificación. Nada de código todavía: aquí queda definido
> **qué** se construye, **cómo se ve**, **cómo se anima** y **en qué orden**.

---

## 1. Qué encontré en el proyecto actual

### 1.1 Stack

| Capa | Tecnología | Ubicación |
|---|---|---|
| Frontend | Svelte 5 + TypeScript + Vite + TailwindCSS + CSS puro heredado | `calendario-saas/frontend` |
| Empaquetado móvil | Capacitor 6 (WebView) — `com.calendario.finanzas` | `capacitor.config.ts` |
| Backend | Node + Fastify + TypeScript + `@fastify/jwt` | `calendario-saas/backend/server.ts` (2.480 líneas) |
| Base de datos | MySQL en AlwaysData | `setupDB.ts` (15 tablas) |
| API en producción | `https://dibeltran05.alwaysdata.net` | `.env.production` |

### 1.2 Dimensiones reales del frontend

```
Dashboard.svelte        6.051 líneas   ← monolito con los 5 módulos + 12 modales
calendar.css            2.377 líneas
styles.css              1.204 líneas
Confirmar.svelte        1.075 líneas
AdvancedAnalytics       672 líneas     ← 7 gráficas SVG dibujadas a mano
Landing.svelte          594 líneas     ← solo web, excluida del APK
cycleUtils.ts           445 líneas     ← motor de predicción del ciclo
OnboardingFinanzas      387 líneas
Calendar.svelte         362 líneas
Register / ModuleSelector / Login / CoachMark / CurrencyInput / ParticleAnimation
────────────────────────────────────────
~15.300 líneas de frontend
```

### 1.3 Los 5 módulos (y sus 5 temas de color)

La app hoy cambia **el tema completo** al alternar de módulo, mediante clases sobre
`<body>` que reescriben las variables CSS:

| Módulo | Tema | Acento | Fondo |
|---|---|---|---|
| Agenda / Eventos | WhatsApp Dark | `#25D366` | `#0B141A` |
| Salud Femenina | Rosa / violeta | `#ff4081` | `#1a0f14` |
| Finanzas | Esmeralda + oro | `#FFD700` | `#08160E` |
| Notas | Azul | `#4FC3F7` | — |
| Hábitos | Verde | `#4CAF50` | — |

### 1.4 Inventario funcional completo

**Autenticación**
- Registro con nombre, email, contraseña y **WhatsApp obligatorio**
- Verificación por **código OTP de 6 dígitos enviado por WhatsApp** (API externa)
- Reenvío de código con countdown de 60s
- Login con JWT. Si la cuenta no está verificada → 403 + reenvío automático de código
- Selector de módulo: *Personal* (activo) / *Empresa* (próximamente)

**Calendario (compartido por los 5 módulos)**
- Grilla mensual 7×6, semana empieza en domingo
- Festivos de Colombia vía `date.nager.at` con caché en localStorage
- Días importantes desde el backend (`/api/important-days`)
- Tap = seleccionar día · **Doble tap = crear** (implementado con un hack de 400 ms)
- Indicadores por celda distintos en cada modo: puntos de evento, 🎂, 🩸/🌸/✨,
  badge de finanzas, badge `n/m` de hábitos, heatmap de 5 niveles

**Agenda / Eventos**
- Categorías con buscador desplegable
- Frecuencias: única / diaria / quincenal / mensual / trimestral / semestral / anual
  (el backend **materializa físicamente** las ocurrencias futuras en la tabla)
- `tipo_transaccion`: ninguno / gasto / ingreso · `estado_pago`: pendiente / pagado
- Cada evento genera un `uuid_confirmacion` → **link público de confirmación**
- Simulador de mensaje de WhatsApp con botones copiar / enviar
- Cumpleaños como categoría especial → tabla propia con año de nacimiento, mensaje y teléfono
- Festivos y días importantes con ficha de detalle

**Finanzas** (el módulo más grande — 7 sub-pestañas)

1. **Resumen** — balance del día, balance mensual, regla 50/30/20 con diagnóstico,
   consejos generados por reglas, proyección de rendimientos de CDT a fecha futura
2. **Cuentas** — ahorros / efectivo / corriente / CDT / tarjeta de crédito.
   CDT con tasa E.A., plazo, rendimiento diario, interés compuesto proyectado,
   barra de progreso al vencimiento. Tarjeta con cupo y día de corte.
   **Transferencias** entre cuentas.
3. **Metas** — monto objetivo vs actual, fecha límite, aportes, icono y color
4. **Presupuesto** — límite mensual por categoría + **CRUD de categorías propias**
5. **Planificador** — ingresos recurrentes → ocurrencias generadas en el cliente +
   **verificación** (esperado vs. recibido real)
6. **Historial** — transacciones del mes o del día + transferencias
7. **Gráficos** — 7 visualizaciones con filtros 7D/30D/3M/6M/1A:
   tendencia de patrimonio, ingresos vs gastos por mes, flujo diario,
   donut de distribución, top gastos, ingresos por cuenta, balances por cuenta

**Salud femenina** (`cycleUtils.ts` — lógica no trivial, hay que portarla con cuidado)
- Cada registro es el día 1 de un ciclo
- Ciclo cerrado → duración observada (hecho). Último registro → proyección
- Ventana móvil de los **6 ciclos más recientes**; solo se promedian ciclos de 20–45 días
- Con menos de 3 ciclos observados se completa con el estándar de 28 días
- Proyección limitada a **2 ciclos** hacia adelante (más allá no es honesto)
- 7 fases: `period`, `predicted-period`, `late-period`, `ovulation`, `fertile`,
  `follicular`, `luteal` — cada una con color, probabilidad de embarazo y consejo diario
- Historial editable con marcado de ciclos atípicos

**Notas** — nota por día con etiqueta y color

**Hábitos** — hábitos con icono/color/frecuencia/meta, log diario, **rachas**, heatmap

**Búsqueda corporativa** (restringida: solo `user.id === 1` o un email específico)
- Búsqueda por cédula → núcleo familiar (afiliado, cónyuge, beneficiarios)
- Autocompletado de empresas por NIT / razón social
- Exportación a Excel con descarga

**Onboarding y tour** — asistente de 3 pasos para finanzas + *coach marks* posicionados

### 1.5 Cómo carga los datos (esto está bien resuelto y se conserva)

```
GET /api/dashboard/bootstrap   → 1 vez por sesión: cumpleaños, ciclos, hábitos,
                                  cuentas, ingresos planificados, verificaciones,
                                  metas, categorías
GET /api/dashboard/month?mes&anio → al cargar y al cambiar de mes: eventos,
                                  transacciones, notas, logs de hábitos,
                                  presupuestos, transferencias
GET /api/finanzas/analytics?dias  → perezoso, solo al abrir Gráficos
```
Más caché *stale-while-revalidate* en localStorage. **Este diseño es ideal para móvil**
y lo replico tal cual con Hive.

---

## 2. ¿Se puede reutilizar el mismo backend? — **Sí, al 100 %**

No hay nada atado al DOM: es REST + JWT + JSON puro. Ya lo verifiqué endpoint por
endpoint (**68 rutas**). No se requiere ni una línea de cambio en el servidor para
que la app Flutter funcione.

### Detalles técnicos que sí hay que manejar en el cliente Dart

| # | Hallazgo | Impacto | Solución en Flutter |
|---|---|---|---|
| 1 | `DECIMAL(12,2)` de MySQL llega como **string** (`"1500.00"`), no como número | Alto — un `as double` explota | Helper `numFromJson` en todos los `@JsonKey` de montos |
| 2 | `BOOLEAN` llega como `0` / `1` | Medio | Helper `boolFromJson` |
| 3 | El pool usa `dateStrings: ['DATE']` → las fechas llegan ya como `YYYY-MM-DD` | Positivo | Parseo directo, sin desfase UTC |
| 4 | `hora` llega como `HH:MM:SS` y puede ser `null` | Bajo | `TimeOfDay?` con parser tolerante |
| 5 | JWT **sin expiración declarada** | Medio | Interceptor Dio: ante 401 → logout limpio |
| 6 | Contraseñas con **SHA-256 sin salt** | Riesgo de seguridad | Recomiendo migrar a bcrypt (backend). No bloquea la app |
| 7 | "¿Olvidaste tu contraseña?" no tiene endpoint | Bajo | O se oculta, o se agrega `POST /api/password/reset` |
| 8 | CORS `origin: '*'` | Irrelevante en móvil nativo | — |
| 9 | Los códigos OTP viajan por una API de WhatsApp con API-key **hardcodeada** en el server | Riesgo | Moverla a variable de entorno (backend) |

### Endpoints opcionales que facilitarían la vida (no obligatorios)

- `GET /api/me` — revalidar sesión al abrir la app sin tener que pegarle a bootstrap
- `POST /api/auth/refresh` — refresh token
- `POST /api/devices` — registrar token FCM si más adelante se quieren push nativas

---

## 3. Arquitectura propuesta para Flutter

Toolchain verificado en esta máquina: **Flutter 3.44.1 stable · Dart 3.12.1 · Android SDK 36.1.0**.

> ⚠️ `flutter doctor` reporta dos pendientes para compilar el APK:
> faltan los **cmdline-tools** de Android y **aceptar las licencias** del SDK.
> Se resuelve antes de la Fase 7.

### 3.1 Paquetes

| Área | Paquete | Por qué |
|---|---|---|
| Estado | `flutter_riverpod` + `riverpod_annotation` | Los ~40 bloques reactivos `$:` de Svelte mapean 1:1 a providers derivados |
| Navegación | `go_router` | ShellRoute persistente + deep links (`/confirmar/:uuid`) |
| HTTP | `dio` + `pretty_dio_logger` | Interceptores de JWT, retry y manejo de 401 |
| Modelos | `freezed` + `json_serializable` | Inmutabilidad y `copyWith` — 15 tablas que modelar |
| Almacenamiento | `flutter_secure_storage` (token) + `hive_ce` (caché SWR) | Réplica del caché actual |
| Animación | `flutter_animate`, `animations` (Material motion) | Base declarativa + transiciones de Material 3 |
| Gráficas | `fl_chart` + `CustomPainter` propio | Las 7 gráficas + la rueda del ciclo |
| Formato | `intl` (locale `es_CO`) | Moneda COP y fechas en español |
| Extras | `local_auth`, `flutter_local_notifications`, `share_plus`, `open_filex`, `confetti`, `shimmer`, `flutter_staggered_grid_view` | Biometría, recordatorios, Excel, celebraciones, skeletons, masonry |

**Impeller** viene activo por defecto en Android → animaciones a 120 fps sin jank de shaders.

### 3.2 Estructura de carpetas

```
AppFlutter/
├── lib/
│   ├── main.dart
│   ├── app/
│   │   ├── app.dart
│   │   ├── router.dart              # go_router + transiciones custom
│   │   └── theme/
│   │       ├── app_theme.dart       # 5 ThemeData (uno por módulo)
│   │       ├── app_colors.dart      # ThemeExtension con los tokens
│   │       ├── app_typography.dart
│   │       ├── app_spacing.dart
│   │       └── app_motion.dart      # curvas y duraciones estandarizadas
│   ├── core/
│   │   ├── network/     (dio_client, interceptors, api_exception)
│   │   ├── storage/     (secure_store, cache_store)
│   │   ├── utils/       (date_utils, currency, material_icon_map)
│   │   └── extensions/
│   ├── data/
│   │   ├── models/      (15 modelos freezed)
│   │   ├── datasources/ (remote + local)
│   │   └── repositories/
│   ├── features/
│   │   ├── splash/  auth/  module_selector/
│   │   ├── shell/                  # scaffold + bottom nav + calendario
│   │   ├── calendar/               # widget compartido
│   │   ├── agenda/  finance/  cycle/  notes/  habits/
│   │   ├── search/  confirm/  settings/
│   │   └── onboarding/
│   └── shared/
│       ├── widgets/     (glass_card, animated_counter, gradient_button,
│       │                 skeleton, empty_state, app_sheet, ...)
│       ├── animations/  (page_transitions, stagger, morph_indicator)
│       └── painters/    (cycle_wheel, progress_ring, sparkline, particles,
│                         confetti, wave_check)
├── assets/  (fonts, images, lottie)
├── test/
└── pubspec.yaml
```

**`material_icon_map.dart` es crítico**: la base de datos guarda nombres de iconos
como texto (`'savings'`, `'restaurant'`, `'directions_car'`…) en `habitos.icono`,
`finanzas_metas.icono` y `finanzas_categorias.icono`. Se necesita un mapa
`String → IconData` con los ~40 iconos en uso, más un fallback.

---

## 4. Sistema de diseño

### 4.1 Decisión de identidad

Mantengo el ADN (oscuro, acento verde, un color por módulo) pero lo subo de nivel:

- **Superficies por elevación de color**, no por sombras duras — es lo correcto en dark
- **Radios**: 12 (chips) · 16 (inputs) · 20 (cards) · 28 (sheets)
- **Escala de 4 pt** para todo el espaciado
- **Glassmorphism selectivo**: solo en overlays y headers flotantes, nunca en listas
  (mata el rendimiento en scroll)
- **Tipografía**: Plus Jakarta Sans o Inter variable, embebida (no `google_fonts` en
  runtime, para que funcione offline)

### 4.2 Cambio de tema animado (esto no existe hoy)

Hoy cambiar de módulo intercambia una clase CSS → corte brusco. En Flutter:

```
AnimatedTheme(duration: 450ms, curve: Curves.easeInOutCubic)
  + ThemeExtension<AppColors> con lerp() implementado
```

Resultado: al pasar de Finanzas a Ciclo, **todos** los colores de la pantalla
—fondo, acentos, bordes, texto— se interpolan de forma líquida. Es el tipo de
detalle que separa una app "bien hecha" de una app "premium".

### 4.3 Vocabulario de movimiento (`app_motion.dart`)

| Token | Duración | Curva | Uso |
|---|---|---|---|
| `instant` | 100 ms | `easeOut` | Feedback táctil, ripples |
| `quick` | 200 ms | `easeOutCubic` | Hover, selección, checkboxes |
| `standard` | 300 ms | `easeInOutCubic` | Entradas de card, expansiones |
| `emphasized` | 450 ms | `easeInOutCubicEmphasized` | Cambio de tema, transición de página |
| `dramatic` | 700 ms | `easeOutQuint` | Reveals, celebraciones |
| `spring` | — | `SpringSimulation` (damping .8) | Sheets, drag, FAB |
| `stagger` | 60 ms | — | Delay entre items de lista |

Regla: **una sola** animación protagonista por pantalla; el resto acompaña.

### 4.4 Accesibilidad

- Respetar `MediaQuery.disableAnimationsOf(context)` → todo cae a 0 ms
- Contraste AA mínimo en los 5 temas (el tema rosa actual tiene texto `#f48fb1`
  sobre `#2d1b24` que **no pasa AA** — se corrige)
- Targets táctiles ≥ 48 dp (las celdas del calendario actual son más pequeñas)
- `Semantics` en celdas de calendario, checkboxes de hábitos y gráficas

---

## 5. Navegación — el cambio de UX más importante

### Problema actual

El header tiene 5 botones-toggle apretados junto a búsqueda y logout. En móvil es
incómodo, no indica en qué modo estás sin mirar el color, y no hay gestos.

### Propuesta

**Bottom navigation de 5 destinos con indicador *morphing***

```
┌───────────────────────────────────────────┐
│  Header colapsable (mes + acciones)       │
├───────────────────────────────────────────┤
│                                           │
│         CALENDARIO  (persistente)         │
│         PageView infinito por mes         │
│                                           │
├───────────────────────────────────────────┤
│  ▲ drag handle                            │
│  Panel de detalle — cambia según módulo   │
│  (DraggableScrollableSheet)               │
├───────────────────────────────────────────┤
│  📅      💰      🌸      📝      🎯       │
│ Agenda Finanzas Ciclo  Notas  Hábitos     │
└───────────────────────────────────────────┘
```

Claves:

1. El **calendario vive en un `ShellRoute`** → no se reconstruye al cambiar de módulo.
   Solo cambian los indicadores de las celdas (con animación) y el panel inferior.
2. El **indicador de la barra se desliza** de un ícono a otro con una píldora que se
   estira y contrae (efecto *goo*), mientras el color del tema se interpola.
3. **Swipe horizontal** en el panel inferior también cambia de módulo, con parallax
   del fondo. Descubrible y rápido.
4. El módulo **Ciclo se oculta** si el usuario no lo activa en Ajustes (hoy está
   siempre visible para todos).
5. El **panel inferior es arrastrable**: medio (default) → completo (pantalla) →
   mínimo (calendario a pantalla completa). Sustituye el scroll infinito actual.

### Tap vs. doble tap

El doble tap para crear es un antipatrón en móvil (hoy hay un temporizador manual de
400 ms que además retrasa el tap simple). Propuesta:

| Gesto | Acción |
|---|---|
| Tap | Seleccionar día |
| **Long press** | Menú de acciones rápidas del día (crear evento / gasto / nota / periodo) |
| Doble tap | Se mantiene como alias del long press (retrocompatible para quien ya lo tiene aprendido) |
| Swipe horizontal en calendario | Cambiar de mes |

---

## 6. Diseño y animación, vista por vista

### 6.1 Splash

- Logo con **shimmer** cruzando la máscara + escala 0.9 → 1.0 (`easeOutBack`)
- Fondo de partículas con `CustomPainter` (sustituye `ParticleAnimation.svelte`,
  que hoy es DOM y cuesta caro)
- En paralelo: leer token, validar sesión, precalentar caché
- Salida: el logo hace **Hero** hacia el logo del Login → continuidad total

### 6.2 Login

- Fondo: **3 orbs desenfocados** flotando en trayectorias sinusoidales
  (`ImageFiltered` + `AnimationController`) — la versión actual en CSS, pero fluida
- Tarjeta **glass**: `BackdropFilter` + borde 1 px blanco 10 %
- Campos: la etiqueta sube y toma el color de acento al enfocar
  (`AnimatedDefaultTextStyle`), el borde se ilumina con gradiente
- Botón: gradiente verde→azul, escala 0.97 al presionar. En loading, el texto
  **hace morph** a spinner dentro del mismo contenedor (`AnimatedSize` + `AnimatedSwitcher`)
- **Error**: la tarjeta hace *shake* (`TweenSequence` sobre translateX), haptic de
  error, y el mensaje entra deslizándose
- **Éxito**: el botón colapsa a un círculo con check → el círculo **se expande hasta
  llenar la pantalla** (`ClipPath` animado) revelando la vista siguiente

### 6.3 Registro (2 pasos)

- Stepper con barra de progreso animada
- Paso 1 → Paso 2: `SharedAxisTransition` horizontal
- **Campo de WhatsApp** con selector de país y formato en vivo
- **OTP de 6 cajas**:
  - cada dígito escrito hace *pop* en su caja (1 → 1.15 → 1) y enciende el borde
  - al completar los 6 → auto-submit con un pulso de la fila entera
  - error → las 6 cajas hacen *shake* sincronizado + vibración
  - pegar desde el portapapeles rellena las 6 en cascada de 40 ms
- **Countdown de reenvío**: anillo circular que se vacía (`CustomPainter`), no un número seco

### 6.4 Selector de módulo

- Entrada de las cards **escalonada** (80 ms de delay) desde abajo con fade
- **Tilt 3D** siguiendo el dedo: `Matrix4` con perspectiva mientras se arrastra sobre
  la card. Detalle caro de imitar y muy vistoso
- Tap en *Personal*: la card **se expande hasta ocupar la pantalla** (`OpenContainer`)
  y por dentro ya está el dashboard — cero corte visual
- *Empresa* mantiene el badge "PRÓXIMAMENTE" con un shimmer sutil

### 6.5 Calendario (la vista central)

- **`PageView` infinito** de meses: swipe horizontal natural
- Header de mes: al cambiar, el nombre hace cross-fade y **el año rueda dígito a
  dígito** hacia arriba o abajo según la dirección
- Celdas: `AnimatedContainer` para color/borde/radio. Al seleccionar → ripple
  centrado + escala 1.06 → 1.0
- El anillo de "hoy" **respira** con un pulso lento
- Los indicadores (puntos, emojis, badges) **entran escalonados** cuando llega la data
  del backend — convierte el "pop" de datos en algo intencional
- **Modo ciclo**: menstruación con gradiente que respira, ovulación con glow pulsante
- **Modo hábitos**: heatmap cuyo color **se interpola** al cambiar de mes
- **Modo finanzas**: el badge de monto aparece con un contador que sube desde 0
- Long press → **bottom sheet radial** de acciones rápidas del día
- Skeleton con shimmer mientras carga el mes (hoy no hay nada y la grilla salta)

### 6.6 Panel Agenda

- Cabecera del día seleccionado con el color del tipo de día (festivo / importante / normal)
- Lista de eventos con entrada escalonada; cada tarjeta con **swipe** → editar / eliminar
- **Simulador de WhatsApp**: burbuja de chat realista con la cola del globo, la hora
  y doble check azul. Botones copiar (con check animado) y enviar (abre WhatsApp)
- Cumpleaños: tarjeta con confeti sutil de fondo y la edad en contador animado
- Ficha de festivo desplegable con `AnimatedSize`
- Vacío: ilustración animada + CTA

### 6.7 Módulo Finanzas

**Barra de pestañas**: `TabBar` scrollable con indicador que **se estira** entre
pestañas (efecto goo) + `TabBarView` con swipe entre las 7 vistas.

**Resumen**
- Tarjeta de balance con el número **contando desde 0** en formato COP al entrar
- Barra 50/30/20: los tres segmentos crecen **en secuencia** (`Interval` sobre un
  único controller) y las tres filas comparativas entran en cascada
- Sparkline del mes con el trazo **dibujándose** (`PathMetrics`)
- Consejos del "experto": tarjetas apiladas que entran una tras otra
- Proyección de CDT: tarjeta glass con el interés acumulado en contador animado

**Cuentas**
- Las tarjetas de crédito se ven como **tarjetas físicas**: gradiente por tipo, chip,
  últimos dígitos, y **flip 3D** al tocar (`Transform` con `rotationY` + perspectiva)
  para ver deuda, cupo y día de corte al reverso
- CDT: **anillo de progreso** al vencimiento + el rendimiento diario como número que
  **sube en tiempo real** (se recalcula cada segundo). Detalle deleitoso y barato
- Swipe en la lista para editar / eliminar
- Transferencia: sheet con las dos cuentas y una **flecha animada** que viaja de
  origen a destino al confirmar

**Metas**
- Barra de progreso con brillo que recorre el relleno
- Al alcanzar el 100 %: **confeti** + haptic de éxito + la tarjeta se marca completada
  con un check dibujado
- Aporte rápido desde el día seleccionado

**Presupuesto**
- Grid de categorías con **anillo de progreso** por categoría
- Al superar el límite, el anillo **pulsa en rojo**
- Gestión de categorías propias con selector visual de iconos (grid animado)

**Planificador**
- **Timeline vertical** de ocurrencias con la línea dibujándose de arriba a abajo
- Verificar un ingreso → el check **se dibuja con trazo** (`PathMetrics`) y el item
  cambia de color ámbar a verde

**Historial**
- Lista agrupada por fecha con **headers pegajosos**
- Items con entrada escalonada, monto en verde/rojo, swipe para eliminar
- Deshacer con snackbar y temporizador visual

**Gráficos** (`fl_chart`)
- Las 7 gráficas con animación de entrada y **tooltips al tocar** (hoy no hay
  interacción: son SVG estáticos)
- El filtro 7D/30D/3M/6M/1A hace **morphing de los datos**, no un redibujado seco
- Donut con el arco creciendo y la leyenda entrando en cascada

### 6.8 Módulo Ciclo

Aquí propongo el mayor salto visual respecto a la versión web:

- **Rueda del ciclo** (`CustomPainter`): un anillo dividido en arcos de color por
  fase, con un marcador que se posiciona en el día actual. Al seleccionar otro día,
  el marcador **se desliza por la circunferencia** y el centro hace cross-fade con
  el nuevo número de día
- El color de acento de la pantalla **se interpola** al color de la fase seleccionada
- Tarjeta de fase con el consejo del día, entrando con fade+slide
- Probabilidad de embarazo como medidor animado
- Registro de periodo desde long press en el calendario o desde la rueda
- Historial de ciclos con badges de "atípico" y edición inline
- **Toda la lógica de `cycleUtils.ts` se porta 1:1 a Dart, con sus tests**
  (ya existe `cycleUtils.test.ts` con 169 líneas que sirven de referencia)

### 6.9 Módulo Notas

- Notas como tarjetas tipo sticky con el color elegido y una rotación aleatoria de
  ±1.5° para dar naturalidad
- Grid **masonry** (`flutter_staggered_grid_view`) de las notas del mes
- Crear: el FAB **se expande** hasta convertirse en el editor (`OpenContainer`)
- Selector de color como fila de círculos con check animado
- Guardar → la tarjeta "vuela" a su posición en el grid

### 6.10 Módulo Hábitos

- **Checkbox circular custom**: al marcar, una **onda llena el círculo** desde el
  centro (`CustomPainter` + controller), el check se dibuja con trazo, haptic medio
  y un micro-burst de partículas
- **Racha**: llama con parpadeo animado; al superar un récord, pulso dorado
- **Anillos estilo Apple Fitness** para el progreso diario del conjunto
- Heatmap mensual con leyenda y tooltip al tocar

### 6.11 Formularios → Bottom sheets

Los **12 modales** actuales pasan a `showModalBottomSheet` con:
- `isScrollControlled` + drag handle + esquinas de 28
- **Blur animado** del fondo al abrir (`BackdropFilter` con opacidad tweened)
- El teclado empuja el contenido con `AnimatedPadding` (nunca tapa el campo activo)
- Validación inline con mensajes que entran animados
- **`CurrencyInput` → `TextInputFormatter`** con formato es-CO en vivo (miles con
  punto, sin decimales), igual que el componente actual
- Selector de fecha/hora nativo, con el estilo del tema del módulo

### 6.12 Búsqueda corporativa

- La barra **se expande desde el ícono** de lupa (`Hero` + `AnimatedContainer`),
  igual que el `search-bar.active` de hoy pero con física
- Autocompletado con resultados en cascada
- Fichas de núcleo familiar **expandibles** con `AnimatedSize` y rotación del chevron
- Exportar a Excel: botón con progreso circular → descarga → `share_plus` / abrir
- Se muestra solo si el backend autoriza al usuario (hoy: `id === 1` o email específico)

### 6.13 Confirmación pública (deep link)

- Registrar **App Links** (`https://dibeltran05.alwaysdata.net/confirmar/:uuid`) y un
  esquema propio (`agendaservi://confirmar/:uuid`)
- Pantalla nativa con los datos del evento, selector de cuenta y categoría
- Al confirmar: **confeti** (la versión web ya lo tiene) + check expandiéndose
- Funciona **sin sesión**, igual que hoy

### 6.14 Ajustes (nuevo — hoy no existe)

- Perfil y cierre de sesión
- **Bloqueo biométrico** de la app (`local_auth`)
- Activar / desactivar módulos visibles en la barra inferior
- **Recordatorios locales** de eventos (complementa el WhatsApp del backend)
- Limpiar caché · Acerca de · Versión

### 6.15 Onboarding y coach marks

- Onboarding de finanzas como **carrusel de 3 pasos** con ilustraciones animadas y
  progreso, en lugar del bloque estático actual
- Coach marks con **spotlight**: fondo oscurecido con un recorte animado sobre el
  elemento destacado (`CustomPainter` + `BlendMode.clear`), tooltip que apunta
  y flecha animada. Muy superior al `CoachMark.svelte` actual

---

## 7. Micro-interacciones transversales

| Elemento | Comportamiento |
|---|---|
| Feedback háptico | `selection` al tocar, `light` al navegar, `medium` al completar, `heavy` en errores |
| Carga | **Skeletons con shimmer** siempre, nunca un spinner suelto |
| Pull-to-refresh | Indicador custom con el logo girando |
| Estados vacíos | Ilustración animada + CTA claro, uno distinto por módulo |
| Snackbars | Estilo propio con ícono, color de estado y acción "Deshacer" |
| Errores de red | Banner animado de offline + reintento automático con backoff |
| Transiciones | `SharedAxis` en jerarquía · `FadeThrough` entre pares · `ContainerTransform` al expandir |
| Scroll | Física iOS/Android nativa + *overscroll glow* en el color del módulo |
| Botones | Escala 0.97 al presionar, siempre |

---

## 8. Plan de trabajo por fases

| Fase | Contenido | Entregable |
|---|---|---|
| **0 — Fundaciones** | Proyecto, pubspec, tema × 5, tokens, tipografía, `app_motion`, Dio + interceptores, 15 modelos freezed, router, mapa de iconos, catálogo interno de widgets | App corriendo con design system navegable |
| **1 — Auth** | Splash, Login, Registro, OTP por WhatsApp, Selector de módulo, sesión persistente | Se puede entrar contra el backend real |
| **2 — Shell + Calendario + Agenda** | ShellRoute, bottom nav morphing, calendario `PageView`, bootstrap + month + caché, panel Agenda, CRUD de eventos y cumpleaños, simulador de WhatsApp | Módulo Agenda completo |
| **3 — Finanzas** | Las 7 sub-pestañas, CRUD completo, transferencias, verificaciones, CDT, 50/30/20, gráficas | Módulo Finanzas completo (la fase más larga) |
| **4 — Ciclo · Notas · Hábitos** | Port de `cycleUtils` + tests, rueda del ciclo, notas masonry, hábitos con rachas y heatmap | Los 5 módulos funcionando |
| **5 — Extras** | Búsqueda corporativa, exportar Excel, pantalla de confirmación, deep links, onboarding, coach marks | Paridad total con la web |
| **6 — Pulido** | Segunda pasada de animaciones, offline, notificaciones locales, biometría, accesibilidad, perfilado a 120 fps | App lista para release |
| **7 — Release** | cmdline-tools + licencias Android, iconos adaptativos, splash nativo, firma, App Links, APK/AAB | Instalable |

Cada fase se entrega funcionando contra el backend de producción — nada de trabajo
a ciegas.

---

## 9. Lo que propongo mejorar de paso

Cosas que hoy están rotas, ausentes o incómodas, y que cuesta poco arreglar durante
la migración:

1. **Doble tap → long press** para crear (elimina el retardo de 400 ms en todo tap)
2. **Contraste AA** en el tema rosa (`#f48fb1` sobre `#2d1b24` no pasa)
3. **Targets de 48 dp** en las celdas del calendario
4. **Skeletons** en vez de grillas que saltan al llegar la data
5. **Recuperar contraseña** (requiere endpoint nuevo en el backend)
6. **Ajustes** — hoy no hay ninguna pantalla de configuración
7. **Manejo explícito de 401** → hoy un token vencido deja la app en estado raro
8. **Parseo de `DECIMAL`** — el front web hace `Number(...)` sobre strings y funciona
   por casualidad; en Dart hay que hacerlo bien
9. **Modo offline real** — leer del caché y encolar escrituras
10. **Bloqueo biométrico** — la app maneja datos financieros y de salud

---

## 10. Decisiones que necesito de tu parte

| # | Pregunta | Mi recomendación |
|---|---|---|
| 1 | ¿Bottom nav de 5 destinos, o conservar los toggles del header? | **Bottom nav** — es el estándar móvil y libera el header |
| 2 | ¿Long press para crear, o mantener doble tap? | **Long press**, con doble tap como alias |
| 3 | ¿Entra la búsqueda corporativa (Comfaca) en la app? | **Sí**, pero oculta salvo que el backend autorice |
| 4 | ¿Se incluye la landing de marketing? | **No** — igual que el APK actual, que ya la excluye |
| 5 | ¿Solo Android o también iOS? | Android primero; el código sirve para iOS sin cambios (falta un Mac para compilar) |
| 6 | ¿Mantener la identidad WhatsApp o rediseñar la paleta? | **Mantener el ADN**, elevando contraste, tipografía y espaciado |
| 7 | ¿Se puede tocar el backend para lo mínimo (reset de contraseña, bcrypt, API-key a env)? | Recomendado, pero **no bloquea nada** |
| 8 | ¿Nombre y `applicationId` de la app? | Sugiero conservar `com.calendario.finanzas` para no romper instalaciones |

---

## 11. Resumen

- **El backend se reutiliza tal cual**: 68 endpoints REST + JWT, cero cambios obligatorios.
- **Los 5 módulos, los 12 formularios y las 7 gráficas se portan completos.**
- **La lógica delicada** (predicción del ciclo, interés compuesto de CDT, ocurrencias
  recurrentes, regla 50/30/20, rachas) se traduce a Dart con tests, tomando como
  referencia los tests que ya existen en TypeScript.
- **El salto real está en la interacción**: calendario con swipe entre meses, panel
  arrastrable, cambio de tema interpolado, tarjetas de crédito con flip 3D, rueda del
  ciclo, checkboxes con onda, contadores animados y transiciones Material 3 en toda
  la navegación.
