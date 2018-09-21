# Migrations

You may wish to migrate a database and/or files from another server, which does not have Loft Deploy installed.  As long as you can `scp` and `rsync` into this other server you can use this feature.

Migrations are unique in that they do implement the file excludes or the database filters.  In other words, all tables, and all files.

Hooks are available, you can see the hooks if you run a migration with the `-v` option.

**Also, migrations affect the destination server immediately,** they are unlike the fetch/pull strategy.  When you migrate, the database is directly imported and the files are immediately deleted to match the source.

In a migration, the database is backed up unless you use the `--nobu` option.  The files are NOT backed up.

## On the source server

1. Create a mysql dump of the database and take note of it's path.
1. Take note of the paths to each of the user files directories, up to 3.

## On the destination server (the one you are migrating to)

1. Add something like the following to your Loft Deploy configuration file _.loft_deploy/config.yml_.  You do not need to add both `database` and `files` as they can act independently, if desired.

        migration:
          title: d8-staging.mysite.com
          database:
            user: cwcd8
            host: 192.168.0.100
            path: /home/parrot/backups/migrate.sql.gz
          files:
          - user: parrot
            host: 192.168.0.100
            path: /home/parrot/public_html/web/sites/default/files
          - user: parrot
            host: 192.168.0.100
            path: /home/parrot/public_html/private/default/files

1. Clear caches to update the config `ldp cc`.
1. Check your configration with `ldp info`; you should see a migration section with the paths to the assets you can migrate.
1. When you are ready call `lpd migrate`.  You will asked to confirm each step.    

