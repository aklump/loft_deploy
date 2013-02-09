SUMMARY:
A handy script to assist in deployment of websites using either of these
scenarios:

  LOCAL DEV -> PRODUCTION
  LOCAL DEV -> STAGING -> PRODUCTION

It was written to be agnositic of codebase and be super flexible to work with
anything from Drupal to custom sites.

USE AT YOUR OWN RISK AS IMPROPER CONFIGURATION CAN RESULT IN DESTRUCTION OF
DATABASE CONTENT AND FILES.


REQUIREMENTS:
The following assumptions are made about your project: 1) your project uses a
database 2) your project's codebase is maintained using source control (git,
svn, etc) 3) your project has a files directory that contains dynamic files,
which are NOT in source control. If these assumptions are not true then this
package may be less useful to you.


INSTALLATION:
* Create a symlink called loft_deploy to the loft_deploy.sh in a directory found
  in the $PATH so that you may execute this script
* Make sure that loft_deploy.sh is user executable, e.g. chmod u+x
  loft_deploy.sh
* Optional, create an alias, e.g. 'alias ld=loft_deploy' in ~/.profile or
  ~/.bash_profile


CONFIGURATION:
* For each website project that you want to use this for, you must create a
  configuration file for that website in all environments: local, production and
  staging if applicable.
* Copy one of the provided files found in example_configs/ as .loft_deploy above
  the web root for each environment. Notice the new name begins with a .
* Carefully and meticulously configure these files making CERTAIN you pay
  attention to the variable local_role. Setting this correctly ensures certain
  access checks, which may help to prevent damaging your production environment.
* AGAIN, MAKE SURE TO CORRECTLY SET local_role
* Also make certain that your paths are correct as incorrect paths may result in
  data loss to your production website.
* Navigate inside the webroot of each environment and test the configuration
  with the command: loft_deploy config.
* Verify that local > role is correct, as are all the paths.
* Correct any mistakes now, before its too late!
* Once the configuration files are in place and correct, REMOVE ALL WRITE
  PERMISSIONS to all copies of .loft_deploy configuration files.


USAGE:
* After installed and configured type: 'loft_deploy help' for available
  commands; you may also access the help by simply typing 'loft_develop'



--------------------------------------------------------
CONTACT:
In the Loft Studios
Aaron Klump - Web Developer
PO Box 29294 Bellingham, WA 98228-1294
aim: theloft101
skype: intheloftstudios

http://www.InTheLoftStudios.com
