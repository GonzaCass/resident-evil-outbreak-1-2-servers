# Resident Evil Outbreak File 1 y 2 Server en Docker

Servidor Docker para levantar los servicios online de `Biohazard / Resident Evil Outbreak File 1` y `File 2`.

La imagen construye Apache con OpenSSL compatible con PS2, PHP 7.4, MariaDB y los servidores Java de `bioserver`. El `docker-compose.yml` deja el contenedor en `network_mode: host`, por lo que los servicios quedan escuchando directamente en la maquina host.

## Requisitos

- Linux con Docker y Docker Compose.
- Puertos libres en el host: `80`, `443`, `8200`, `8300`, `8590` y `8690`.
- Una IP o dominio que el cliente del juego pueda alcanzar.
- Resolucion DNS para los dominios que usa el juego.
- Hairpin NAT / NAT loopback en el router si el host tambien quiere entrar al servidor usando la IP publica o dominio desde la misma red LAN.

> Nota: `network_mode: host` funciona como se espera en Linux. En Docker Desktop para Windows o macOS el modo host no expone la red de la misma forma, por lo que este compose esta pensado para ejecutarse en Linux.

## Puertos usados

| Puerto | Uso |
| --- | --- |
| `80/tcp` | HTTP del flujo web del juego |
| `443/tcp` | DNAS / HTTPS compatible con PS2 |
| `8200/tcp` | Lobby de Outbreak File 2 |
| `8300/tcp` | Lobby de Outbreak File 1 |
| `8590/tcp` | Game server de Outbreak File 2 |
| `8690/tcp` | Game server de Outbreak File 1 |

Antes de levantar el servidor, verifica que no haya otro proceso usando esos puertos:

```bash
sudo ss -ltnp | grep -E ':(80|443|8200|8300|8590|8690)\b'
```

Si algun puerto aparece ocupado, hay que detener el servicio que lo esta usando o mover este servidor a otra maquina.

## Configuracion de IP publica o LAN

El valor `EXTERNAL_IP` es la direccion que el servidor informa al juego para conectarse a los lobbies y partidas. Puede ser:

- IP LAN, por ejemplo `192.168.1.50`, si vas a jugar dentro de la misma red.
- IP publica o dominio, por ejemplo `outbreak.midominio.com`, si vas a conectarte desde internet.

Antes de levantarlo, edita `docker-compose.yml` y cambia `EXTERNAL_IP` por la IP o dominio que vayan a usar los clientes:

```yaml
environment:
  - MYSQL_ROOT_PASSWORD=reoutbreak
  - EXTERNAL_IP=TU_IP_PUBLICA_O_DOMINIO
```

### Host jugando en su propio servidor

Si quien hostea tambien quiere jugar con amigos en el mismo servidor, hay dos casos:

- Con una VPN/tunel tipo Hamachi, ZeroTier o similar, se puede usar la IP de esa red virtual como `EXTERNAL_IP` y hacer que todos resuelvan los dominios del juego hacia esa IP.
- Sin VPN/tunel, si el host o jugadores dentro de la misma LAN entran usando el dominio o IP publica, el router necesita soportar hairpin NAT, tambien llamado NAT loopback. Sin eso, los clientes internos no van a poder volver hacia la IP publica del propio router.

Si el router no soporta hairpin NAT, una alternativa es usar DNS dividido: dentro de la LAN, `gate1.jp.dnas.playstation.org` y `www01.kddi-mmbb.jp` apuntan a la IP LAN del host Docker; fuera de la LAN apuntan a la IP publica.

## Levantar el servidor

```bash
git clone git@github.com:GonzaCass/resident-evil-outbreak-1-2-servers.git
cd resident-evil-outbreak-1-2-servers
docker compose up -d --build
```

Ver logs:

```bash
docker compose logs -f outbreak-server
```

Detener:

```bash
docker compose down
```

Recrear desde cero, incluyendo la base de datos:

```bash
docker compose down -v
docker compose up -d --build
```

## DNS necesario para conectarse

El juego busca los servidores originales por dominio. El cliente debe resolver estos nombres hacia la IP del host donde corre Docker:

- `gate1.jp.dnas.playstation.org`
- `www01.kddi-mmbb.jp`

Este contenedor no levanta un servidor DNS propio. Podes resolverlo de alguna de estas formas:

- Configurar overrides DNS en tu router, Pi-hole, dnsmasq u otro DNS local.
- Usar un DNS externo propio si vas a jugar por internet.
- Usar un ISO/parche/configuracion del emulador que ya redirija esos dominios al servidor.

Si queres usar DNS local, la idea es que ambos dominios apunten a la IP LAN del host Docker. Ejemplo conceptual:

```text
gate1.jp.dnas.playstation.org -> 192.168.1.50
www01.kddi-mmbb.jp            -> 192.168.1.50
```

## Bases de datos

Los archivos `bioserver1.sql` y `bioserver2.sql` quedan versionados en este repo como copia de referencia de los esquemas de File 1 y File 2.

En el arranque normal, el contenedor inicializa MariaDB usando los SQL que vienen dentro del repositorio `bioserver` clonado durante el build:

- `/root/bioserver/bioserv1/database/bioserver.sql`
- `/root/bioserver/bioserv2/database/bioserver.sql`

MariaDB persiste en el volumen `db_data`. Por eso, si modificas los SQL despues de haber levantado el contenedor, los cambios no se aplican automaticamente sobre una base ya creada. Para recrearla desde cero:

```bash
docker compose down -v
docker compose up -d --build
```

## Como conectarse desde el juego

1. Levanta el servidor con `EXTERNAL_IP` apuntando a una IP o dominio alcanzable por la consola/emulador.
2. Asegurate de que los puertos necesarios esten libres y, si jugas desde internet, abiertos/forwardeados en el router.
3. Configura la PS2 o PCSX2 para que use un DNS que resuelva `gate1.jp.dnas.playstation.org` y `www01.kddi-mmbb.jp` hacia tu servidor.
4. Entra al modo online de `Resident Evil Outbreak File 1` o `File 2`.
5. File 1 debe conectar al lobby en `8300` y usar partidas en `8690`.
6. File 2 debe conectar al lobby en `8200` y usar partidas en `8590`.

## Consideraciones

- No ejecutes Apache, Nginx u otro servicio web en el mismo host usando `80` o `443`.
- Si tenes Traefik corriendo en el mismo host y usando `80`/`443`, el compose actual no va a poder levantar porque el servidor necesita esos puertos directamente.
- Se podria armar una configuracion avanzada con Traefik haciendo proxy TCP/passthrough, pero para este servidor no conviene terminar TLS en Traefik: DNAS usa compatibilidad SSL/TLS vieja de PS2 y Apache esta compilado/configurado para eso. Ademas, si el cliente no envia SNI, compartir `443` con otros sitios HTTPS detras de Traefik se vuelve problematico. La opcion simple es detener Traefik, usar otra maquina/IP, o dedicar esos puertos a Outbreak mientras el servidor este activo.
- MariaDB corre dentro del contenedor y persiste en el volumen `db_data`.
- Si cambias `EXTERNAL_IP` despues del primer arranque, recrea el contenedor para que se regenere la configuracion:

```bash
docker compose down
docker compose up -d
```

- Si necesitas reiniciar tambien la base de datos, usa `docker compose down -v`.

## Creditos

Este proyecto se basa en el trabajo original de `corbin-ch/bioserver-docker`, `corbin-ch/bioserver` y `corbin-ch/DNASrep`, ademas del proyecto BioServer/obsrv.org para la emulacion del servidor de Outbreak.
