#!/bin/bash

function show_help {
    echo "Options:"
    echo "-h, --help: Show this help message"
    echo "-i, --install: Run 'mvn install' first"
}

install=false
version=0.1.0

while :; do
    case $1 in
        -h|--help)
            show_help
            exit
            ;;
        -i|--install)
            install=true
            ;;
        --)
            shift
            break
            ;;
        *)
            break
            ;;
    esac
    shift
done

mkdir -p log
./docker-database/run.sh > log/docker.log 2> log/docker.error.log &


if [[ "$install" = true ]]; then
    echo "Installing all modules"
    mvn install
fi

psql_res="false"

while [[ "$psql_res" != "true" ]]; do
    echo "Waiting for database to be up"
    sleep 1
    # TODO: Extract user/pw/port to parameters?!

    DOCKER_MACHINE=$(which docker-machine)

    if [[ ! "$DOCKER_MACHINE" = "" ]]; then
        VM=default
        HOST=$(docker-machine ip $VM 2>/dev/null)
    else
        HOST="localhost"
    fi

    PORT=5432
    DATABASE=ems
    USERNAME=ems
    PASSWORD=ems
    echo "$HOST:$PORT:$DATABASE:$USERNAME:$PASSWORD" > ~/.pgpass
    chmod 0600 ~/.pgpass
    psql_res="$(psql -p $PORT -h $HOST -U ems -c '\echo true' 2> /dev/null)"
done

cd importer-launcher
java -jar target/importer-launcher-${version}.jar > ../log/importer-launcher.log  2> ../log/importer-launcher.error.log &
cd ..
cd importer-database
mvn exec:java > ../log/importer-database.log 2> ../log/importer-database.error.log &
cd ..
mvn spring-boot:run -pl rest-endpoint > log/rest-endpoint.log 2> log/rest-endpoint.error.log &
