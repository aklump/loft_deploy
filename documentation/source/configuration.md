---
id: config
---

# The _config.yml_ File Explained

## Remote Servers

* See _includes/schema--config.json_ for more info.
* Production and staging connection via SSH

| local property | description |
|----------|----------|
| config | Absolute path to the _.loft_deploy_ directory |
| script | Absolute path to the _ldp_ binary |
| user | SSH username |
| ip | SSH hostname or IP address |

```yaml
production:
  config: /var/www/website/.loft_deploy
  script: /usr/local/bin/ldp
  user: USERNAME
  ip: NN.NN.NNN.NNN

staging:
  config: /var/www/test.website/.loft_deploy
  script: /usr/local/bin/ldp
  user: USERNAME
  ip: NN.NN.NNN.NNN
```

## Local Server Config

```yaml
local:
  location: ITLS
  url: website.local
  basepath: /Users/aklump/Code/Projects/Client/Website/site/dist/
  role: dev
  files:
    - private/default/files
    - web/sites/default/files
```

| local property | description |
|----------|----------|
| location | The business name of the physical location |
| url | The URL of the local website without protocol |
| basepath | The absolute local path to the project root; used to resolve relative links in the `local` configuration.  (This is prepended to all other paths in _
local_, which do not begin with a forward slash) |
| role | One of: dev, staging, production |
| files | Up to three relative or absolute local file paths, which will be used in the files operations |
| drupal | Use this with a Drupal application to read in the database settings automatically. |
| drupal.root | _Required._  Relative path to the Drupal web root. |
| drupal.settings | < Drupal 8 only. Relative path to the _settings.php_. |
| drupal.database | The database key if other than `default`. |
| database | _See different configurations below..._ |
| database.backups | _Required._ Relative path to the backup directory for database exports. |

## Local Database Connection Configurations

### Example A: Any MySQL DB

* Local site using explicit mysql credentials.
* No production nor staging servers.

```yaml
local:
  database:
    backups: private/default/db/purgeable
    host: localhost
    user: DB_USER
    password: "PASSWORD-GOES-HERE"
    name: DB_NAME
```

### Example B: A Drupal Application

* Local site using Drupal _settings.php_ for database connection.
* NOTE: If you change DB credentials in Drupal's _settings.php_, you will need
  to call `ldp clearcache` manually.
* Starting in Drupal 8, you do not need to include `local.drupal.settings`.
* `local.drupal.database` will default to `default`, when not provided.

```yaml
local:
  drupal:
    root: web
    settings: web/sites/default/settings.php
    database: default
  database:
    backups: private/default/db/purgeable
```

###:lando Example C: Using Lando

When using Lando you need to indicate the name of the Lando database service.
This will be used to resolve the local/host database connections.

```yaml
local:
  database:
    backups: private/default/db/purgeable
    lando: database
```

However, **if also using Drupal, you must** set the value to `@drupal` as in
this second example; this indicates that lando should convert the Drupal settings to the external/host credentials before passing them off to Loft Deploy.

```yaml
local:
  drupal:
    root: web
  database:
    backups: private/default/db/purgeable
    lando: '@drupal'
```    

## Indicating Specific Binaries

You can define the binaries (except PHP) to use; more info in _
includes/schema--config.json_.

```yaml
bin:
  mysql: /Applications/MAMP/Library/bin/mysql
  gzip: /usr/bin/gzip
```

## To indicate PHP version

You can override the PHP version by setting the environment
variable `LOFT_DEPLOY_PHP` with the path to the correct version. Note: You
cannot add PHP to the YAML configuration.

```bash
export LOFT_DEPLOY_PHP="/Applications/MAMP/bin/php/php7.1.12/bin/php"
```

If you're calling this from the CLI you can do like this:

```bash
export LOFT_DEPLOY_PHP=/Applications/MAMP/bin/php/php7.1.12/bin/php; ldp export foo_bar -fy
```

### On Remote Server

1. Open _~/.bashrc_ and add this line (adjusted per correct path to php).
2. `export LOFT_DEPLOY_PHP=/usr/local/php74/bin/php`
