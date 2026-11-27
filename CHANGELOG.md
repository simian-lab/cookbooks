# Changelog

## [5.5.0] - 2026-11-27

- `wordpress` lee desde Parameter Store el parámetro opcional `UEC_CACHE_INVALIDATOR_TOKEN` (igual que `RD_STATION_API_KEY`) y lo agrega a la configuración de la instancia. Si el parámetro no existe, no pasa nada.
- `wordpress` revierte el ajuste de 5.4.2 que fijaba la fecha de modificación de `wp-content/plugins/wp-2fa/wp-2fa.php` en cada deploy; el deploy vuelve a no tocar esa fecha.

## [5.4.2] - 2026-11-26

- `wordpress` fija la fecha de modificación de `wp-content/plugins/wp-2fa/wp-2fa.php` (`2020-01-01 00:00:00 UTC`) en cada deploy, justo después de sincronizar el repositorio. WP 2FA (clase `Upgrade_Guard`, desde la 4.0) guarda en la base de datos compartida el hash `md5(versión | filemtime(wp-2fa.php))` y, cuando no coincide con el de la instancia que atiende la petición, invalida en opcache los 301 archivos PHP del plugin. Como cada instancia tiene la fecha de su propio deploy, con varias instancias el hash oscilaba en la mayoría de las peticiones: opcache se reiniciaba cada ~30 s (724 reinicios en ~9,6 h en una instancia) y cada reinicio asigna huecos nuevos en la tabla `map_ptr` de PHP, que cada worker nuevo reserva entera en su primera petición (160-175 MB de ceros). Eso llevaba la memoria de las instancias al 85-99 % en 10-17 h.
- Verificado en producción el 2026-11-25: tras igualar la fecha a mano en las tres instancias y reiniciar Apache, el contador `oom` de opcache dejó de subir, los workers nacen con ~100 MB (antes ~280 MB) y a las 16,8 h las instancias siguen en ~45-47 % de memoria con pendiente casi nula. Las instancias existentes toman el cambio en el siguiente deploy o al reemplazarse.

## [5.4.1] - 2026-11-25

- `apache2` limita la memoria de Apache con un drop-in de systemd (`apache2.service.d/memory-limit.conf`): `MemoryMax` igual al presupuesto de Apache (RAM − Varnish − SO/agentes, 2115 MB en una instancia de 4 GB) y `OOMPolicy=continue`. Si Apache llega al límite, el kernel mata un proceso hijo y prefork lo reemplaza, en lugar de que toda la instancia se quede sin memoria y entre en thrashing como en la caída del 2026-11-25. `OOMPolicy=continue` evita que systemd detenga Apache entero al primer hijo eliminado.
- Sin `MemoryHigh` a propósito: en staging, con el límite bajado a 180 MB, `MemoryHigh` hizo que el kernel frenara a Apache en lugar de matar procesos y el sitio dejó de responder (100 % de timeouts). Solo con `MemoryMax`, Apache tuvo algunos 503 y siguió respondiendo.

## [5.4.0] - 2026-11-25

- `wordpress` hace que Varnish nunca cachee `healthz.php`, para que el health check del ELB llegue siempre a Apache y no a una respuesta en caché.
- `apache2` agrega el PID del worker (`%P`) y la duración en microsegundos (`%D`) al final de los access logs (formatos `combined_xff` y el nuevo `combined_pid`), para cruzar cada petición con el RSS de su proceso en New Relic. Los campos van después del User-Agent, así que los patrones de parseo existentes siguen funcionando.

## [5.3.2] - 2026-11-24

