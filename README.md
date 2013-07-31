##Summary
A handy script to assist in the workflow across servers involved with websites such as Drupal that have three distince elements to manage: 

1. codebase
2. database
3. dynamic (or user-managed) files

While it is not limited to Drupal, it does assume this type of tri-component scenario. If you have neither a database nor user files, you would be wise not to use this tool as it adds complexity without utility.

In this scenario, the database lives and originates on the production server.
Changes to the database should only be made there. Yet those changes need to be
propogated to dev and staging environments; loft_deploy will do this.

User files, which are too dynamic to include in version management, also
originate and must be changed on the production server. Just like the database,
the dev and staging environments need to be brought to match production at
times. loft_deploy will do this.

loft_deploy is also used to push database and user files to a staging
environment for preview by the client or end user.

loft_deploy does not intend to replace codebase management with version control
systems such as git. Such systems should continue to be used in tandem with
loft_deploy.

Neither database, nor user files are ever pushed to production, whether from dev
or from staging.

##Warning!!!
**USE AT YOUR OWN RISK AS IMPROPER CONFIGURATION CAN RESULT IN DESTRUCTION OF DATABASE CONTENT AND FILES.**


##Requirements
The following assumptions are made about your project:

1. your project uses a database
2. your project's codebase is maintained using source control (git, svn, etc)
3. your project might have a files directory that contains dynamic
files, which are NOT in source control. If these assumptions are not true then this package may be less useful to you.


##Installation
* Create a symlink called loft_deploy to the loft_deploy.sh in a directory found
  in the $PATH so that you may execute this script
* Make sure that loft_deploy.sh is user executable, e.g. chmod u+x
  loft_deploy.sh

* How to install the package on each of your servers...

          cd ~;
          mkdir bin;
          cd bin;
          git clone git://github.com/aklump/loft_deploy.git loft_deploy_files;
          ln -s loft_deploy_files/loft_deploy.sh loft_deploy;
          chmod u+x loft_deploy_files/loft_deploy.sh;

* Open up and modify ~/.bash_profile

          alias ld="loft_deploy"
          export PATH=$PATH:~/bin

* Reload your profile and test, you should see the loft_deploy help screen

          $ . ~/.bash_profile
          $ ld

##Configuration
* You must configure each environment for a given project. That is to say you must run 'loft_deploy init dev' and 'loft_deploy init prod' and maybe `loft_deploy init staging` on each of the appropriate servers.
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


##Files:
* You may use this when you do not have a files directory, just omit any config variables referencing `files`.


##Usage:
* After installed and configured type: `loft_deploy help` for available
  commands; you may also access the help by simply typing `loft_develop`

##Contact
* **In the Loft Studios**
* Aaron Klump - Developer
* PO Box 29294 Bellingham, WA 98228-1294
* _aim_: theloft101
* _skype_: intheloftstudios
* _d.o_: aklump
* <http://www.InTheLoftStudios.com>
