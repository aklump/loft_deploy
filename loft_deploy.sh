#!/bin/bash
#
# @file
# Loft Deploy a system to aid in website deployment
#
# CONFIGURATION
#   1. You must create the file .loft_deploy in a parent directory above web
#   root in the project you want to use this script for. Until the configuration
#   file is created this script will not do anything.
#
# USAGE:
#  1.
#
# CREDITS:
# In the Loft Studios
# Aaron Klump - Web Developer
# PO Box 29294 Bellingham, WA 98228-1294
# aim: theloft101
# skype: intheloftstudios
#
#
# LICENSE:
# Copyright (c) 2013, In the Loft Studios, LLC. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
#   1. Redistributions of source code must retain the above copyright notice,
#   this list of conditions and the following disclaimer.
#
#   2. Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
#
#   3. Neither the name of In the Loft Studios, LLC, nor the names of its
#   contributors may be used to endorse or promote products derived from this
#   software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY IN THE LOFT STUDIOS, LLC "AS IS" AND ANY EXPRESS
# OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
# OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
# EVENT SHALL IN THE LOFT STUDIOS, LLC OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
# INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
# BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
# OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
# EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
# The views and conclusions contained in the software and documentation are
# those of the authors and should not be interpreted as representing official
# policies, either expressed or implied, of In the Loft Studios, LLC.
#
#
# @defgroup loft_deploy Loft Deploy
# @{
#

# The user's operation
op=$1

# Holds the starting directory
start_dir=${PWD}

# holds the full path to the last db dump
current_db_dir=''

# holds the filename of the last db dump
current_db_filename=''

# holds the directory of the config file
config_dir=${PWD}/.loft_deploy

# holds the result of connect()
mysql_check_result=false

# holds a timestamp for backups, etc.
now=$(date +"%Y%m%d_%H%M")


##
 # Initialize a new project
 #
 # @param string $1
 #   One of dev, staging or production
 #
 # @return NULL
 #