- `apache2` apaga `KeepAlive` y baja `MaxConnectionsPerChild` de 500 a 100. `MaxConnectionsPerChild` cuenta conexiones, no requests: con `KeepAlive On` Varnish reutilizaba sus conexiones hacia Apache y cada una servía ~7,3 requests (`backend_req / backend_conn` = 43 876 / 6005 en producción el 2026-11-24), así que 500 conexiones eran ~3650 requests, unas 13 horas por proceso. Los procesos de PHP casi nunca se reciclaban y crecían hasta 340–385 MB de RSS, llevando las instancias al 90–98 % de memoria.
- Varnish y Apache corren en la misma instancia (Varnish en el 80, Apache en el 8080) y no hay conexiones establecidas en el 443 de Apache, así que abrir una conexión por request no tiene costo apreciable. Con `KeepAlive Off` cada proceso se recicla cada 20–35 minutos con el tráfico observado (~0,8 requests/s por instancia).
- Verificado en la instancia beta con 1500 requests sin caché: todos `200`, `backend_req / backend_conn` = 1679 / 1679 (antes 7,3) y procesos de Apache de 14 a 58 segundos de vida. Las instancias existentes toman el cambio solo al reemplazarse.

## [5.3.1] - 2026-11-23

- `apache2` calcula `MaxRequestWorkers` con un presupuesto de memoria explícito: RAM total − Varnish (25 %) − SO y agentes (768 MB), dividido por la memoria de cada proceso Apache+PHP. Antes reservaba un 30 % genérico que no alcanzaba para Varnish (~930 MB) más el SO y los agentes (~580 MB), y en la caída del 2026-11-22 la memoria llegó al 92–99 % y el OOM killer mató a Varnish.
- La memoria por proceso se presupuesta por PSS y no por RSS (el RSS cuenta opcache y las librerías compartidas una vez por proceso y casi duplica el consumo real): 130 MB, el PSS máximo medido en producción con Ubuntu 24.04 (promedio ~103 MB frente a ~203 MB de RSS). En una instancia de 4 GB quedan 16 workers (antes 17), que cubren el pico normal de 14–16. El mínimo de workers baja de 10 a 5.
- `MaxConnectionsPerChild` baja de 10 000 a 500 para reciclar los procesos de PHP antes de que crezcan.
- `wordpress` limita el almacenamiento *Transient* de Varnish a 128 MB (`-s Transient=malloc,128m`); hasta ahora no tenía límite y crece con scrapers que piden muchas URLs distintas.

## [5.3.0] - 2026-11-23

- `wordpress` hace que Varnish se reinicie solo si muere (crash, OOM kill o `kill -9`): la unidad systemd usa `Restart=always` con `RestartSec=2` y `StartLimitIntervalSec=0`, para que nunca deje de reintentar. En la caída del 2026-11-22, `varnishd` y `cache-main` murieron en los cuatro servidores y no volvieron, dejando el puerto 80 cerrado con Apache aún arriba.
- Varnish baja su prioridad ante el OOM killer (`OOMScoreAdjust=-500`, heredado por `cache-main`), para que el kernel elija primero a Apache.
- Chef reinicia Varnish cuando cambia la unidad, para que las instancias existentes tomen la nueva configuración tras el `daemon-reload`.

## [5.2.2] - 2026-11-19

- `wordpress` configura `DPkg::Lock::Timeout` en 600 segundos (`/etc/apt/apt.conf.d/90-dpkg-lock-timeout`) antes de `apt::default`, para que cada `apt-get` espere el lock de dpkg en lugar de fallar. En el primer arranque de instancias Ubuntu 24.04, `unattended-upgrades` o una asociación de SSM podían tener tomado `/var/lib/dpkg/lock-frontend` y el bootstrap fallaba, dejando la instancia abandonada por timeout del heartbeat.

## [5.2.1] - 2026-11-18

- `wordpress` deja de instalar `php8.3-imagick` y purga ImageMagick (`libmagickwand`, `libmagickcore`, `imagemagick-6-common`): en Ubuntu 22.04 y 24.04 sus parches de seguridad solo llegan por Ubuntu Pro (ESM), así que Inspector seguía reportando CVEs críticos con exploit (CVE-2025-57807, CVE-2025-53101, CVE-2025-53014) que apt no podía corregir. WordPress usa GD; se pierden las miniaturas de PDF y el procesamiento de HEIC. Apache se reinicia tras la purga.
- La purga elige el sufijo de las librerías según la versión de Ubuntu (`7t64` en 24.04, `6` en 22.04), para cubrir también instancias noble como beta.

