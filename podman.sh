#!/bin/sh
#
[ ! -d redis-data ] && mkdir redis-data

[ $(podman ps -q -f name=^argot$) ] || podman-compose start
 
podman exec -it -w /app argot /bin/bash

