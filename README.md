# Loft Deploy (for BASH)

## Summary

Deployment management for Drupal websites (and others with similar structures) that makes database and user file migration between production, development and staging extremly fast and simple.

The premise of this utililty assumes that you will manage the codebase of the project with source control such as Git.  Loft deploy adds the ability to pull the database and/or the user files (files not in your version control) from _production_ to _local_, and push or pull the database and user files between _local_ and _staging_. 

While it is not limited to Drupal, it does assume this type of tri-component scenario (codebase, database, user files). If you have neither a database nor user files, you would be wise not to use this tool as it adds complexity without utility.  With only a codebase to manage, simply use Git. 

Loft Deploy does not intend to replace codebase management with version control systems such as Git. Such systems should continue to be used in tandem with Loft Deploy.

## Key Concepts
### Fetch
Fetching grabs the remote assets and caches them locally, but does not alter your local environment.  You have to reset to do that.  Cached assets can be found in the _.loft_deploy_ folder.

### Reset
Uses the cached remote assets from the last fetch to alter your local environment.  Saves you download time if you are doing frequent resets to test update scripts or something, where you need to continusously reset to match the production database, for example.

### Pull
A combination that will do a fetch and reset in one command.


### Workflow

    [ PRODUCTION ]
           |
          \|/
           '
      [ LOCAL ] <--> [ STAGING ]

* Assets can flow FROM production to local.
* Assets cannot flow TO production.
* Assets can flow between local and staging.

## The database component

The production database is always considered the "origin"--that is to say it is the master of the database component of any group of production/local/staging servers.  When developing locally you should be making your database changes directly on the production database (or in an update script of a module) and then pulling using loft_deploy, but never will you push a local or staging database to production. Before local development you will need to refresh your local database and you do that with Loft Deploy `loft_deploy pull -d`.

After you have completed local development you may want to push to a staging server for client review.  You will use Loft Deploy `loft_deploy push -d` to push your local database to the staging server.

## The user files component

User files (i.e. _sites/default/files_), which are too dynamic to include in version control, also originate and must be changed on the production server. Just like the database, the dev and staging environments need to be brought to match production at times. Loft Deploy will do this using `loft_deploy pull -f`. You may still use Loft Deploy this when you do not have a user files directory, just omit any config variables referencing `files`.

### Excluding certain files using _files_exclude.txt_
You may set Loft Deploy to ignore certain user files by creating a file _.loft_deploy/files_exclude.txt_.  This will be used by the rsync program as an `--exclude-from` argument.

### Filenames with special chars
There appears to be a shortcoming with filenames that contain special chars.  The file sync may not work in this case.  Easiest fix is to insure filenames do not have special chars, like accents, etc.

## Fetch/reset/pull from staging
By default `fetch`, `reset` and `pull` will grab from _production_. In order to perform these functions using staging as the source you will need to **pass the `--staging` flag** like this:

    loft_deploy pull --staging
    loft_deploy fetch --staging
    loft_deploy reset --staging

The command `push` is always directed at the staging server.

## Warning!!!

**USE AT YOUR OWN RISK AS IMPROPER CONFIGURATION CAN RESULT IN DESTRUCTION OF DATABASE CONTENT AND FILES.**


## Requirements
The following assumptions are made about your project:

1. Your project's codebase is maintained using source control (git, svn, etc).
1. Your project uses a mysql database.
1. Your project might have a files directory that contains dynamic files, which are NOT in source control.

_If these assumptions are not true then this package may be less useful to you._


## (Recommended) Installation

1. Loft Deploy needs to be installed in each environment: _Production, Local_ and (if used) _Staging_.
1. Connect using a terminal program to the home directory of the server.  If the _bin_ folder does not exist, create it now.

        cd ~/bin

1. Clone Loft Deploy and create a symlink that is user executable.

        git clone https://github.com/aklump/loft_deploy.git loft_deploy_files;
        ln -s loft_deploy_files/loft_deploy.sh loft_deploy;
        chmod u+x loft_deploy;

1. Open up and modify _~/.bash_profile_ or _~/.profile_ (whichever you use).

        alias ldp="loft_deploy"
        export PATH=$PATH:~/bin

1. Reload your profile and test, you should see the Loft Deploy help screen if installation was successful.

        $ . ~/.bash_profile
        $ ldp

## Configuration (of projects)

