# Changelog

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