function init() {
  if [ -d .loft_deploy ]
  then
    end "$start_dir is already initialized."
  fi
  if [ $# -ne 1 ]
  then
    end "Please specific one of: dev, staging or prod.  e.g. loft_deploy init dev"
  elif [ "$1" == 'dev' ] || [ "$1" == 'staging' ] || [ "$1" == 'prod' ]
  then
    loft_deploy_source=$(which loft_deploy)_files
    mkdir .loft_deploy
    cd .loft_deploy
    echo 'deny from all' > .htaccess
    chmod 0644 .htaccess
    cp $loft_deploy_source/example_configs/example_$1 ./config
    mkdir db
    touch cached_db
    mkdir files
    touch cached_files
    cd $start_dir
    complete
    end "Please configure and save $config_dir/config"
  else
    end "Invalid argument"
  fi
}

##
 # Load the configuration file
 #
function load_config() {
  dir=.loft_deploy
  if [ ! -d "$dir" ]
  then
    _upsearch $dir
  fi

  # these are defaults
  local_role="prod"
  local_db_host='localhost'
  production_script='~/bin/loft_deploy'
  production_pass=''
  production_root=''
  staging_pass=''
  source $dir/config
  cd $start_dir
}

##
 # Recursive search for file in parent dirs
 #
function _upsearch () {
  test / == "$PWD" && echo && echo "`tput setaf 1`NO CONFIG FILE FOUND!`tput op`" && end "Please create .loft_deploy or make sure you are in a child directory." || test -e "$1" && config_dir=${PWD}/.loft_deploy && return || cd .. && _upsearch "$1"
}

##
 # Fetch production files to local
 #
function fetch_files() {
  if [ ! "$production_files" ] || [ ! "$local_files" ] || [ "$production_files" == "$local_files" ]
  then
    end "Bad config"
  fi
  echo "Copying files from production server..."
  rsync -av $production_server://$production_files/ $config_dir/files/ --delete

  # record the fetch date
  echo $now > $config_dir/cached_files
}

##
 # Reset the local files with fetched production files
 #
 # @param string $1
 #   description of param
 #
 # @return NULL
 #   Sets the value of global $reset_files_return
 #
function reset_files() {
  echo "This process will reset your local files to match the most recently fetched"
  echo "production files, removing any local files that are not present in the fetched"
  echo "set. You will be given a preview of what will happen first. To absolutely"
  echo "match production, consider running fetch_files first, however it is slower."
  echo
  echo "End result: Your local files directory will match fetched production files."

  source=$config_dir/files
  if [ ! -d $source ]
  then
    end "Please fetch_files first"
  fi
  confirm "Are you sure you want to `tput setaf 3`OVERWRITE LOCAL FILES`tput op`"
  echo 'Previewing...'
  rsync -av $source/ $local_files/ --delete --dry-run
  confirm 'That was a preview... do it for real?'
  rsync -av $source/ $local_files/ --delete
}


##
 # Fetch the remote db and import it to local
 #
function fetch_db() {
  if [ ! "$production_script" ] || [ ! "$production_db_dir" ] || [ ! "$production_server" ] || [ ! "$production_db_name" ]
  then
    end "Bad db config"
  fi

  echo "Exporting production db..."
  prod_suffix='fetch_db'
  ssh $production_server "cd $production_root && . $production_script dump_db $prod_suffix"
  wait

  echo "Downloading from production..."
  remote_file="$production_db_dir/${production_db_name}-$prod_suffix.sql"
  local_file=$config_dir/db/fetched.sql
  scp $production_server://$remote_file $local_file

  # record the fetch date
  echo $now > $config_dir/cached_db

  # delete it from remote
  echo "Deleting the production copy..."
  ssh $production_server "rm $remote_file"
}

##
 # Reset the local database with a previously fetched copy
 #
 # @return NULL
 #   Sets the value of global $reset_db_return
 #
function reset_db() {
  echo "This process will reset your local db to match the most recently fetched"
  echo "production db, first backing up your local db. To absolutely match production,"
  echo "consider running fetch_db first, however it is slower.."
  echo
  echo "End result: Your local files directory will match the fetched prod db."

  confirm "Are you sure you want to `tput setaf 3`OVERWRITE YOUR LOCAL DB`tput op` with the production db"

  file=$config_dir/db/fetched.sql
  if [ ! -f $file ]
  then
    end "Please fetch_db first"
  fi

  #backup local
  dump_db reset_backup_$now

  echo "Importing $local_file"
  import_db $file
}


##
 # Push local files to staging
 #
function push_files() {
  if [ ! "$staging_files" ]
  then
    end "`tput setaf 1`You cannot push your files unless you define a staging environment.`tput op`"
  fi
  if [ ! "$local_files" ] || [ "$staging_files" == "$local_files" ]
  then
    end "`tput setaf 1`BAD CONFIG`tput op`"
  fi

  echo "This process will push your local files to your staging server, removing any"
  echo "files on staging that are not present on local. You will be given"
  echo "a preview of what will happen first."
  echo
  echo "End result: Your staging files directory will match your local."
  confirm 'Are you sure you want to push local files OVERWRITING STAGING files'
  echo 'Previewing...'
  rsync -av $local_files/ $staging_server://$staging_files/ --delete --dry-run
  confirm 'That was a preview... do it for real?'
  rsync -av $local_files/ $staging_server://$staging_files/ --delete

  complete "Push files complete; please test your staging site."
}

##
 # Push local db (with optional dump) to staging
 #
function push_db() {
  if [ ! "$staging_db_dir" ] || [ ! "$staging_server" ]
  then
    end "You cannot push your database unless you define a staging environment."
  fi
  confirm "Are you sure you want to push your local db to staging"

  # @todo make this push it and import into staging
  suffix='push_db'
  dump_db $suffix
  echo 'Pushing db to staging...'
  scp $current_db_dir$current_db_filename $staging_server://$staging_db_dir/$current_db_filename

  complete "Push db complete; please test your staging site."
}

##
 # Generate the current db filepath with optional suffix
 #
 # @param string $1
 #   Anything to add as a suffix
 #
function _current_db_paths() {
  current_db_dir=''
  if [ "$local_db_dir" ]
  then
    current_db_dir=$local_db_dir/
  fi
  suffix=''
  if [ "$1" ]
  then
    suffix="-$1"
  fi
  current_db_filename=$local_db_name$suffix.sql
}

##
 # Dump the database with optional file suffix
 #
 # @param string $1
 #   Anything to add as a suffix
 #
function dump_db() {
  _current_db_paths $1

  if [ -f "$current_db_dir$current_db_filename" ]
  then
    confirm_result=false
    confirm "File $current_db_dir$current_db_filename exists, replace" noend
    if [ $confirm_result == false ]
    then
      return
    fi
    rm $current_db_dir$current_db_filename
  fi
  if [ ! "$local_db_user" ] || [ ! "$local_db_pass" ] || [ ! "$local_db_name" ]
  then
    end "Bad config"
  fi
  if [ ! "$local_db_host" ]
  then
    local_db_host="localhost"
  fi

  echo "Exporting database as $current_db_dir$current_db_filename..."
  mysqldump -u $local_db_user -p$local_db_pass -h $local_db_host $local_db_name -r $current_db_dir$current_db_filename
}

##
 # Import a db dump file into local db, overwriting local
 #
 # @param string $1
 #   If this is not a path to a file, it will be assumed a filename in
 #   $local_db_dir
 #
function import_db() {
  _current_db_paths $1
  if file=$1 && [ ! -f $1 ] && file=$current_db_dir$current_db_filename && [ ! -f $file ]
  then
    end "$file not found."
  fi
  confirm "You are about to `tput setaf 3`OVERWRITE YOUR LOCAL DATABASE`tput op`, are you sure"
  echo "It's advisable to empty the database first."
  _drop_tables
  echo "Importing $current_db_dir$1 to $local_db_host $local_db_name database..."
  mysql -u $local_db_user -p$local_db_pass -h $local_db_host $local_db_name < $file
}

##
 # Drop all local db tables
 #
function _drop_tables() {
  confirm_result=false;
  confirm "Should we `tput setaf 3`DUMP ALL TABLES (empty database)`tput op` from $local_db_host $local_db_name, first" noend
  if [ $confirm_result == false ]
  then
    return
  fi
  tables=$(mysql -u $local_db_user -p$local_db_pass -h $local_db_host $local_db_name -e 'show tables' | awk '{ print $1}' | grep -v '^Tables' )
  echo "Dropping all tables from the $local_db_name database..."
  for t	in $tables
  do
    echo $t
    mysql -u $local_db_user -p$local_db_pass -h $local_db_host $local_db_name -e "drop table $t"
  done
  echo
}

###
 # Complete an operation and optional exit
 #
 # @param string $1
 #   The message to delive
 #
 ##
function complete() {
  if [ $# -ne 0 ]
  then
    echo $1
  fi
  echo '----------------------------------------------------------'
}

##
 # Accept a y/n confirmation message or end
 #
 # @param string $1
 #   A question to ask
 # @param string $2
 #   A flag, e.g. noend; which means a n will not exit
 #
 # @return bool
 #   Sets the value of confirm_result
 #
function confirm() {
  echo
  echo "$1 (y/n)?"
  read -n 1 a
  confirm_result=true
  if [ "$a" != 'y' ]
  then
    confirm_result=false
    if [ "$2" != 'noend' ]
    then
      end 'CANCELLED!'
    fi
  fi
  echo
}

##
 # Theme a help topic output
 #
 # @param string $1
 #   Access check arg
 # @param string $2
#    The destination; expecting local or remote
 # @param string $3
 #   The help description
 #
 # @return NULL
 #
function theme_help_topic() {
  indent='    ';
  access=false
  _access_check $1
  if [ "$access" == true ]
  then
    left="<<<"
    right=">>>"
    case $2 in
        'l')
          color=3
          icon="`tput setaf 4`local`tput op`"
          icon='';;

        'pl')
          color=6
          icon="`tput setaf 6`local $left`tput op` prod";;
        'pld')
          color=6
          icon="`tput setaf 6`local db $left`tput op` prod db";;
        'plf')
          color=6
          icon="`tput setaf 6`local files $left`tput op` prod files";;

        #'lp')
        #  color=3
        #  icon="`tput setaf 3`local $right`tput op` prod";;
        #'lpd')
        #  icon="`tput setaf 3`local db $right`tput op` prod db";;
        #'lpf')
        #  icon="`tput setaf 3`local files $right`tput op` prod files";;

        'sl')
          icon="`tput setaf 3`local $left`tput op` staging";;
        'sld')
          icon="`tput setaf 3`local db$left `tput op` staging db";;
        'slf')
          icon="`tput setaf 3`local files$left `tput op` staging files";;

        'lst')
          color=2
          icon="local `tput setaf 2`$right staging`tput op`";;
        'lsd')
          color=2
          icon="local db `tput setaf 2`$right staging db`tput op`";;
        'lsf')
          color=2
          icon="local files `tput setaf 2`$right staging files`tput op`";;
    esac

    echo "`tput setaf $color`$1`tput op`"
    i=0
    for line in "$@"
    do
      if [ $i -gt 1 ]
      then
        echo "$indent$line"
        #if [ "$icon" ]
        #then
        #  echo "$indent[ $icon ]"
        #fi
      fi
      i+=1
    done
  fi
}

