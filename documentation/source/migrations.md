# Migrations

You may wish to migrate a database and/or files from another server, which does not have Loft Deploy installed.  As long as you can `scp` and `rsync` from this other server you can use this feature.  If you cannot then see the section _The Push Option_ for a method to push the files to your destination server.

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
1. When you are ready call `ldp migrate`.  You will asked to confirm each step.    

## The Push Option

If you try to migrate and the process hangs, [one issue](https://superuser.com/questions/395356/scp-doesnt-work-but-ssh-does#396667) may be that there is a problem with the SSH tunnel made during the `scp` operation.  In any event you can use the `--push` option to create a markdown file with step by step instructions and code snippets to run **on the source server** to push the files to your destination by hand.

The second part of this method requires the you do a manual `ldp import` of the database file **on the destination server**, so don't miss that step.

Simply call `ldp migrate --push` to see the output on the screen.  As a sidenote, the configuration is the same as above, you still need to add the `migration` array to your configuration file.

Or pipe it to a file like this `ldp migrate --push > migrate.md`.

Follow the instructions therein. 
