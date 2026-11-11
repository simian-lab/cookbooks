# Changelog

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
