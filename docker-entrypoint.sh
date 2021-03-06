#!/usr/bin/dumb-init /bin/bash

PID_FILE="/tmp/haproxy.pid"
CONFIG=${CONFIG_FILE:-"/data/haproxy.cfg"}
WATCH_FILES="$CONFIG $EXTRA_WATCH_FILES"
CHECK_CONFIG_CMD="haproxy -c -f $CONFIG"
PRINT_VERSION="haproxy -vv"
STORE_OLD_CFG="cp $CONFIG /tmp/old_haproxy.cfg"
RUN_HAPROXY_CMD="haproxy -D -f $CONFIG -p $PID_FILE"

function log() { echo "`date +'%Y/%m/%d %T'` <container> $@"; }

cd /data

$PRINT_VERSION
$STORE_OLD_CFG
$CHECK_CONFIG_CMD || exit $?

trap "trap - SIGTERM && kill -SIGUSR1 \$(cat $PID_FILE) ; kill 0" SIGINT SIGTERM EXIT

$RUN_HAPROXY_CMD || exit $?

log "Started haproxy"
log "Listening for $WATCH_FILES changes."

while inotifywait -q -r -e modify,attrib,create,delete $WATCH_FILES; do
  if [ -f $PID_FILE ] ; then
    sleep 5 #graceful period for mutiple files update
    log "Config $CONFIG update event received, diff: "
    diff /tmp/old_haproxy.cfg $CONFIG
    log "Checking updated config"
    if $CHECK_CONFIG_CMD ; then
      log "Check OK, restarting haproxy"
      $STORE_OLD_CFG
      $RUN_HAPROXY_CMD -sf `cat $PID_FILE`
      log "Successfuly restarted haproxy"
    else
      log "Check failed, no restart performed, haproxy will continue to use the old working config. Please fix the new config file."
    fi
  else
    log "Fatal, no PID file"
    exit 999
  fi
done
