#!/bin/sh

. ./fbdev_config.sh

case "$1" in
    "install" )
        coffee --compile --output js js_src
        psql $PSQL_ARGS < install.sql
esac
