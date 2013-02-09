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
cwd=${PWD}

# holds the full path to the last db dump
current_db_dir=''

# holds the filename of the last db dump
current_db_filename=''

# holds the directory of the config file
config_dir=$cwd

# holds the result of connect()
mysql_check_result=false

##
 # Load the configuration file
 #
function load_config() {
  cd $config_dir
  file=.loft_deploy
  if [ ! -f "$file" ]
  then
    _upsearch $file
  fi
  source $file
  cd $cwd
}

##
 # Recursive search for file in parent dirs
 #
function _upsearch () {
  test / == "$PWD" && echo && echo "NO CONFIG FILE FOUND!" && end "Please create .loft_deploy above web root" || test -e "$1" && config_dir=${PWD} && return || cd .. && _upsearch "$1"
}

##
 # Fetch production files to local
 #
function fetch_files() {
  if [ ! "$production_files" ] || [ ! "$local_files" ] || [ "$production_files" == "$local_files" ]
  then
    end "Bad config"
  fi
  confirm 'Are you sure you want to fetch prod files OVERWRITING LOCAL files'
  echo 'Previewing...'
  rsync -av $production_server://$production_files/ $local_files/ --delete --dry-run
  confirm 'That was a preview... do it for real?'
  rsync -av $production_server://$production_files/ $local_files/ --delete
}

##
 # Fetch the remote db and import it to local
 #
function fetch_db() {
  confirm 'Are you sure you want to OVERWRITE YOUR LOCAL DB with the production db'
  ssh $production_server . $production_db_tag dump_db
  wait
  _current_db_paths fetch_db
  scp $production_server://$production_db_dir/${production_db_name}_fetch_db.sql $current_db_dir

  #backup local
  dump_db local_backup

  #import production to local


}

##
 # Push local db (with optional dump) to staging
 #
function push_db() {
  if [ ! "$staging_db_dir" ] || [ ! "$staging_server" ]
  then
    warning "You cannot push your database unless you define a staging environment."
    end
  fi
  confirm "Are you sure you want to push your local db to staging"

  suffix='push_db'
  dump_db $suffix
  echo 'Pushing db to staging...'
  scp $current_db_dir$current_db_filename $staging_server://$staging_db_dir/$current_db_filename
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
    confirm "File $current_db_dir$current_db_filename exists, replace" --soft
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

  echo "Dumping the database to $current_db_dir$current_db_filename..."
  mysqldump -u $local_db_user -p$local_db_pass -h $local_db_host $local_db_name -r $current_db_dir$current_db_filename
}

##
 # Import a db dump file into local db, overwriting local
 #
 # @param string $1
 #   The filename of the dumpfile
 #
function import_db() {
  _current_db_paths
  if [ ! "$1" ] || [ ! -f $current_db_dir$1 ]
  then
    end "File $current_db_dir$1 not found."
  fi
  confirm "You are about to OVERWRITE YOUR LOCAL DATABASE, are you sure"
  echo "We need remove all tables first for a clean slate."
  _drop_tables
  echo "Importing $current_db_dir$1 to $local_db_host $local_db_name database..."
  mysql -u $local_db_user -p$local_db_pass -h $local_db_host $local_db_name < $current_db_dir$1
}

##
 # Drop all local db tables
 #
function _drop_tables() {
  confirm "Do you really want to DUMP ALL TABLES from $local_db_host $local_db_name"
  tables=$(mysql -u $local_db_user -p$local_db_pass -h $local_db_host $local_db_name -e 'show tables' | awk '{ print $1}' | grep -v '^Tables' )
  echo "Dropping all tables from the $local_db_name database..."
  for t	in $tables
  do
    echo $t
    mysql -u $local_db_user -p$local_db_pass -h $local_db_host $local_db_name -e "drop table $t"
  done
  echo
}

##
 # Accept a y/n confirmation message or end
 #
 # @param string $1
 #   A question to ask
 # @param string $2
 #   A flag, e.g. --soft; which means a n will not exit
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
    if [ "$2" != '--soft' ]
    then
      end 'CANCELLED!'
    fi
  fi
  echo
}

##
 # Display help for this script
 #
