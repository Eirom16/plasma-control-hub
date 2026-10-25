# Arquitectura

## Base original

`applets/systemtray` procede de Plasma Workspace 6.8.1. Se conservan el registro de plasmoides, la integración con StatusNotifierItem, los modelos de iconos, la importación de menús D-Bus y las acciones de las aplicaciones. `libdbusmenuqt` también procede del mismo proyecto.

El identificador del nuevo containment es `org.eirom.plasma.controlhub`. Su biblioteca incorpora QML mediante los mecanismos de compilación de Plasma 6.8. No se instala ningún archivo con el identificador de la bandeja original.

## Propiedad y navegación

`main.qml` filtra el modelo original en aplicaciones visibles, aplicaciones ocultas y plasmoides de control. Cada plasmoide tiene un solo propietario, incluso al quitar su tarjeta del centro de control. Su representación completa se aloja en `PlasmoidPopupsContainer.qml`, conservando las acciones, cabecera, navegación y configuración originales.

Los controles genéricos abren la interfaz completa del módulo. Las tarjetas de red y Bluetooth utilizan directamente las acciones que los plasmoides originales exponen, con sus estados y restricciones. Brillo y volumen se mantienen en un pie fijo, separado de la cuadrícula desplazable. Sus filas permiten abrir las vistas completas y se pueden mostrar u ocultar desde el editor; su ubicación inferior permanece fija. Los deslizadores usan los módulos de Plasma Audio Volume y PowerDevil; no ejecutan comandos de shell para cambiar el sistema.

## Personalización

`controlOrder` y `selectedControls` se añaden al esquema KConfig original. La visibilidad de una tarjeta es independiente del estado del servicio. Los cambios de visibilidad se guardan juntos mediante el esquema original y notifican inmediatamente al modelo. El arrastre entre ventanas utiliza MIME y la transferencia nativa de Qt. Los iconos de aplicaciones conservan las preferencias `shownItems` y `hiddenItems` de KDE. `ControlLayout.js` centraliza las operaciones de orden y visibilidad.

## Notificaciones

El widget original `org.kde.plasma.notifications` sigue gestionando historial, avisos temporales, acciones, tareas, agrupación y No molestar. Su vista completa se aloja en `NotificationContent.qml`.

`NotificationDrawer` deriva de `PlasmaQuick::Dialog`: reutiliza el tema y la integración de ventanas de Plasma, y modifica la posición para colocar el historial a la derecha del área disponible del monitor del widget. En Wayland se reaplica la posición a través de `PlasmaShellWaylandIntegration`, porque Qt puede comunicar coordenadas globales nulas durante la configuración inicial de la ventana. Se conserva la superficie original de libplasma. KWin recibe una solicitud de deslizamiento desde el borde derecho. El efecto real depende de que la animación correspondiente esté habilitada. La velocidad de animación configurada en KDE se respeta.

El centro de control y el historial lateral se excluyen mutuamente. Cerrar el historial sincroniza el estado `expanded` del plasmoide original, necesario para el seguimiento de lectura.

## Geometría

Los diseños utilizan `Kirigami.Units`, layouts automáticos, controles nativos y colores heredados. La cuadrícula de controles cambia a una columna cuando falta ancho; el contenido tiene desplazamiento. El cajón de notificaciones queda limitado al área disponible del monitor y mantiene el botón de cierre accesible.

## Actualizaciones de KDE

Comparar cada nueva versión con el commit de importación, revisar los cambios de las interfaces privadas y ejecutar tanto las pruebas de modelos como la integración con los plasmoides reales. No se ofrece compatibilidad automática con versiones anteriores a Plasma 6.8.
