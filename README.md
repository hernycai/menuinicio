# Rojo Inicio

Aplicación nativa para macOS que inspecciona LaunchAgents y LaunchDaemons, muestra su etiqueta y permite habilitar o deshabilitar agentes del usuario con `launchctl`. La app no elimina archivos de configuración.

## Compilar y empaquetar

```sh
./scripts/build.sh
```

Genera `build/Rojo Inicio.app`, un icono macOS y `dist/Rojo-Inicio-1.0.0.dmg`. El DMG puede instalarse arrastrando la app a Aplicaciones. Para instalar localmente en `/Applications`, ejecuta `./scripts/install.sh`.

## Cobertura y permisos

- El inventario lee `~/Library/LaunchAgents`, `/Library/LaunchAgents` y `/Library/LaunchDaemons`.
- La app modifica el estado de los agentes del usuario con `launchctl enable/disable`; el cambio aplica en el siguiente inicio de sesión.
- Los agentes y daemons globales se muestran como protegidos. La app no cambia archivos del sistema ni solicita privilegios de administrador.
- Los elementos de Inicio de sesión administrados por macOS se configuran en Ajustes del Sistema > General > Ítems de inicio. macOS no ofrece a una app común un inventario completo de esos elementos de otras apps.

## Actualizaciones

En Actualizaciones, la app consulta `hernycai/menuinicio` por defecto; se puede indicar otro `usuario/repositorio`. La app abre la página oficial de descargas. La descarga e instalación automática requiere firma Developer ID, notarización y Sparkle con claves privadas. La preferencia de comprobación automática queda guardada; el chequeo automático aún no está activo en esta compilación.

## Distribución

El DMG generado sirve para compartir. Para distribución pública, firma y notariza la app antes de publicar; configura los secretos `APPLE_CERTIFICATE`, `APPLE_CERTIFICATE_PASSWORD`, `APPLE_ID`, `APPLE_TEAM_ID` y `APPLE_APP_SPECIFIC_PASSWORD` en GitHub Actions. La instalación de la app en `/Applications` es local y no se incluye en el DMG.