##
 # Theme a header
 #
 # @param string $1
 #   Header text
 # @param int $2
 #   Color
 #
 # @return NULL
 #   Sets the value of global $theme_header_return
 #
function theme_header() {

  if [ $# -eq 1 ]
  then
    color=7
  else
    color=$2
  fi
  echo
  echo "`tput setaf $color`~~$1~~`tput op`"
}


##
 # Display help for this script
 #
function show_help() {
  clear

  title=$(echo "Commands for a $local_role Environment" | tr "[:lower:]" "[:upper:]")
  theme_header "$title"

  theme_header 'from prod' 6
  theme_help_topic fetch 'pl' 'A fetch all shortcut'
  theme_help_topic fetch_db 'pld' 'Pull production db but do not import to local'
  theme_help_topic fetch_files 'plf' 'Fetch production files to local, but do not overwrite local'
  theme_help_topic reset 'pl' 'A reset all shortcut (uses previously fetched data)'
  theme_help_topic reset_db 'pld' 'Overwrite local db with previously fetched production db'
  theme_help_topic reset_files 'plf' 'Replace local files with previously fetched production files'
  theme_help_topic pull 'pl' 'A fetch and reset all shortcut'
  theme_help_topic pull_db 'pld' 'A fetch and reset database shortcut'
  theme_help_topic pull_files 'plf' 'Fetch and reset files shortcut'

  theme_header 'to staging' 2
  theme_help_topic push 'lst' 'A push all shortcut'
  theme_help_topic push_db 'lsd' 'Dump local db and push it to staging for manual import'
  theme_help_topic push_files 'lsf' 'Push local files to staging, overwriting staging files'

  theme_header 'local' 3
  theme_help_topic dump_db 'l' 'Dump the local db with an optional suffix' 'dump_db [suffix]'
  theme_help_topic import_db 'l' 'Import a db dump file overwriting local' 'import_db [suffix]'
  theme_help_topic help 'l' 'Show this help screen'
  theme_help_topic info 'l' 'Show info'
  theme_help_topic configtest 'l' 'Test configuration'
  theme_help_topic ls 'l' 'List contents of db or files directories.  Flags for ls may be added.' 'ls (db|files) (ls flags)'
  theme_help_topic pass 'l' 'Display the production or staging server password' 'pass (prod|staging)'
}

##
 # Test for a mysql connection
 #
 # @param string $1
 #   username
 # @param string $2
 #   The password
 # @param string $3
 #   The database name
 # @param string $4
 #   Optional; defaults to localhost
 #
 # @return bool
 #   Sets the value of $mysql_check_result
 #
function mysql_check() {
  db_user=$1
  db_pass=$2
  db_name=$3
  db_host=$4
  mysql -u "${db_user}" -p"${db_pass}" -h "${db_host}" "${db_name}" -e exit 2>/dev/null
  db_status=`echo $?`
  if [ $db_status -ne 0 ]
  then
    mysql_check_result=false;
  else
    mysql_check_result=true;
  fi
}

##
 # Get the current version of the package
 #
 # @return string
 #   Sets the value of version_result
 #
 # @todo Make this work for non-standard installation locations?
 #
function version() {
  path="${HOME}/bin/loft_deploy_files/web_package.info"
  if [ -f "$path" ]
  then
    version_result=$(grep "version" $path | cut -f2 -d "=");
  fi

}

##
 # Print out the header
 #
 #
function print_header() {
  echo "~ $local_title ~ $local_role ~" | tr "[:lower:]" "[:upper:]"
  echo
}

##
 # Run a config test and printout results
 #
 # @param string $1
 #   description of param
 #
 # @return NULL
 #   Sets the value of global $configtest_return
 #
function configtest() {
  configtest_return=true;
  echo 'Testing...'
  # Test if the staging and production files are the same, but only if we have production files
  if [ "$production_files" ] && [ "$local_files" == "$production_files" ]
  then
    configtest_return=false;
    warning 'Your local files directory and production files directory should not be the same'
  fi

  # Test for the presence of the .htaccess file in the .loft_config dir
  if [ ! -f  "$config_dir/.htaccess" ]
  then
    configtest_return=false
    warning "Missing .htaccess in $config_dir; if web accessible, your data is at risk!" "echo 'deny from all' > $config_dir/.htaccess"
  fi

  #Test to make sure the .htaccess contains deny from all
  contents=$(grep 'deny from all' $config_dir/.htaccess)
  if [ ! "$contents" ]
  then
    configtest_return=false
    warning "$config_dir/.htaccess should contain the 'deny from all' directive; your data may be at risk!"
  fi

  # Test for prod server password in prod environments
  if ([ "$local_role" == 'prod' ] && [ "$production_pass" ]) || ([ "$local_role" == 'staging' ] && [ "$staging_pass" ])
  then
    configtest_return=false;
    warning "For security purposes you should remove the $local_role server password from your config file in a $local_role environment."
  fi

  # Test for other environments than prod, in prod environment
  if [ "$local_role" == 'prod' ] && ( [ "$prod_server" ] || [ "$staging_server" ] )
  then
    configtest_return=false;
    warning "In a $local_role environment, no other environments should be defined.  Remove extra settings from config."
  fi

  # Test for directories
  if [ ! -d "$local_db_dir" ]
  then
    configtest_return=false;
    warning "local_db_dir: $local_db_dir does not exist."
  fi

  if [ "$local_files" ] && [ ! -d "$local_files" ]
  then
    configtest_return=false;
    warning "local_files: $local_files does not exist."
  fi

  # Test for a production root in dev environments
  if [ "$local_role" == 'dev' ] && [ ! "$production_root" ]
  then
    configtest_return=false;
    warning "production_root: Please define the production environment's root directory "
  fi

  # Test for db access
  mysql_check_result=false
  mysql_check $local_db_user $local_db_pass $local_db_name $local_db_host
  if [ $mysql_check_result == false ]
  then
    configtest_return=false;
    warning "Can't connect to local DB; check credentials"
  fi

  # @todo test for ssh connection to prod
  # @todo test for ssh connection to staging

  # @todo test local and remote paths match
  if [ "$configtest_return" == true ]
  then
    echo 'All tests passed.'
  else
    echo 'Some tests failed; see earlier warnings!'
  fi

}


##
 # Display configuation info
 #
function show_info() {
  clear
  print_header

  #echo "Configuration..."
  echo '~ LOCAL ~'
  echo "Role          : $local_role " | tr "[:lower:]" "[:upper:]"
  echo "Config        : $config_dir"
  echo "DB            : $local_db_name"
  echo "DB User       : $local_db_user"
  echo "Dumps         : $local_db_dir"
  echo "Files         : $local_files"
  access=false
  _access_check 'fetch_db'
  if [ "$access" == true ]
  then
    echo "DB Fetched    : " $(cat $config_dir/cached_db)
  fi
  access=false
  _access_check 'fetch_files'
  if [ "$access" == true ]
  then
    echo "Files Fetched : " $(cat $config_dir/cached_files)
  fi
  echo

  if [ "$local_role" == 'dev' ]
  then
    echo '~ PRODUCTION ~'
    echo "Server        : $production_server"
    echo "DB            : $production_db_name"
    echo "Dumps         : $production_db_dir"
    echo "Files         : $production_files"
    echo
    echo "~ STAGING ~"
    echo "Server        : $staging_server"
    echo "DB            : $staging_db_name"
    echo "Dumps         : $staging_db_dir"
    echo "Files         : $staging_files"
    echo
  fi

  version_result='?'
  version
  echo '~ LOFT_DEPLOY ~'
  echo "Version       : $version_result"
}

function warning() {
  echo
  #echo "!!!!!!WARNING!!!!!!"
  echo "`tput setaf 3`$1`tput op`"
  if [ "$2" ]
  then
    echo_fix "$2"
  fi
  confirm 'Disregard warning'
}

##
 # Output the suggested fix
 #
 # @param string $1
 #   The string of text to output
 #
 # @return NULL
 #   Sets the value of global $echo_fix_return
 #
function echo_fix() {
  echo 'To fix this try:'
  echo "`tput setaf 2`$1`tput op`"
  echo
}


##
 # End execution with a message
 #
 # @param string $1
 #   A message to display
 #
function end() {
  echo
  echo $1
  echo
  exit;
}

##
 # Sets the value of $access based on $1 op
 #
 # @param string $1
 #   An op to test for against current config
 #
 # @return bool (sets value of global $access)
 #
function _access_check() {
  # List out helper commands, with universal access regardless of local_role
  if [ "$1" == '' ] || [ "$1" == 'help' ] || [ "$1" == 'info' ] || [ "$1" == 'configtest' ] || [ "$1" == 'ls' ] || [ "$1" == 'init' ]
  then
    access=true
    return
  fi
  # For each role, list the ops they MAY execute
  if [ "$local_role" == 'prod' ]
  then
    case $1 in
      'dump_db')
        access=true
        ;;
    esac
  elif [ "$local_role" == 'staging' ]
  then
    case $1 in
      'import_db')
        access=true
        ;;
      'pass')
        access=true
        ;;
    esac
  elif [ "$local_role" == 'dev' ]
  then
    access=true
  fi
}

