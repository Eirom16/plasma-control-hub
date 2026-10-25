# Validación

Entorno de referencia: CachyOS, Plasma Workspace/Desktop 6.8.1, KDE Frameworks 6.31, Qt 6.12 y GCC 16.2.1.

## Pruebas automatizadas

`QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software ctest --test-dir build --output-on-failure`

- **PASS**: validación AppStream configurada por ECM.
- **PASS**: prueba original del modelo de bandeja de KDE.
- **PASS**: ordenación, módulos ausentes y eliminación de duplicados en la distribución.
- **PASS**: integración del containment compilado con los plasmoides reales, usando Xvfb y un bus D-Bus privado.

La integración comprueba carga y unicidad de módulos, apertura del centro, edición y guardado, reordenación con eventos reales de puntero, posición de brillo/volumen en el pie, apertura de la vista original de audio, recepción de un StatusNotifierItem, arrastre nativo desde el desplegable hacia el panel, recepción de una notificación real mediante el protocolo D-Bus, contenido del historial y apertura/cierre del cajón lateral. Detecta errores de ejecución de nuestro QML.

La pantalla y las rutas XDG de configuración, datos, caché y estado están aisladas. La prueba no activa/desactiva servicios ni modifica el volumen o el brillo del usuario.

## Escalado y geometría

- **PASS**: Xvfb 1440 × 900, escala 100 %.
- **PASS**: Xvfb 1920 × 1080, `QT_SCALE_FACTOR=2`, área lógica 960 × 540. Incluye los arrastres, adaptando las coordenadas del puntero a la escala.
- Pie fijo medido al 100 %: brillo `QRectF(8,332 460×30)`, volumen `QRectF(8,366 460×30)`, dentro de un panel emergente de 476 × 404.
- Cajón al 100 % en X11: `QRect(1000,0 440×900)` dentro de `QRect(0,0 1440×900)`.
- Cajón al 200 %: `QRect(520,0 440×540)` dentro de `QRect(0,0 960×540)`.

## Wayland y KWin

**PASS**: KWin Wayland 6.8.1 con framebuffer virtual 1440 × 900, bus privado y rutas XDG aisladas. La geometría se consulta al propio compositor mediante su API de scripting: `QRect(1000,0 440×900)`, exactamente en el borde derecho.

Esta prueba detectó y permitió corregir un problema del diálogo de Qt en Wayland: sus coordenadas globales podían volver a cero durante la configuración de la superficie. `NotificationDrawer` reaplica el anclaje con `PlasmaShellWaylandIntegration`, reutilizando la superficie nativa de libplasma. El historial recibió la notificación de prueba y cerró correctamente, sin errores de nuestro QML.

Los eventos reales de puntero para arrastre se validaron en Xvfb; la prueba de Wayland comprueba carga, controles, edición mediante sus funciones, historial, foco y geometría del compositor. No se ha registrado un vídeo ni medido la trayectoria cuadro a cuadro de la animación.

## Instalación y traducción

**PASS**: instalación local en `~/.local/lib/plugins/plasma/applets`, descubrimiento del plugin instalado en un proceso nuevo y ejecución de la integración con `LC_ALL=es_DO.UTF-8` y `LANGUAGE=es`. Se verificó visualmente la traducción al español del centro, editor, pie y notificaciones.

## Capturas

`docs/screenshots/` contiene capturas del widget real, tomadas con los plasmoides de KDE. Las tarjetas deshabilitadas reflejan los servicios ausentes del bus de pruebas. No son maquetas.

## Límites de estas comprobaciones

El bus aislado no ejecuta PowerDevil, KDE Connect ni otros demonios de la sesión. Por eso ciertas tarjetas aparecen deshabilitadas y el brillo muestra su estado de indisponibilidad. Se comprobó por separado, mediante una consulta de solo lectura, que la sesión del usuario publica `org.kde.ScreenBrightness` con un monitor.

No se han medido FPS, consumo gráfico ni latencia. La animación depende de los efectos habilitados y de la velocidad de animación configurada en KWin. No se han realizado pruebas físicas de desconexión de monitores, dispositivos Bluetooth o adaptadores de red, ni cambios de estado de hardware.
