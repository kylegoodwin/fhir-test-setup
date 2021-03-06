#!/bin/sh -e

cmdname="$(basename "$0")"
bin_path="$(cd "$(dirname "$0")" && pwd)"
repo_path="${bin_path}/.."


usage() {
    cat << USAGE >&2
Usage:
    $cmdname [-h] [-b backup_location]
    -h     Show this help message
    -b     Override default backup location (/tmp)
    Application backup script
    Dump application database and uploaded content
USAGE
    exit 1
}

while getopts "hb:" option; do
    case "${option}" in
        b)
            backups_dir="${OPTARG}"
            ;;
        h)
            usage
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

default_backups_dir=/tmp
BACKUPS_DIR="${backups_dir:-$default_backups_dir}"

# docker-compose commands must be run in the same directory as docker-compose.yaml
#docker_compose_directory="${repo_path}"
cd "../"

if [ -z "$(docker-compose ps --quiet postgres)" ]; then
    >&2 echo "Error: database not running"
    exit 1
fi

# get COMPOSE_PROJECT_NAME (see .env)
compose_project_name="$(
    docker inspect "$(docker-compose ps --quiet postgres)" \
        --format '{{ index .Config.Labels "com.docker.compose.project"}}'
)"
web_image_hash="$(docker-compose images --quiet hapi | cut -c1-7)"
dump_filename="psql_dump-$(date --iso-8601=seconds)-${web_image_hash}-${compose_project_name}"

echo "Backing up current database..."

docker-compose exec -T --user postgres postgres bash -c '\
    PGPASSWORD=postgres pg_dump \
        --dbname hapifhir \
        --username postgres \
        --no-acl \
        --no-owner \
        --encoding utf8 '\
> "${BACKUPS_DIR}/${dump_filename}.sql"


echo "Backup complete"
