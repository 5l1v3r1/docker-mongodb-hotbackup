#!/bin/sh

# Exit on errors
set -e

die() {
	echo >&2 "$*"
	exit 1
}

# find running container; return false if nothing found
docker_ps() {
	local filter="$1" id

	id=$(docker ps -qf "$filter")
	if [ -n "$id" ]; then
		echo "$id"
		return 0
	fi
	return 1
}

# find container by:
# - id
# - name
# - label
# - swarm service name
find_container() {
	local token="$1" id

	docker_ps id="$token" || \
	docker_ps name="$token" || \
	docker_ps label="$token" || \
	docker_ps label=com.docker.swarm.service.name="$token"
}

# https://www.adelton.com/docs/containers/docker-inspect-volumes-mounts
# find path that is bind mounted into container
docker_find_bind_mount() {
	local container="$1" path="$2"

	docker inspect --format "{{ range .Mounts }}{{ if eq .Destination \"$path\" }}{{ .Source }}{{ end }}{{ end }}" "$container"
}

dirsize() {
	local dir="$1"
	du -sk "$dir" | awk '{print $1}'
}

# run backup inside container
create_backup() {
	local container="$1" backup_dir="$2" user="$3" password="$4" local_dir out size

	local_dir=$(docker_find_bind_mount "$container" "$backup_dir")
	test -z "$local_dir" && die "Could not find bind mount for $backup_dir"

	# Clean up old backup. do it inside container for safety
	docker exec $container sh -c "rm -rf '$backup_dir'/*" || die "Could not cleanup $backup_dir"
	size=$(dirsize "$local_dir")
	if [ "$size" -gt 0 ]; then
		die "Could not cleanup $backup. $size remaining"
	fi

	out=$(mktemp)
	if [ -n "$user" ] && [ -n "$password" ]; then
		docker exec $container mongo -u $user -p $password admin --eval "db.runCommand({createBackup: 1, backupDir: '$backup_dir'})" > $out
	else
		docker exec $container mongo admin --eval "db.runCommand({createBackup: 1, backupDir: '$backup_dir'})" > $out
	fi

	if ! grep -q '"ok" : 1' $out; then
		cat >&2 "$out"
		rm "$out"
		return 1
	fi
	rm "$out"

	size=$(dirsize "$local_dir")
	if [ "$size" -le 0 ]; then
		die "Backup empty. size: $size"
	fi
	echo "Backup Created: $size KiB: $local_dir"
}

# CONTAINER can be id, name, label, or swarm service name
# BACKUP_DIR is path that is bind mounted into container:
# -v $EXTERNAL_BACKUP_DIR:$CONTAINER_BACKUP_DIR
# the value for local dir is detected automatically
# when USER and PASSWORD are filled, then backup is done via authentication

[ -z "$2" ] && die "Usage: $0 CONTAINER BACKUP_DIR USER PASSWORD"

# take container name from commandline
container=$(find_container "$1") || die "Could not find running container"
backup_dir="$2"
user="$3"
password="$4"

create_backup "$container" "$backup_dir" "$user" "$password" || die "Failed to create backup"
