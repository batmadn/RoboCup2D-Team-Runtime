#!/bin/sh

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
exec sh "${SCRIPT_DIR}/start.sh" --offline-logging --debug --debug-server-connect ${1+"$@"}
