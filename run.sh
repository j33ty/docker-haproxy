#!/bin/sh
docker run -d --rm --name "haproxy" --net=host \
		--ulimit "nofile=1048576:1048576" \
		-e CONFIG_FILE=haproxy.cfg \
		-v /data/haproxy/config:/data \
		-e EXTRA_WATCH_FILES="/data/certs" haproxy:latest
