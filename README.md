# Loft Deploy (for BASH)

## Summary

Deployment management for Drupal websites (and others with similar structures)
that makes database and user file migration between production, development and
staging extremly fast and simple.

The premise of this utililty assumes that you will manage the codebase of the
project with source control such as Git.  Loft deploy adds the ability to
fetch/pull the database and/or the user files from _production_ to _local_ and
push the database and user files from _local_ to _staging_.

While it is not limited to Drupal, it does assume this type of tri-component
scenario. If you have neither a database nor user files, you would be wise not
to use this tool as it adds complexity without utility.  With only a codebase to
manage, simply use Git.

Loft Deploy does not intend to replace codebase management with version control
systems such as Git. Such systems should continue to be used in tandem with
Loft Deploy.


## The database component

    [ PRODUCTION DB ] ---> [ LOCAL DB ] --> [ STAGING DB ]

The production database is always considered the "origin"--that is to say it is
the master of the database component of any group of production/local/staging
servers.  When developing locally you should be making your database changes
directly on the production database and then pulling (or in an update script of
a module), but never will you push a local or staging database to production.
Before local development you will need to refresh your local database and you do
that with Loft Deploy `ld pull -d`.

After you have completed local development you may want to push to a staging
server for client review.  You will use Loft Deploy `ld push -d` to push your
local database to the staging server.

## The user files component

User files (i.e. _sites/default/files_), which are too dynamic to include in
version control, also originate and must be changed on the production server.
Just like the database, the dev and staging environments need to be brought to
match production at times. Loft Deploy will do this using `ld pull -f`.

You may still use Loft Deploy this when you do not have a user files directory,
just omit any config variables referencing `files`.


## Warning!!!

**USE AT YOUR OWN RISK AS IMPROPER CONFIGURATION CAN RESULT IN
DESTRUCTION OF DATABASE CONTENT AND FILES.**


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

        git clone git@github.com:aklump/loft_deploy.git loft_deploy_files;
        ln -s loft_deploy_files/loft_deploy.sh loft_deploy;
        chmod u+x loft_deploy;

1. Open up and modify _~/.bash_profile_ or _~/.profile_ (whichever you use).

        alias ld="loft_deploy"
        export PATH=$PATH:~/bin

1. Reload your profile and test, you should see the Loft Deploy help screen if installation was successful.

        $ . ~/.bash_profile
        $ ld

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

##Message of the Day MOTD

MOTD will print a reminder each time a Loft Deploy action is executed; use it to
keep track of reminders about your project.  Here's how:

Create a file in your project, `.loft_deploy/motd`, the contents of which is
echoed when you run any loft_deploy command.  This is a way to store reminders
per project.

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