## [5.2.0] - 2026-11-11

- Instala Apache y PHP desde `packages.sury.org`, el repositorio propio de Ondřej Surý, en lugar de `ppa:ondrej/apache2` y `ppa:ondrej/php` en `wordpress` y `buddypress`. La llave se instala con el paquete oficial `debsuryorg-archive-keyring` y cada source usa `signed-by`, sin depender de `gpg-agent`. Ya no depende de la disponibilidad de Launchpad.
- `buddypress` ejecuta `apt-get update` después de agregar el repositorio de PHP.
- Deja de instalar `php8.3-mail`, que no existe en `packages.sury.org`; `mail()` viene incluido en PHP.
- `wordpress` usa `apt::default` en lugar de `yum::default`, que en Ubuntu solo escribía un `/etc/yum.conf` sin uso.
- Los paquetes de PHP 8.3 vuelven a instalarse con `:install` en lugar de `:upgrade`: Chef ya no actualiza PHP ni reinicia Apache en ejecuciones posteriores. Las instancias nuevas reciben la versión corregida de PHP2Shell (8.3.36 o posterior).
- Elimina el recurso redundante de `libapache2-mod-php8.3`, que ya instalan `apache2::mod_php` y la instalación conjunta de paquetes de PHP.
- La mitigación de PHP2Shell (`session.upload_progress` desactivado) pasa a ser permanente, sin importar la versión de PHP, y en el vhost también se bloquea cuando mod_php se registra como `php7_module` o `php5_module`.
- Quita `index.cgi` e `index.pl` del `DirectoryIndex` del vhost de `wordpress`, para evitar unas 7.800 líneas diarias de `AH01797 client denied` por servidor en el log de errores de Apache.

## [5.1.1] - 2026-10-21

- Mitiga PHP2Shell (CVE-2026-109618 / CVE-2026-109619) en `wordpress` y `buddypress`: actualiza en cada ejecución todos los paquetes de PHP 8.3 en una sola transacción de apt, para que las instancias existentes reciban la versión corregida (8.3.36), y reinicia Apache para que mod_php la cargue.
- Desactiva `session.upload_progress` en el SAPI de Apache (`conf.d`) y lo bloquea en el vhost con `php_admin_flag`, para que no se pueda reactivar desde `.htaccess` ni `ini_set()`.
- Registra un aviso en el log de Chef, sin fallar la ejecución, mientras `libapache2-mod-php8.3` sea anterior a 8.3.36.

## [5.1.0] - 2026-10-20

- Deja de escribir en el log de Chef los valores de las variables de entorno (contraseña de la base de datos, credenciales SMTP, URL del repositorio); ahora solo se registran sus nombres en `wordpress` y `buddypress`.
- Actualiza las variables ya existentes en `/etc/apache2/envvars` y `/etc/environment` en vez de solo agregar las que faltan, para que las credenciales rotadas lleguen a las instancias.
- Lee con descifrado los parámetros secretos de Parameter Store (SMTP, base de datos, llave RSA privada, licencia de New Relic y URL del repositorio), lo que permite pasarlos a `SecureString`.
- Elimina el código ligado a parámetros que no se usaban: la instalación de `php-ssh2` y la redirección `FORCE_SSL_DNS` del VCL en `wordpress`, y las variables `PHP_*_ENABLE` y la instalación de `php-ssh2` en `buddypress`.
- Activa las métricas de procesos de New Relic Infrastructure en `wordpress` y `buddypress`, limitadas a los procesos del stack web (Apache, Varnish, New Relic y Fluent Bit).
- Envía los logs de Apache a New Relic con el atributo `logtype` para que se parseen correctamente.
- Registra en el log de acceso de Apache la IP real del cliente tomada de `X-Forwarded-For`.
- Instala el repositorio apt de New Relic en `buddypress` sin depender de `gpg-agent`.
- Renombra el recurso SSM de la licencia de New Relic.
- Ajusta el TTL por defecto de Varnish a 7,5 minutos y corrige el formato de la cabecera `Expires`.
- Quita las referencias a Zona Digital del cookbook `wordpress`.
