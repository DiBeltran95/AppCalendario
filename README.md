# Agendaservi — App Flutter

Migración nativa del frontend Svelte de `calendario-saas` a Flutter, contra el
**mismo backend** Fastify de producción (`https://dibeltran05.alwaysdata.net`),
sin ningún cambio en el servidor.

## Correr la app

```bash
flutter pub get
flutter run            # dispositivo Android conectado
flutter run -d chrome  # prueba rápida en navegador
```

Tests del motor de ciclo (port 1:1 de `cycleUtils.ts` con sus 38 casos):

```bash
flutter test
```

> Para compilar el APK faltan dos pasos en esta máquina (`flutter doctor`):
> instalar los *cmdline-tools* de Android y aceptar licencias con
> `flutter doctor --android-licenses`.

## Estructura

```
lib/
├── app/            # tema (5 paletas interpolables), motion, router, providers
├── core/           # red (Dio+JWT), almacenamiento (SWR cache), cycle engine, utils
├── data/           # modelos de las 15 tablas + repositorios (68 endpoints)
├── features/
│   ├── splash/ auth/ module_selector/
│   ├── shell/      # HomeShell: calendario persistente + panel arrastrable + bottom nav
│   ├── calendar/   # PageView infinito de meses, celdas por módulo, acciones de día
│   ├── agenda/ finance/ cycle/ notes/ habits/
│   ├── search/     # buscador corporativo (gateado por usuario)
│   ├── confirm/    # confirmación pública /confirmar/:uuid
│   └── settings/
└── shared/         # widgets y animaciones reutilizables
```

## Decisiones clave

- **Un solo calendario** en un shell persistente: cambiar de módulo no lo
  reconstruye, solo cambia indicadores y panel. El tema completo se interpola
  (`AppColors.lerp` + `AnimatedTheme`).
- **Long press** crea (con doble tap como alias); el tap solo selecciona.
  Se eliminó el retardo de 400 ms del doble-clic web.
- Carga en dos niveles como la web: `bootstrap` (1×/sesión) + `month`
  (por mes) + `analytics` (perezoso), con caché stale-while-revalidate.
- Los `DECIMAL`/`BOOLEAN` de MySQL llegan como string/0-1: todo el parseo pasa
  por `core/utils/json_utils.dart`.
- Fechas siempre como `YYYY-MM-DD` local (sin UTC), igual que el backend.

## Pendientes conocidos

- Compilación de APK (cmdline-tools + licencias + App Links en el manifest).
- Notificaciones locales y bloqueo biométrico (propuestos en PROPUESTA.md §6.14).
- El backend no tiene endpoint de recuperar contraseña.
