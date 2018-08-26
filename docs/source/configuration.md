# Configuration Examples

After configuration changes you must call `ldp clearcache`.
See _includes/schema--config.json_ for more info.

## Example A

* Local site using Drupal _settings.php_ for database connection.
* Production and staging connection via SSH

        local:
          location: ITLS
          url: website.local
          basepath: /Users/aklump/Code/Projects/Client/Website/site/dist/
          role: dev
          files:
          - private/default/files
          - web/sites/default/files
          database:
            backups: private/default/db/purgeable
          drupal:
            root: web
            settings: web/sites/default/settings.php
            database: default
        production:
          config: /var/www/website/.loft_deploy
          script: /usr/local/bin/loft_deploy
          user: USERNAME
          ip: NN.NN.NNN.NNN
        staging:
          config: /var/www/stage.website/.loft_deploy
          script: /usr/local/bin/loft_deploy
          user: USERNAME
          ip: NN.NN.NNN.NNN

| local property | description |
|----------|----------|
| location | The business name of the physical location |
| url | The URL of the local website without protocol |
| basepath | The local path to the project, this is prepended to all other paths in _local_, which do not begin with a forward slash |
| role | one of: dev, staging, production |
| files | up to three relative or absolute local file paths, which will be used in the files operations |
| database | See below |
| drupal | See below |

## Example B

* Local site using explicit mysql credentials.
* No production nor staging servers.

        local:
          location: ITLS
          url: website.local
          basepath: /Users/aklump/Code/Projects/Client/Website/site/dist/
          role: dev
          files:
          - private/default/files
          - web/sites/default/files
          database:
            backups: private/default/db/purgeable
            host: localhost
            user: DB_USER
            password: "PASSWORD-GOES-HERE"
            name: DB_NAME

## Indicating Specific Binaries

You can define the binaries (except PHP) to use; more info in _includes/schema--config.json_.

        bin:
          mysql: /Applications/MAMP/Library/bin/mysql
          gzip: /usr/bin/gzip

## To indicate PHP version

If you need to specify a php version you must add the following to _.bash_profile_ or _.bashrc_.  You cannot add PHP to the YAML configuration.

    export LOFT_DEPLOY_PHP="/Applications/MAMP/bin/php/php7.1.12/bin/php"