##
 # End Functions
 #

##
 # Begin Controller
 #

# init has to come before configuration loading
if [ "$1" == 'init' ]
then
  access=false
  _access_check $op
  if [ "$access" == false ]
  then
    echo "`tput setaf 1`ACCESS DENIED!`tput op`"
    end "$local_role sites may not invoke: loft_deploy $op"
  else
    init $2
  fi
fi

load_config

# Help MUST COME AFTER CONFIG FOR ACCESS CHECKING!!!! DON'T MOVE
if [ ! "$op" ] || [ "$op" == 'help' ]
then
  show_help

  if [ ! "$op" ]
  then
    echo "Please call with one or more arguments."
  fi
  end
fi

##
 # Access Check
 #
access=false
_access_check $op
if [ "$access" == false ]
then
  echo "`tput setaf 1`ACCESS DENIED!`tput op`"
  end "$local_role sites may not invoke: loft_deploy $op"
fi

##
 # Call the correct handler
 #
print_header
case $op in
  'init')
    init $2
    complete
    end
    ;;
  'ls')
    case $2 in
      'db')
        dir="$local_db_dir"
        ;;
      'files')
        dir="$local_files"
        ;;
    esac
    echo $dir
    if [ "$3" ]
    then
      flags=$3
    fi
    ls $dir
    complete
    end
    ;;
  'configtest')
    configtest
    complete
    end
    ;;
  'dump_db')
    dump_db $2
    complete
    end
    ;;
  'pull')
    fetch_db
    reset_db
    fetch_files
    reset_files
    complete 'Database & Files fetched and reset'
    end
    ;;
  'pull_files')
    fetch_files
    reset_files
    complete 'Files fetched and reset'
    end
    ;;
  'pull_db')
    fetch_db
    reset_db
    complete 'Database fetched and reset'
    end
    ;;
  'push')
    push_db
    push_files
    complete 'Database & Files pushed to Staging'
    end
    ;;
  'push_files')
    push_files
    complete
    end
    ;;
  'push_db')
    push_db
    complete
    end
    ;;
  'fetch_files')
    fetch_files
    complete "Production files have been fetched; use reset_files when ready."
    end
    ;;
  'reset_files')
    reset_files
    complete 'Local files have been reset with production.'
    end
    ;;
  'fetch_db')
    fetch_db
    complete 'Production database has been fetched; use reset_db when ready.'
    end
    ;;
  'reset_db')
    reset_db
    complete 'Local database has been reset with production.'
    end
    ;;
  'fetch')
    fetch_db
    complete
    fetch_files
    complete
    end
    ;;
  'reset')
    reset_db
    complete
    reset_files
    complete
    end
    ;;
  'import_db')
    import_db $2
    complete
    end
    ;;
  'help')
    show_help
    complete
    end
    ;;
  'info')
    show_info
    complete
    end
    ;;
  'pass')
    if [ "$2" == 'prod' ]
    then
      complete "Production Password: `tput setaf 2`$production_pass`tput op`"
    elif [ "$2" == 'staging' ]
    then
      complete "Staging Password: `tput setaf 2`$staging_pass`tput op`"
    fi
    end
    ;;
esac

end "loft_deploy $op is an unknown operation."
