# MongoDB Hot Backup for Docker

# Docker Hot Backup

This project provides script to run [Hot Backup](#hot-backup) for [percona/percona-server-mongodb].

The `mongo` container needs to be setup with local mount:

```yml
version: "3"

services:
  mongo:
    image: percona/percona-server-mongodb:3.4
    # (case sensitive) engine: mmapv1, rocksdb, wiredTiger, inMemory
    command: --storageEngine=wiredTiger
    volumes:
      - /srv/backups/mongodb:/backup
    ports:
      - 27017:27017

# vim:ts=2:sw=2:et
```

To run the backup, specify container name or id on commandline:

```
./backup-mongodb.sh CONTAINER BACKUP_DIR
```

- `CONTAINER` can be id, name, label, or swarm service name
- `BACKUP_DIR` is path that is bind mounted into container: `-v $EXTERNAL_BACKUP_DIR:$CONTAINER_BACKUP_DIR` the value for local dir is detected automatically

[percona/percona-server-mongodb]: https://hub.docker.com/r/percona/percona-server-mongodb/

## Hot Backup

[Percona Server for MongoDB] includes an integrated open-source hot backup system for the default [WiredTiger] and alternative [MongoRocks] storage engine. It creates a physical data backup on a running server without notable performance and operating degradation.

[Percona Server for MongoDB]: https://www.percona.com/software/mongo-database/percona-server-for-mongodb
[WiredTiger]: https://docs.mongodb.org/manual/core/wiredtiger/
[MongoRocks]: https://www.percona.com/doc/percona-server-for-mongodb/LATEST/mongorocks.html#mongorocks

To take a hot backup of the database in your current `dbpath`, run the `createBackup` command as administrator on the `admin` database and specify the backup directory.

```
> use admin
switched to db admin
> db.runCommand({createBackup: 1, backupDir: "/my/backup/data/path"})
{ "ok" : 1 }
```

If the backup was successful, you should receive an `{ "ok" : 1 }` object. If there was an error, you will receive a failing `ok` status with the error message, for example:

```
> db.runCommand({createBackup: 1, backupDir: ""})
{ "ok" : 0, "errmsg" : "Destination path must be absolute" }
```

https://www.percona.com/doc/percona-server-for-mongodb/LATEST/hot-backup.html
