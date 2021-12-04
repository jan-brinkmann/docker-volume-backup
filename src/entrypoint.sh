#!/bin/bash

# Exit immediately on error
set -e

# Read .rotate-backups.ini
ROTATE_HOURLY=$(cat /config/rotate-backups.ini | grep hourly | grep -o -E '[0-9]+')
ROTATE_HOURLY="${ROTATE_HOURLY:-$(cat /config/rotate-backups.ini | grep hourly | grep -o -E 'always')}"
ROTATE_DAILY=$(cat /config/rotate-backups.ini | grep daily | grep -o -E '[0-9]+')
ROTATE_DAILY="${ROTATE_DAILY:-$(cat /config/rotate-backups.ini | grep daily | grep -o -E 'always')}"
ROTATE_WEEKLY=$(cat /config/rotate-backups.ini | grep weekly | grep -o -E '[0-9]+')
ROTATE_WEEKLY="${ROTATE_WEEKLY:-$(cat /config/rotate-backups.ini | grep weekly | grep -o -E 'always')}"
ROTATE_MONTHLY=$(cat /config/rotate-backups.ini | grep monthly | grep -o -E '[0-9]+')
ROTATE_MONTHLY="${ROTATE_MONTHLY:-$(cat /config/rotate-backups.ini | grep monthly | grep -o -E 'always')}"
ROTATE_YEARLY=$(cat /config/rotate-backups.ini | grep yearly | grep -o -E '[0-9]+')
ROTATE_YEARLY="${ROTATE_YEARLY:-$(cat /config/rotate-backups.ini | grep yearly | grep -o -E 'always')}"

# Write cronjob env to file, fill in sensible defaults, and read them back in
cat <<EOF > env.sh
BACKUP_SOURCES="${BACKUP_SOURCES:-/backup}"
BACKUP_CRON_EXPRESSION="${BACKUP_CRON_EXPRESSION:-@daily}"
AWS_S3_BUCKET_NAME="${AWS_S3_BUCKET_NAME:-}"
AWS_GLACIER_VAULT_NAME="${AWS_GLACIER_VAULT_NAME:-}"
AWS_EXTRA_ARGS="${AWS_EXTRA_ARGS:-}"
SCP_HOST="${SCP_HOST:-}"
SCP_USER="${SCP_USER:-}"
SCP_DIRECTORY="${SCP_DIRECTORY:-}"
BACKUP_FILENAME=${BACKUP_FILENAME:-"backup-%Y-%m-%dT%H-%M-%S.tar.gz"}
BACKUP_ARCHIVE="${BACKUP_ARCHIVE:-/archive}"
BACKUP_UID=${BACKUP_UID:-0}
BACKUP_GID=${BACKUP_GID:-$BACKUP_UID}
BACKUP_WAIT_SECONDS="${BACKUP_WAIT_SECONDS:-0}"
BACKUP_HOSTNAME="${BACKUP_HOSTNAME:-$(hostname)}"
GPG_PASSPHRASE="${GPG_PASSPHRASE:-}"
INFLUXDB_URL="${INFLUXDB_URL:-}"
INFLUXDB_DB="${INFLUXDB_DB:-}"
INFLUXDB_CREDENTIALS="${INFLUXDB_CREDENTIALS:-}"
INFLUXDB_MEASUREMENT="${INFLUXDB_MEASUREMENT:-docker_volume_backup}"
BACKUP_CUSTOM_LABEL="${BACKUP_CUSTOM_LABEL:-}"
ROTATE_BACKUPS="${ROTATE_BACKUPS:-}"
ROTATE_HOURLY="${ROTATE_HOURLY:-0}"
ROTATE_DAILY="${ROTATE_DAILY:-0}"
ROTATE_WEEKLY="${ROTATE_WEEKLY:-0}"
ROTATE_MONTHLY="${ROTATE_MONTHLY:-0}"
ROTATE_YEARLY="${ROTATE_YEARLY:-0}"
EOF
chmod a+x env.sh
source env.sh

# Configure AWS CLI
mkdir -p .aws
cat <<EOF > .aws/credentials
[default]
aws_access_key_id = ${AWS_ACCESS_KEY_ID}
aws_secret_access_key = ${AWS_SECRET_ACCESS_KEY}
EOF
if [ ! -z "$AWS_DEFAULT_REGION" ]; then
cat <<EOF > .aws/config
[default]
region = ${AWS_DEFAULT_REGION}
EOF
fi

# Add our cron entry, and direct stdout & stderr to Docker commands stdout
echo "Installing cron.d entry: docker-volume-backup"
echo "$BACKUP_CRON_EXPRESSION root /root/backup.sh > /proc/1/fd/1 2>&1" > /etc/cron.d/docker-volume-backup

# Let cron take the wheel
echo "Starting cron in foreground with expression: $BACKUP_CRON_EXPRESSION"
cron -f
