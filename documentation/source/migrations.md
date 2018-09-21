# Migrations

You may wish to migrate a database and/or files from another server, which does not have Loft Deploy installed.  As long as you can scp and rsync into this other server you can use this feature.

Migrations are unique in that they do not allow filters or hooks at this time.  In other words, all tables, and all files

## On destination server

1. Create a mysql dump of the database and take note of it's path

## On the source server

Add something like the following to your Loft Deploy configuration and do `ldp cc`.  The role that you choose will determine where the files are staged within Loft Deploy on your destination server.  If you choose prod, they will appear in the same folder as if you had done `ldp pull prod`.

    migration:
      role: prod
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
    

1. Check your configration with `ldp info`; you should see a migration section with the paths to the assets you can migrate.

    

ldp export migrate
cd path/to/dbs

? enter the name of the db dump
scp *-migrate.sql.gz challengestaging@166.62.85.248:/home/challengestaging/releases/current/private/default/db/purgeable
