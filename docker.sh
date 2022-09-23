#!/bin/sh
#
[ ! -d redis-data ] && mkdir redis-data
 
[ $(docker ps -q -f name=^argot$) ] || docker exec -it -w /app argot /bin/bash

