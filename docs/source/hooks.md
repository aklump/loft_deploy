# Hooks

You may create `.sh` files that will execute before or after an operation.  These are called hooks and should be created in `.loft_deploy/hooks`.  An example is a hook to be executed after a `reset` operation, you need only create a file at using the pattern `{op}_{post|pre}`.  The variables from loft_deploy.sh are available to your hook files, e.g., `$config_dir`.  If you want the same file to be executed for multiple operations you should use symlinks.

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

## Hook vars

| arg | definition | example |
|----------|----------|----------|
| $1 | operation  | push |
| $2 | production server |   |
| $3 | staging server |   |
| ${13} | path to hooks dir | /do/re/hooks  |
