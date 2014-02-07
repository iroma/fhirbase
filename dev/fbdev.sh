#!/bin/bash

. ./fbdev_config.sh

cd $FHIRBASE_HOME;

function install_cmd {
    if [ -z "$1" ]; then
        echo "install command requires dbname argument"
        exit
    else
        coffee --compile --output js js_src
        $PG_BIN_DIR/psql $PSQL_ARGS -d $1 < install.sql
    fi
}

case "$1" in
    "install" )
        install_cmd $2
        ;;
    "build" )
        # echo "DROP DATABASE $BUILD_DB_NAME; CREATE DATABASE $BUILD_DB_NAME;" | $PG_BIN_DIR/psql $PSQL_ARGS -d postgres;
        # install_cmd $BUILD_DB_NAME
        $PG_BIN_DIR/pg_dump $PSQL_ARGS --format=plain --schema=fhirr $BUILD_DB_NAME > $FHIRBASE_HOME/../fhirbase.sql &&
          echo "FhirBase schema successfully dumped to $FHIRBASE_HOME/../fhirbase.sql"
esac
