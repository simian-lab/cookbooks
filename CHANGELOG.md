# Changelog

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
