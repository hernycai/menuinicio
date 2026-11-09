# Rojo Inicio

Rojo Inicio es una aplicación para macOS que muestra servicios configurados para ejecutarse al iniciar el equipo o al iniciar sesión. Presenta la aplicación asociada, desarrollador, ruta y estado. Permite activar o desactivar servicios compatibles, abrirlos en Finder y deshacer el último cambio.

## Descargar e instalar

1. Abre la sección [Releases](https://github.com/hernycai/menuinicio/releases/latest) y descarga `Rojo-Inicio-1.0.0.dmg`.
2. Abre el archivo DMG.
3. Arrastra **Rojo Inicio.app** a la carpeta **Aplicaciones**.
4. Expulsa el disco virtual e inicia Rojo Inicio desde Aplicaciones.

La versión actual no está firmada ni notarizada. macOS puede mostrar un aviso al abrirla. Para distribución sin ese aviso, el desarrollador debe firmar y notarizar la aplicación con Apple.

## Qué puede gestionar

La app examina `~/Library/LaunchAgents`, `/Library/LaunchAgents` y `/Library/LaunchDaemons`. Los LaunchAgents se pueden activar o desactivar desde la lista. Los LaunchDaemons del sistema requieren autorización de administrador. Los elementos “Abrir al iniciar” y “Actividad en segundo plano” que macOS administra directamente se consultan en **Ajustes del Sistema → General → Ítems de inicio**; el botón de la app abre ese panel.

Desactivar un servicio puede afectar sincronización, avisos o actualizaciones de su aplicación. El botón **Deshacer** revierte el último cambio realizado desde Rojo Inicio.

## Compilar desde el código

Requiere macOS y Xcode Command Line Tools. Desde la carpeta clonada:

```sh
./scripts/build.sh
```

El DMG aparece en `dist/Rojo-Inicio-1.0.0.dmg`. También se puede instalar localmente con `./scripts/install.sh`.