function show_help() {
  echo
  echo '~ LOFT DEPLOY HELP ~'
  echo
  echo '~ WORKFLOW COMMANDS ~'
  echo
  access=false
  _access_check dump_db
  if [ $access ]
  then
    echo 'loft_deploy dump_db [suffix]'
    echo '    Dump the local db with an optional suffix'
    echo '    LOCAL DB ---> ???'
    echo
  fi
  access=false
  _access_check push_db
  if [ $access ]
  then
    echo 'loft_deploy push_db'
    echo '    Dump local db and push it to staging for manual import'
    echo '    LOCAL DB ---> STAGING DB'
    echo
  fi
  access=false
  _access_check fetch_db
  if [ $access ]
  then
    echo 'loft_deploy fetch_db'
    echo '    Pull production db and import it to local, overwriting local'
    echo '    LOCAL DB <--- PRODUCTION DB'
    echo
  fi
  access=false
  _access_check import_db
  if [ $access ]
  then
    echo 'loft_deploy import_db [suffix]'
    echo '    Import a db dump file overwriting local'
    echo '    LOCAL DB <--- ???'
    echo
  fi
  access=false
  _access_check fetch_files
  if [ $access ]
  then
    echo 'loft_deploy fetch_files'
    echo '    Fetch production files to local, overwriting local files'
    echo '    LOCAL FILES <--- PRODUCTION FILES'
    echo
  fi
  echo
  echo '~ HELPER COMMANDS ~'
  echo
  echo 'loft_deploy help'
  echo '    Show this help screen'
  echo
  echo 'loft_deploy config'
  echo '    Review the configuration'
  echo
  echo 'loft_deploy go (top|db|files)'
  echo '    Quickly jump to a directory.'
  echo
  echo 'loft_deploy pass p (or s)'
  echo '    Display the production or staging server password'
  echo
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
 # Display configuation info
 #
function show_config() {
  clear

  version_result='v?'
  version
  echo "~ LOFT_DEPLOY$version_result ~"
  echo "Testing..."

  # Test if the staging and production files are the same
  if [ "$local_files" == "$production_files" ]
  then
    warning 'Your local files directory and production files directory should not be the same'
  fi

  # Test for prod server password in prod environments
  if ([ "$local_role" == 'prod' ] && [ "$production_pass" ]) || ([ "$local_role" == 'staging' ] && [ "$staging_pass" ])
  then
    warning "For security purposes you should remove the $local_role server password from your config file in a $local_role environment."
  fi

  # Test for other environments than prod, in prod environment
  if [ "$local_role" == 'prod' ] && ( [ "$prod_server" ] || [ "$staging_server" ] )
  then
    warning "In a $local_role environment, no other environments should be defined.  Remove extra settings from config."
  fi

  # Test for directories
  if [ -d "$local_db_dir" ]
  then
    echo "TEST: $local_db_dir exists."
  else
    warning "local_db_dir: $local_db_dir does not exist."
  fi

  if [ -d "$local_files" ]
  then
    echo "TEST: $local_files exists."
  else
    warning "local_files: $local_files does not exist."
  fi

  # Test for db access
  mysql_check_result=false
  mysql_check $local_db_user $local_db_pass $local_db_name $local_db_host
  if [ $mysql_check_result == true ]
  then
    echo "TEST: Local DB connection good."
  else
    warning "Can't connect to local DB; check credentials"
  fi

  # @todo test for ssh connection to prod
  # @todo test for ssh connection to staging
  echo
  echo "Configuration..."
  echo '~ LOCAL ~'
  echo "Role   : $local_role"
  echo "Config : $config_dir/.loft_deploy"
  echo "DB     : $local_db_name"
  echo "Dumps  : $local_db_dir"
  echo "Files  : $local_files"
  echo
  echo '~ STAGING ~'
  echo "Server : $staging_server"
  #echo "DB     : $staging_db_name"
  echo "Dumps  : $staging_db_dir"
  #echo "Files  : $staging_files"
  echo
  echo '~ PRODUCTION ~'
  echo "Server : $production_server"
  echo "DB     : $production_db_name"
  echo "Files  : $production_files"
  echo
}

function warning() {
  echo
  echo "!!!!!!WARNING!!!!!!"
  echo $1
  confirm 'Disregard warning'
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
  if [ "$1" == '' ] || [ "$1" == 'config' ]
  then
    access=true
    return
  fi

  # For each role, list the ops they MAY execute
  if [ "$local_role" == 'prod' ]
  then
    case $1 in
      dump_db)
        access=true
        ;;
      db)
        access=true
        ;;
    esac
  elif [ "$local_role" == 'staging' ]
  then
    case $1 in
      import_db)
        access=true
        ;;
      db)
        access=true
        ;;
      fetch_files)
        access=true
        ;;
      pass)
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

# We'll place this here before config and access check to help the user
if [ ! "$op" ] || [ "$op" == 'help' ]
then
  show_help

  if [ ! "$op" ]
  then
    echo "Please call with one or more arguments."
  fi
  load_config
  end
fi

load_config

##
 # Access Check
 #
access=false
_access_check $op
if [ $access == false ]
then
  echo 'ACCESS DENIED!'
  end "$local_role sites may not invoke: loft_deploy $op"
fi


##
 # Call the correct handler
 #
case $op in
  'go')
    case $2 in
      'db')
        cd "$local_db_dir"
        ;;
      'files')
        cd "$local_files"
        ;;
      'top')
        cd "$config_dir"
        ;;
    esac
    ls -AGF
    end "You've moved to ${PWD}"
    ;;
  'dump_db')
    dump_db $2
    ;;
  'push_db')
    push_db
    ;;
  'fetch_files')
    fetch_files
    ;;
  'fetch_db')
    fetch_db
    ;;
  'import_db')
    import_db $2
    ;;
  'help')
    show_help
    ;;
  'config')
    show_config
    ;;
  'pass')
    echo
    if [ "$2" == 'p' ]
    then
      echo "Production Password: $production_pass"
    elif [ "$2" == 's' ]
    then
      echo "Staging Password: $staging_pass"
    fi
    echo
    ;;
esac
