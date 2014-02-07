#!/bin/bash

if [ -f ./fbdev_config.sh ]; then
    . ./fbdev_config.sh
else
    echo "ERROR: No fbdev_config.sh file found!"
    echo "Please create your own config from template file fbdev_config.sh.template"
    exit 1
fi

cd $FHIRBASE_HOME;

function install_cmd {
    if [ -z "$1" ]; then
        echo "install command requires dbname argument"
        exit 1
    else
        coffee --compile --output js js_src
        $PG_BIN_DIR/psql $PSQL_ARGS -d $1 < install.sql
    fi
}

function recreate_db {
    echo "DROP DATABASE $1; CREATE DATABASE $1;" | $PG_BIN_DIR/psql $PSQL_ARGS -d postgres;
}

function test_cmd {
    recreate_db $TEST_DB_NAME
    cd $FHIRBASE_HOME/test && $FHIRBASE_HOME/pg_prove $PSQL_ARGS -d $TEST_DB_NAME $FHIRBASE_HOME/test/*_test.sql
}

case "$1" in
    "test" )
        test_cmd
        ;;
    "install" )
        install_cmd $2
        ;;
    "build" )
        recreate_db $BUILD_DB_NAME
        install_cmd $BUILD_DB_NAME

        $PG_BIN_DIR/pg_dump $PSQL_ARGS \
          --format=plain \
          --schema=fhir $BUILD_DB_NAME \
          --no-owner > $FHIRBASE_HOME/../fhirbase.sql &&
          echo "FhirBase schema successfully dumped to $FHIRBASE_HOME/../fhirbase.sql"
        ;;
esac
