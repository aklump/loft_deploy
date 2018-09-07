var tipuesearch = {"pages":[{"title":"0.14.13","text":"   Changes in config.yml are now detected and caches are cleared automatically.   0.14.10   Removed scp operation; you should now use the copy_production_to feature instead.   0.14   Change to YAML configuration files (see update.html for how to)  ","tags":"","url":"CHANGELOG.html"},{"title":"(Recommended) Installation","text":"   Loft Deploy needs to be installed in each environment: Production, Local and (if used) Staging. Connect using a terminal program to the home directory of the server.  If the bin folder does not exist, create it now.  cd \/opt  Clone Loft Deploy and create a symlink that is user executable.  git clone https:\/\/github.com\/aklump\/loft_deploy.git loft_deploy; cd \/usr\/local\/bin ln -s \/opt\/loft_deploy\/loft_deploy.sh loft_deploy; chmod u+x loft_deploy;  Install dependencies using Composer.  cd \/usr\/local\/bin\/loft_deploy composer install  Open up and modify ~\/.bash_profile or ~\/.profile (whichever you use).  alias ldp=\"loft_deploy\" export PATH=$PATH:~\/bin  Reload your profile and test, you should see the Loft Deploy help screen if installation was successful.  $ . ~\/.bash_profile $ ldp    Documentation  After downloading, open docs\/index.html for documentation.  Contact   In the Loft Studios Aaron Klump - Developer PO Box 29294 Bellingham, WA 98228-1294 aim: theloft101 skype: intheloftstudios d.o: aklump http:\/\/www.InTheLoftStudios.com  ","tags":"","url":"README.html"},{"title":"Configuration Examples","text":"   See includes\/schema--config.json for more info. NOTE: If you change DB credentials in the settings file, you will need to call ldp clearcache manually.   Example A   Local site using Drupal settings.php for database connection. Production and staging connection via SSH  local:   location: ITLS   url: website.local   basepath: \/Users\/aklump\/Code\/Projects\/Client\/Website\/site\/dist\/   role: dev   files:   - private\/default\/files   - web\/sites\/default\/files   database:     backups: private\/default\/db\/purgeable   drupal:     root: web     settings: web\/sites\/default\/settings.php     database: default production:   config: \/var\/www\/website\/.loft_deploy   script: \/usr\/local\/bin\/loft_deploy   user: USERNAME   ip: NN.NN.NNN.NNN staging:   config: \/var\/www\/stage.website\/.loft_deploy   script: \/usr\/local\/bin\/loft_deploy   user: USERNAME   ip: NN.NN.NNN.NNN         local property   description       location   The business name of the physical location     url   The URL of the local website without protocol     basepath   The local path to the project, this is prepended to all other paths in local, which do not begin with a forward slash     role   one of: dev, staging, production     files   up to three relative or absolute local file paths, which will be used in the files operations     database   See below     drupal   See below     Example B   Local site using explicit mysql credentials. No production nor staging servers.  local:   location: ITLS   url: website.local   basepath: \/Users\/aklump\/Code\/Projects\/Client\/Website\/site\/dist\/   role: dev   files:   - private\/default\/files   - web\/sites\/default\/files   database:     backups: private\/default\/db\/purgeable     host: localhost     user: DB_USER     password: \"PASSWORD-GOES-HERE\"     name: DB_NAME    Indicating Specific Binaries  You can define the binaries (except PHP) to use; more info in includes\/schema--config.json.      bin:       mysql: \/Applications\/MAMP\/Library\/bin\/mysql       gzip: \/usr\/bin\/gzip   To indicate PHP version  If you need to specify a php version you must add the following to .bash_profile or .bashrc.  You cannot add PHP to the YAML configuration.  export LOFT_DEPLOY_PHP=\"\/Applications\/MAMP\/bin\/php\/php7.1.12\/bin\/php\"  ","tags":"","url":"configuration.html"},{"title":"Hooks","text":"  Quick Start  The hook filename is comprised of: OPERATION_{ASSET_}POSITION, e.g.  .loft_deploy\/hooks\/ \u251c\u2500\u2500 fetch_db_post.sh \u251c\u2500\u2500 fetch_db_pre.sh \u251c\u2500\u2500 fetch_files_post.sh \u251c\u2500\u2500 fetch_files_pre.sh \u251c\u2500\u2500 fetch_post.sh \u251c\u2500\u2500 fetch_pre.sh \u251c\u2500\u2500 pull_db_post.sh \u251c\u2500\u2500 pull_db_pre.sh \u251c\u2500\u2500 pull_files_post.sh \u251c\u2500\u2500 pull_files_pre.sh \u251c\u2500\u2500 pull_post.sh \u251c\u2500\u2500 pull_pre.sh \u251c\u2500\u2500 reset_db_post.sh \u251c\u2500\u2500 reset_db_pre.sh \u251c\u2500\u2500 reset_files_post.sh \u251c\u2500\u2500 reset_files_pre.sh \u251c\u2500\u2500 reset_post.sh \u2514\u2500\u2500 reset_pre.sh   Description  You may create .sh files that will execute before or after an operation.  These are called hooks and should be created in .loft_deploy\/hooks.  An example is a hook to be executed after a reset operation, you need only create a file at using the pattern OPERATION_{ASSET_}POSITION.  The variables from loft_deploy.sh are available to your hook files, e.g., $config_dir.  If you want the same file to be executed for multiple operations you should use symlinks.  .loft_deploy\/hooks\/reset_post.sh   Then create a symlink:  cd .loft_deploy\/hooks\/ &amp;&amp; ln -s reset_post.sh pull_post.sh   The contents of the file could look like this, where $1 is a verbose comment about calling the hook, you should echo it if you care to have it displayed.  #!\/bin\/bash #  # @file # Clears the drupal cache after the database has been reset  # Verbose statement about this hook echo $1  # Leverage the $relative location and then do a drush cc all echo \"`tty -s &amp;&amp; tput setaf 3`Clearing the drupal cache...`tty -s &amp;&amp; tput op`\" (cd \"$(dirname $config_dir)\/public_html\" &amp;&amp; drush cc all)   MYSQL in your hooks  You can add mysql commands against the local environment in a hook using loft_deploy_mysql like this:  #!\/bin\/bash #  # @file # Clears the drupal cache after the database has been reset  # Verbose statement about this hook echo $1 loft_deploy_mysql \"DROP TABLE cache_admin_menu;\"   Hook vars   Be sure to use echo_green, echo_yello, and echo_red. Always return 0, or a non-zero if the hook fails. Never exit in a hook file. Give feedback as to what happened, rather that what is about to happen, e.g. Files downloaded. instead of \"Downloading files...\" when echoing bullet points. See install\/base\/hooks\/example.sh for a code example.        var   description       $ROOT   Path to the directory containing loft_deploy.sh     $INCLUDES   Path to the loft deploy includes directory          arg   definition   example       $1   operation   push     $2   production server   user@192.168.1.100     $3   staging server   user@192.168.1.100     $4   local basepath as defined in config.yml        $5   path to the copy stage directory        $6   source server   prod, staging     $7   operation status   true or false     ${13}   path to hooks dir   \/do\/re\/hooks    ","tags":"","url":"hooks.html"},{"title":"Message of the Day MOTD","text":"  MOTD will print a reminder each time a Loft Deploy action is executed; use it to keep track of reminders about your project.  Here's how:  Create a file in your project, .loft_deploy\/motd, the contents of which is echoed when you run any loft_deploy command.  This is a way to store reminders per project. ","tags":"","url":"motd.html"},{"title":"MYSQL","text":"  Local  Local mysql can be entered using ldp mysql.  Remote  If your production server allows remote connections you can use ldp mysql --prod but that requires some extra configuration.  The following needs to be added to your dev config file:  production_remote_db_host=''   Pantheon  If terminus is installed and your server is on Pantheon you only need to make sure this is present:  pantheon_live_uuid=''  ","tags":"","url":"mysql.html"},{"title":"Overview","text":"  Summary  Deployment management for Drupal websites (and others with similar structures) that makes database and user file migration between production, development and staging extremly fast and simple.  The premise of this utililty assumes that you will manage the codebase of the project with source control such as Git.  Loft deploy adds the ability to pull the database and\/or the user files (files not in your version control) from production to local, and push or pull the database and user files between local and staging.  While it is not limited to Drupal, it does assume this type of tri-component scenario (codebase, database, user files). If you have neither a database nor user files, you would be wise not to use this tool as it adds complexity without utility.  With only a codebase to manage, simply use Git.  Loft Deploy does not intend to replace codebase management with version control systems such as Git. Such systems should continue to be used in tandem with Loft Deploy.  Key Concepts  Fetch  Fetching grabs the remote assets and caches them locally, but does not alter your local environment.  You have to reset to do that.  Cached assets can be found in the .loft_deploy folder.  Reset  Uses the cached remote assets from the last fetch to alter your local environment.  Saves you download time if you are doing frequent resets to test update scripts or something, where you need to continusously reset to match the production database, for example.  Pull  A combination that will do a fetch and reset in one command.  Workflow  [ PRODUCTION ]        |       \\|\/        '   [ LOCAL ] &lt;--&gt; [ STAGING ]    Assets can flow FROM production to local. Assets cannot flow TO production. Assets can flow between local and staging.   The database component  The production database is always considered the \"origin\"--that is to say it is the master of the database component of any group of production\/local\/staging servers.  When developing locally you should be making your database changes directly on the production database (or in an update script of a module) and then pulling using loft_deploy, but never will you push a local or staging database to production. Before local development you will need to refresh your local database and you do that with Loft Deploy loft_deploy pull -d.  After you have completed local development you may want to push to a staging server for client review.  You will use Loft Deploy loft_deploy push -d to push your local database to the staging server.  The user files component  User files (i.e. sites\/default\/files), which are too dynamic to include in version control, also originate and must be changed on the production server. Just like the database, the dev and staging environments need to be brought to match production at times. Loft Deploy will do this using loft_deploy pull -f. You may still use Loft Deploy this when you do not have a user files directory, just omit any config variables referencing files.  For more information see user files.  Fetch\/reset\/pull from staging  By default fetch, reset and pull will grab from production. In order to perform these functions using staging as the source you will need to pass the --staging flag like this:  loft_deploy pull --staging loft_deploy fetch --staging loft_deploy reset --staging   The command push is always directed at the staging server.  Warning!!!  USE AT YOUR OWN RISK AS IMPROPER CONFIGURATION CAN RESULT IN DESTRUCTION OF DATABASE CONTENT AND FILES.  Requirements  The following assumptions are made about your project:   Your project's codebase is maintained using source control (git, svn, etc). Your project uses a mysql database. Your project might have a files directory that contains dynamic files, which are NOT in source control.   If these assumptions are not true then this package may be less useful to you.  Configuration (of projects)   You must configure each environment for a given project. That is to say you must run loft_deploy init dev and loft_deploy init prod and maybe loft_deploy init staging on each of the appropriate servers. The init process creates an empty config file .loft_deply\/config.yml; this file must be edited with all correct params for each environment. The location where you run the init process determines the scope of usage. The best\/most common location is the directory above web root. You may run loft_deploy operations in any child directory and including the directory where it's initialized. An exception to this rule is a Drupal multisite, in which case you must descend into sites\/[sitename] and install it there run loft_deploy init there. You will then be restricted to running loft deploy oeprations to \/sites\/[sitename] and any child directories. There is a .htaccess file provided which denies access to all traffic, make sure that does not get removed; especially if you're installing this in a publicly accessible folder, such as in the case above. For each website project that you want to use this for, you must create a configuration file for that website in all environments: local, production and staging if applicable. Carefully and meticulously edit .loft_deploy\/config making CERTAIN you pay attention to the variable local_role. Setting this correctly ensures certain access checks, which may help to prevent damaging your production environment. AGAIN, MAKE SURE TO CORRECTLY SET local_role to: dev, prod or staging. Also make certain that your paths are correct, as incorrect paths may result in data loss to your production website. Review your config info with loft_deploy configtest. Verify especially that local > role is correct, as are all the paths. Correct any mistakes now, BEFORE ITS TOO LATE! Once the configuration files are in place and correct, REMOVE ALL WRITE PERMISSIONS to all copies of .loft_deploy\/config files. Finally, test each environment before first use. You may run 'configtest' at any time in the future as well.    $ loft_deploy configtest    SQL configuration  GOTCHA!!! It is crucial to realize that the configuration for these needs to be created on the same environmnet as the database.  Meaning, if you are wanting to exclude files from the production database, when pulling from a local dev environment, the files described below MUST be created on the production server config files.  Exclude data from some tables: sql\/db_tables_no_data  Scenario: You are working on a Drupal site and you do not want to export the contents of the cache or cache_bootstrap tables.  Here's how to configure Loft Deploy to do this:   Create a file as .loft_deploy\/sql\/db_tables_no_data.txt In that file add the following (one table per line):  cache cache_bootstrap  Now only the table structure and not the data will be exported.   But how about all cache tables?  Yes this is supported and is done like this:   Create a file as .loft_deploy\/sql\/db_tables_no_data.sql; notice the extension is now .sql. In that file add the sql command to select all cache tables, e.g.,  SELECT table_name FROM information_schema.tables WHERE table_schema = '$local_db_name' AND table_name LIKE 'cache%';  Notice the use of $local_db_name, which will be dynamically replaced with the configured values for the database table. Now only the table structure for all cache tables and not the data will be exported.  And you will not have to update a text file listing out cache table names if your db structure grows.   Here are the dynamic component(s) available:       variable       $local_db_name     Usage:  After installed and configured type: loft_deploy help for available commands; you may also access the help by simply typing loft_develop ","tags":"","url":"overview.html"},{"title":"Support for Pantheon Websites","text":"  This guide will show you how to connect to Pantheon websites.  Be aware that you do not install Loft Deploy on the remote server; you will use Pantheon's Terminus instead.  Install Terminus   Once your local .loft_deploy exists you may install Terminus. Descend into that directory, e.g. cd .loft_deploy Install using composer composer require pantheon-systems\/terminus   Configure Terminus  You must have something like the following in config.yml on your local dev machine for the production section:  production:   files:   - code\/sites\/default\/files   - code\/sites\/default\/files\/private   pantheon:     uuid: UUID-GOES-HERE     site: SITE_NAME     machine_token: 'MACHINE_TOKEN_HERE'   Configure exclude files  Pantheon includes the private files directory inside of the public files directory.  You will want to exclude the private directory by adding the following lines to files_exclude.txt:      private   Then you should setup the second array element as files\/private as shown above and then that will transfer your private directory, if you so desire.  Configuration Hints   To obtain or get more info about machine tokens. You can determine the site name by using ldp terminus site:list after first authenticating.   Test installation   Then run configtest to see if Terminus is installed correctly. You may want to clearcache as a first step in debugging.   Usage   Authenticate using the Loft Deploy credentials with the following:  ldp terminus site:list  You will then see the absolute path to the terminus binary to use for further commands.     Files  @todo This must be updated with the new YAML format:   (Terminus is not necessary for files support at this time.) Connection info is found in the dashboard. The following must appear in your dev config file:  production_server='$ENV.$SITE@appserver.$ENV.$SITE.drush.in' production_port=2222 production_files='files' pantheon_live_uuid=''    More reading: https:\/\/pantheon.io\/docs\/rsync-and-sftp\/ ","tags":"","url":"pantheon.html"},{"title":"Search Results","text":" ","tags":"","url":"search--results.html"},{"title":"Update","text":"  Manual Update to 0.14  This update converts the old config style into YAML:   Copy one of install\/config\/*.yml files to .loft_deploy\/config.yml; based on the role of the local. Hand copy\/paste config values from .loft_deploy\/config into .loft_deploy\/config.yml. Delete .loft_deploy\/config. Run ldp clearcache. Run ldp configtest and adjust as necessary.  ","tags":"","url":"update.html"},{"title":"User (non-versioned) files component","text":"  Loft Deploy supports up to three directories of non-versioned files as part of the files fetch\/pull operation.  This is ample to cover Drupal's concept of public and private directories, with one more directory to spare.  Be sure that the prod and staging directories map to the correct files path to local, e.g. prod:local_files2 maps to local:local_files2 and so on.  Configuration       config var   rsync exclusion file       local_files   files_exclude.txt     local_files2   files2_exclude.txt     local_files3   files3_exclude.txt     Excluding certain files using files_exclude.txt  You may set Loft Deploy to ignore certain user files by creating a file .loft_deploy\/files_exclude.txt.  This will be used by the rsync program as an --exclude-from argument.  Notice that you will need to use files2_exclude.txt and files3_exclude.txt to target files in those other directories, if necessary.  Some highlights from the rsync documentation:   Blank lines in the file and lines starting with ';' or '#' are ignored. If the pattern ends with a \/ then it will only match a directory, not a file, link, or device. A '*' matches any non-empty path component (it stops at slashes). Use '**' to match anything, including slashes. A '?' matches any character except a slash (\/). A '[' introduces a character class, such as [a-z] or [[:alpha:]].   Filenames with special chars  There appears to be a shortcoming with filenames that contain special chars.  The file sync may not work in this case.  Easiest fix is to insure filenames do not have special chars, like accents, etc. ","tags":"","url":"user_files.html"}]};