* You must configure each environment for a given project. That is to say you must run `loft_deploy init dev` and `loft_deploy init prod` and maybe `loft_deploy init staging` on each of the appropriate servers.
* The init process creates an empty config file in .loft_deply/config; this file must be edited with all correct params for each environment.
* The location where you run the init process determines the scope of usage. The best/most common location is the directory above web root. You may run loft_deploy operations in any child directory and including the directory where it's initialized.
* An exception to this rule is a Drupal multisite, in which case you must descend into `sites/[sitename]` and install it there run `loft_deploy init` there. You will then be restricted to running loft deploy oeprations to `/sites/[sitename]` and any child directories.
* There is a .htaccess file provided which denies access to all traffic, make
  sure that does not get removed; especially if you're installing this in a publicly accessible folder, such as in the case above.
* For each website project that you want to use this for, you must create a configuration file for that website in all environments: local, production and staging if applicable.
* Carefully and meticulously edit `.loft_deploy/config` making CERTAIN you pay attention to the variable `local_role`. Setting this correctly ensures certain access checks, which may help to prevent damaging your production environment.
* AGAIN, MAKE SURE TO CORRECTLY SET `local_role` to: dev, prod or staging.
* Also make certain that your paths are correct, as incorrect paths may result in data loss to your production website.
* Review your config info with `loft_deploy configtest`.
* Verify especially that local > role is correct, as are all the paths.
* Correct any mistakes now, BEFORE ITS TOO LATE!
* Once the configuration files are in place and correct, REMOVE ALL WRITE PERMISSIONS to all copies of .loft_deploy/config files.
* Finally, test each environment before first use. You may run 'configtest' at any time in the future as well.

          $ loft_deploy configtest

## Message of the Day MOTD

MOTD will print a reminder each time a Loft Deploy action is executed; use it to keep track of reminders about your project.  Here's how:

Create a file in your project, `.loft_deploy/motd`, the contents of which is echoed when you run any loft_deploy command.  This is a way to store reminders per project.

## Hooks
You may create `.sh` files that will execute before or after an operation.  These are called hooks and should be created in `.loft_deploy/hooks`.  An example is a hook to be executed after a `reset` operation, you need only create a file at using the pattern `{op}_{post|pre}`.  The variables from loft_deploy.sh are available to your hook files, e.g., `$config_dir`.

    .loft_deploy/hooks/reset_post.sh

The contents of the file could look like this, where $1 is a verbose comment about calling the hook, you should echo it if you care to have it displayed.

    #!/bin/bash
    # 
    # @file
    # Clears the drupal cache after the database has been reset

    # Verbose statement about this hook
    echo $1

    # Leverage the $relative location and then do a drush cc all
    (cd "$(dirname $config_dir)/public_html" && drush cc all)

## SQL configuration
**GOTCHA!!!** It is crucial to realize that the configuration for these needs to be created on the same environmnet as the database.  Meaning, if you are wanting to exclude files from the production database, when pulling from a local dev environment, the files described below MUST be created on the production server config files.

### Exclude data from some tables: `sql/db_tables_no_data`
**Scenario**: You are working on a Drupal site and you do not want to export the contents of the `cache` or `cache_bootstrap` tables.  Here's how to configure Loft Deploy to do this:

1. Create a file as `.loft_deploy/sql/db_tables_no_data.txt`
1. In that file add the following (one table per line):
    
        cache
        cache_bootstrap

1. Now only the table structure and not the data will be exported.

#### But how about all `cache` tables?
Yes this is supported and is done like this:

1. Create a file as `.loft_deploy/sql/db_tables_no_data.sql`; notice the extension is now `.sql`.
1. In that file add the sql command to select all cache tables, e.g.,
    
        SELECT table_name FROM information_schema.tables WHERE table_schema = '$local_db_name' AND table_name LIKE 'cache%';

1. Notice the use of $local_db_name, which will be dynamically replaced with the configured values for the database table.
1. Now only the table structure for all cache tables and not the data will be exported.  And you will not have to update a text file listing out cache table names if your db structure grows.

Here are the dynamic component(s) available:

| variable         |
|------------------|
| `$local_db_name` |


##Usage:
After installed and configured type: `loft_deploy help` for available commands; you may also access the help by simply typing `loft_develop`

##Contact
* **In the Loft Studios**
* Aaron Klump - Developer
* PO Box 29294 Bellingham, WA 98228-1294
* _aim_: theloft101
* _skype_: intheloftstudios
* _d.o_: aklump
* <http://www.InTheLoftStudios.com>
