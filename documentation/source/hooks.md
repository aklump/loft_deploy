---
id: hooks
---
# Hooks

## Quick Start

The hook filename is comprised of: OPERATION_{ASSET_}POSITION, e.g.

    .loft_deploy/hooks/
    ├── fetch_db_post.sh
    ├── fetch_db_pre.sh
    ├── fetch_files_post.sh
    ├── fetch_files_pre.sh
    ├── fetch_post.sh
    ├── fetch_pre.sh
    ├── pull_db_post.sh
    ├── pull_db_pre.sh
    ├── pull_files_post.sh
    ├── pull_files_pre.sh
    ├── pull_post.sh
    ├── pull_pre.sh
    ├── reset_db_post.sh
    ├── reset_db_pre.sh
    ├── reset_files_post.sh
    ├── reset_files_pre.sh
    ├── reset_post.sh
    └── reset_pre.sh

## Description

You may create `.sh` files that will execute before or after an operation.  These are called hooks and should be created in `.loft_deploy/hooks`.  An example is a hook to be executed after a `reset` operation, you need only create a file at using the pattern `OPERATION_{ASSET_}POSITION`.  The variables from _loft_deploy.sh_ are available to your hook files, e.g., `$config_dir`.  If you want the same file to be executed for multiple operations you should use symlinks.

    .loft_deploy/hooks/reset_post.sh

Then create a symlink:

    cd .loft_deploy/hooks/ && ln -s reset_post.sh pull_post.sh

The contents of the file could look like this, where $1 is a verbose comment about calling the hook, you should echo it if you care to have it displayed.

    #!/bin/bash
    # 
    # @file
    # Clears the drupal cache after the database has been reset

    # Verbose statement about this hook
    echo $1

    # Leverage the $relative location and then do a drush cc all
    echo "`tty -s && tput setaf 3`Clearing the drupal cache...`tty -s && tput op`"
    (cd "$(dirname $config_dir)/public_html" && drush cc all)

## MYSQL in your hooks

You can add mysql commands against the local environment in a hook using `loft_deploy_mysql` like this:

    #!/bin/bash
    # 
    # @file
    # Clears the drupal cache after the database has been reset

    # Verbose statement about this hook
    echo $1
    loft_deploy_mysql "DROP TABLE cache_admin_menu;"

## Hook Functions

* You may use [Cloudy](https://github.com/aklump/cloudy) functions in your hooks.
* See other Loft Deploy functions in _includes/function.sh_.

See also [sanitization using hooks](@sanitize).
 
## Hook Vars

* Be sure to use `echo_green`, `echo_yellow`, and `echo_red`.
* Always `return` 0, or a non-zero if the hook fails.
* Never `exit` in a hook file.
* Give feedback as to what happened, rather that what is about to happen, e.g. Files downloaded. instead of "Downloading files..." when echoing bullet points.
* See _install/base/hooks/example.sh_ for a code example.

| var | description |
|----------|----------|
| $ROOT | Path to the directory containing loft_deploy.sh |
| $INCLUDES | Path to the loft deploy includes directory |

| arg | definition | example |
|----------|----------|----------|
| $1 | operation  | push |
| $2 | production server | user@192.168.1.100  |
| $3 | staging server | user@192.168.1.100 |
| $4 | local basepath as defined in _config.yml_  |
| $5 | path to the copy stage directory |
| $6 | role of the server being handled | prod, staging |
| $7 | operation status | true or false |
| $8 | local role | dev, staging, prod |
| ${13} | path to hooks dir | /do/re/hooks  |

