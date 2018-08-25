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
source="${BASH_SOURCE[0]}"
while [ -h "$source" ]; do # resolve $source until the file is no longer a symlink
  dir="$( cd -P "$( dirname "$source" )" && pwd )"
  source="$(readlink "$source")"
  [[ $source != /* ]] && source="$dir/$source" # if $source was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
root="$( cd -P "$( dirname "$source" )" && pwd )"

##
 # Bootstrap
 #
declare -a args=()
declare -a flags=()
declare -a params=()
for arg in "$@"; do
  if [[ "$arg" =~ ^--(.*) ]]; then
    params=("${params[@]}" "${BASH_REMATCH[1]}")
  elif [[ "$arg" =~ ^-(.*) ]]; then
    flags=("${flags[@]}" "${BASH_REMATCH[1]}")
  else
    args=("${args[@]}" "$arg")
  fi
done
##
 # End Bootstrap
 #

# The user's operation
op=${args[0]}

# The target of the operation
target=${args[1]}

# Holds the starting directory
start_dir=${PWD}

# holds the full path to the last db export
current_db_dir=''

# holds the filename of the last db export
current_db_filename=''

# holds the directory of the config file
config_dir=${PWD}/.loft_deploy

# holds the result of connect()
mysql_check_result=false

# holds a timestamp for backups, etc.
now=$(date +"%Y%m%d_%H%M")

# Current version of this script (auto-updated during build).
ld_version=0.13.20

# theme color definitions
color_red=1
color_green=2
color_yellow=3
color_blue=4
color_magenta=5
color_cyan=6
color_white=7
color_staging=$color_green
color_local=$color_yellow
color_prod=$color_red

ld_remote_rsync_cmd="rsync -azP"

lobster_user=$(whoami)

##
 # Function Declarations
 #

##
 # Test for a flag
 #
 # @code
 # if has_flag s; then
 # @endcode
 #
 # @param string $1
 #   The flag name to test for, omit the -
 #
 # @return int
 #   0: it has the flag
 #   1: it does not have the flag
 #
function has_flag() {
  for var in "${flags[@]}"
  do
    if [[ "$var" =~ $1 ]]
    then
      return 0
    fi
  done
  return 1
}

##
 # Test for a parameter
 #
 # @code
 # if has_param code; then
 # @endcode
 #
 # @param string $1
 #   The param name to test for, omit the -
 #
 # @return int
 #   0: it has the param
 #   1: it does not have the param
 #
function has_param() {
  for var in "${params[@]}"
  do
    if [[ "$var" =~ $1 ]]
    then
      return 0
    fi
  done
  return 1
}

##
 # Extract the value of a script param e.g. (--param=value)
 #
 # @code
 # value=$(get_param try)
 # @endcode
 #
 # @param string $1
 #   The name of the param
 #
 # @return NULL
 #   Sets the value of global $get_param_return
 #
function get_param() {
  for var in "${params[@]}"
  do
    if [[ "$var" =~ ^(.*)\=(.*) ]] && [ ${BASH_REMATCH[1]} == $1 ]
    then
      echo ${BASH_REMATCH[2]}
      return
    fi
  done
}

function loft_deploy_mysql() {
  #@todo When we switch to lobster we need to add taking arguments for prod and staging.
  if has_param 'prod'; then
    _mysql_production
  elif has_param 'staging'; then
    _mysql_staging
  else
    _mysql_local "$1"
  fi
}

function _mysql_production() {
  load_production_config
  if [ ! "$production_remote_db_host" ]; then
    end "Bad production db config; missing: \$production_remote_db_host"
  fi
  if [ ! "$production_db_user" ]; then
    end "Bad production db config; missing: \$production_db_user"
  fi
  if [ ! "$production_db_pass" ]; then
    end "Bad production db config; missing: \$production_db_pass"
  fi
  if [ ! "$production_db_name" ]; then
    end "Bad production db config; missing: \$production_db_name"
  fi
  if [ "$production_db_port" ] && [ "$production_db_port" != null ]; then
    port=" --port=$production_db_port"
  fi
  show_switch
  cmd="$ld_mysql -u $production_db_user -p\"$production_db_pass\" -h $production_remote_db_host$port $production_db_name"
  eval $cmd
  show_switch
}

function _mysql_staging() {
  end "Not yet supported"
}

function _mysql_local() {
  cmd="$ld_mysql -u $local_db_user -p\"$local_db_pass\" -h $local_db_host$local_mysql_port $local_db_name"
  if [ "$1" ]; then
    echo "$1"
    cmd="$cmd --execute=\"$1\""
  fi
  eval $cmd
}

function update_needed() {
  local need=0
  # Test for _update_0_7_0
  if [[ ! -d "$config_dir/prod" ]]; then
    need=1
  fi

  # Test for _update_0_7_6
  if [[ -d "$config_dir/production" ]]; then
    need=1
  fi

  if [[ $need -eq 1 ]]; then
    echo "`tty -s && tput setaf 3`An update is necessary; the script may not perform as expected; please execute 'loft_deploy update' when ready.`tty -s && tput op`"
    echo ""
  fi
}

##
 # Perform any necessary update functions
 #
function update() {
  _update_0_7_6
  _update_0_7_0
  echo "`tty -s && tput setaf 2`All updates have been processed.`tty -s && tput op`"
  end
}

##
 # Moves db and files into a production folder to support the fetch from
 # multiple environments and changes to the storage mechanisms.
 #
function _update_0_7_0() {
  if [[ ! -d "$config_dir/prod" ]]; then
    mkdir "$config_dir/prod"

    if [[ -d "$config_dir/db" ]]; then
      mv "$config_dir/db" "$config_dir/prod/db"
    else
      mkdir "$config_dir/prod/db"
    fi

    if [[ -d "$config_dir/files" ]]; then
      mv "$config_dir/files" "$config_dir/prod/files"
    else
      mkdir "$config_dir/prod/files"
    fi

    if [[ -f "$config_dir/cached_db" ]]; then
      mv "$config_dir/cached_db" "$config_dir/prod/cached_db"
    fi

    if [[ -f "$config_dir/cached_files" ]]; then
      mv "$config_dir/cached_files" "$config_dir/prod/cached_files"
    fi
  fi

  if [[ ! -d "$config_dir/staging" ]]; then
    mkdir -p "$config_dir/staging/db"
    mkdir -p "$config_dir/staging/files"
  fi

  rm -rf "$config_dir/db" "$config_dir/files" "$config_dir/cached_db" "$config_dir/cached_files"
}

##
 # Assures removal of the config/production folder.
 #
function _update_0_7_6() {
  if [[ -d "$config_dir/production" ]]; then
    if [[ -d "$config_dir/prod" ]]; then
      rm -rf "$config_dir/production";
    else
      mv "$config_dir/production" "$config_dir/prod"
    fi
  fi
}

##
 # Initialize a new project
 #
 # @param string $1
 #   One of dev, staging or prod
 #
 # @return NULL
 #
function init() {
  if [ -d .loft_deploy ]; then
    end "$start_dir is already initialized."
  fi
  if [ $# -ne 1 ]; then
    end "Please specific one of: dev, staging or prod.  e.g. loft_deploy init dev"
  elif [ "$1" == 'dev' ] || [ "$1" == 'staging' ] || [ "$1" == 'prod' ]; then
    mkdir $config_dir && rsync -a "$root/install/base/" "$config_dir/"
    chmod 0644 "$config_dir/.htaccess"
    cp "$root/install/config/$1" "$config_dir/config"
    cd "$start_dir"
    complete
    end "Please configure and save $config_dir/config"
  else
    end "Invalid argument: $1"
  fi
}

function handle_sql_files() {

  local sql_dir="$config_dir/sql"

  # We have to clean this on out because it determins how the mysql
  # is processed in the export function.
  local file=$(get_filename_db_tables_data)
  test -f "$file" && rm $file

  test -e "$sql_dir" || return

  local processed_dir="$config_dir/cache"
  test -d "$processed_dir" || mkdir -p "$processed_dir"

  # Copy over text files direct
  for file in $(find $sql_dir  -type f -iname "*.txt"); do
    local name=$(basename "$file")
    cp "$file" "$processed_dir/$name"
  done

  # First compile sql files' dynamic variables
  for file in $(find $sql_dir  -type f -iname "*.sql"); do
    local sql=$(cat $file);

    sql=$(echo $sql | sed -e "s/\$local_db_name/$local_db_name/g")
    # sql=$(echo $sql | sed -e "s/\$local_db_user/$local_db_user/g")
    # sql=$(echo $sql | sed -e "s/\$local_db_pass/$local_db_pass/g")
    # sql=$(echo $sql | sed -e "s/\$local_role/$local_role/g")

    name=$(basename "$file")
    echo $sql > "$processed_dir/$name"
  done

  # Now execute the sql files
  for file in $(find $processed_dir  -type f -iname "*.sql"); do
    local cmd=$(cat $file)
    local outfile=${file%.*}.txt
    $ld_mysql -u $local_db_user -p"$local_db_pass" -h $local_db_host$local_db_port $local_db_name -s -N -e "$cmd" > "$outfile"
    rm $file
  done

  # Create the inversion of the no_data list as this is what we'll need
  local no_data="$processed_dir/db_tables_no_data.txt"
  if [[ -f "$no_data" ]]; then
    local i=0
    while read line; do
      tables[i]=$line
      i=$(($i + 1))
    done < $no_data
    local tables=$(printf ",\'%s\'" "${tables[@]}")
    tables=${tables:1}
    cmd="SELECT table_name FROM information_schema.tables WHERE table_schema = '$local_db_name' AND table_name NOT IN ($tables)"
    outfile=$(get_filename_db_tables_data)
    $ld_mysql -u $local_db_user -p"$local_db_pass" -h $local_db_host$local_db_port $local_db_name -s -N -e "$cmd" > "$outfile"
    rm $no_data
  fi
}

function get_filename_db_tables_data() {
  echo "$config_dir/cache/db_tables_data.txt"
}

##
 # Returns a csv snippet of all database tables to export data for
 #
 # This is ready to use in the sql statement.
 #
function get_sql_ready_db_tables_data() {
  no_data=$(get_filename_db_tables_data)
  test -e $no_data || return

  i=0
  while read line; do
    tables[i]=$line
    i=$(($i + 1))
  done < $no_data
  # tables=$(printf " %s" "${tables[@]}")
  # tables=${tables:1}
  echo ${tables[@]}
}

##
 # Load the configuration file
 #
function load_config() {
  _upsearch $(basename $config_dir)

  motd=''
  if [[ -f "$config_dir/motd" ]]; then
    motd=$(cat "$config_dir/motd");
  fi

  # Do we have a files exclude for rsync
  if [[ -f "$config_dir/files_exclude.txt" ]]; then
    ld_rsync_exclude_file="$config_dir/files_exclude.txt";
    ld_rsync_ex="--exclude-from=$ld_rsync_exclude_file"
  fi

  # these are defaults
  local_role="prod"
  local_db_host='localhost'
  production_pass=''
  production_root=''
  staging_pass=''

  ld_mysql=$(type mysql >/dev/null 2>&1 && which mysql)
  ld_mysqldump=$(type mysqldump >/dev/null 2>&1 && which mysqldump)
  ld_gzip=$(type gzip >/dev/null 2>&1 && which gzip)
  ld_gunzip=$(type gunzip >/dev/null 2>&1 && which gunzip)
  # For Pantheon support we need to find terminus
  ld_terminus=$(type terminus >/dev/null 2>&1 && which terminus)

  source $config_dir/config

  # Handle reading the drupal settings file if asked
  if [ "$local_drupal_settings" ]; then
    read -r -a settings <<< $(php "$root/includes/drupal_settings.php" "$local_drupal_root" "$local_drupal_settings" "$local_drupal_db")
    local_db_host=${settings[0]};
    local_db_name=${settings[1]};
    local_db_user=${settings[2]};
    local_db_pass=${settings[3]};
    local_db_port=${settings[4]};
  fi

  if [[ ! $production_scp ]]; then
    production_scp=$production_root
  fi;

  # Setup the mysql port.
  if [ "$local_db_port" ]; then
    local_mysql_port=" --port=$local_db_port"
  fi

  # Setup the port by prefixing with -p
  production_ssh_port=''
  production_scp_port=''
  production_rsync_port=''
  if [ "$production_port" ]; then
    production_ssh_port=" -p $production_port "
    production_scp_port=" -P $production_port "
  fi

  # Setup the port by prefixing with -p
  staging_ssh_port=''
  staging_scp_port=''
  staging_rsync_port=''
  if [ "$staging_port" ]; then
    staging_ssh_port=" -p $staging_port "
    staging_scp_port=" -P $staging_port "
  fi

  cd $start_dir
}

##
 # Logs in to production server for dynamic variables
 #
function load_production_config() {
  if [ "$production_server" ] && [ "$production_script" ]; then
    production=($(ssh $production_server$production_ssh_port "cd $production_root && $production_script get local_db_host; $production_script get local_db_name; $production_script get local_db_user; $production_script get local_db_pass; $production_script get local_db_dir; $production_script get local_files; $production_script get local_db_port;"))
    production_db_host="${production[0]}";
    production_db_name="${production[1]}";
    production_db_user="${production[2]}";
    production_db_pass="${production[3]}";
    production_db_dir="${production[4]}";
    production_files="${production[5]}";
    production_db_port="${production[6]}";
  elif [ "$pantheon_live_uuid" ]; then
    production_remote_db_host="dbserver.live.$pantheon_live_uuid.drush.in";
    production_db_name="pantheon";
    production_db_user="pantheon";
  fi
}

##
 # Logs in to staging for dynamic variables
 #
function load_staging_config() {
  if [ "$staging_server" ] && [ "$staging_script" ]; then
      staging=($(ssh $staging_server$staging_ssh_port "cd $staging_root && $staging_script get local_db_host; $staging_script get local_db_name; $staging_script get local_db_dir; $staging_script get local_files"))
    staging_db_host="${staging[0]}";
    staging_db_name="${staging[1]}";
    staging_db_dir="${staging[2]}";
    staging_files="${staging[3]}";
  fi
}

##
 # Recursive search for file in parent dirs
 #
function _upsearch () {
  test / == "$PWD" && echo && echo "`tty -s && tput setaf 1`NO CONFIG FILE FOUND!`tty -s && tput op`" && end "Please create .loft_deploy or make sure you are in a child directory." || test -e "$1" && config_dir=${PWD}/.loft_deploy && return || cd .. && _upsearch "$1"
}

##
 # Fetch files from the appropriate server
 #
function fetch_files() {
  case $source_server in
    'prod' )
      _fetch_files_production
      ;;
    'staging' )
      _fetch_files_staging
      ;;
  esac
}

##
 # Fetch prod files to local
 #
function _fetch_files_production() {
  load_production_config
  if [ ! "$production_files" ]; then
    end "\$production_files cannot be blank, try '.' instead."
  fi
  if [ ! "$local_files" ]; then
    end "\local_files cannot be blank, try '.' instead."
  fi
  if [ "$production_files" != '.' ] && [ "$production_files" == "$local_files" ]; then
    end "\$production_files and \$local_files should not be the same path."
  fi

  echo "Copying files from production server..."

  # Excludes message...
  if test -e "$ld_rsync_exclude_file"; then
    excludes="$(cat $ld_rsync_exclude_file)"
    echo "`tty -s && tput setaf 3`Excluding per: $ld_rsync_exclude_file`tty -s && tput op`"
    echo "`tty -s && tput setaf 3`$excludes`tty -s && tput op`"
  fi

  if [[ "$production_port" ]]; then
    cmd="$ld_remote_rsync_cmd -e \"ssh -p $production_port\" \"$production_server:$production_files/\" \"$config_dir/prod/files/\" --delete $ld_rsync_ex"

      echo "`tty -s && tput setaf 2`$cmd`tty -s && tput op`"
      eval $cmd;
  else
    cmd="$ld_remote_rsync_cmd \"$production_server:$production_files/\" \"$config_dir/prod/files/\" --delete $ld_rsync_ex"
    echo "`tty -s && tput setaf 2`$cmd`tty -s && tput op`"
    eval $cmd;
  fi

  # record the fetch date
  echo $now > $config_dir/prod/cached_files
}

##
 # Fetch staging files to local
 #
function _fetch_files_staging() {
  load_staging_config
  if [ ! "$staging_files" ] || [ ! "$local_files" ] || [ "$staging_files" == "$local_files" ]; then
    end "Bad config"
  fi

  # ld_rsync_ex=''
  echo "Copying files from staging server..."

  # Excludes message...
  if test -e "$ld_rsync_exclude_file"; then
    excludes="$(cat $ld_rsync_exclude_file)"
    echo "`tty -s && tput setaf 3`Excluding per: $ld_rsync_exclude_file`tty -s && tput op`"
    echo "`tty -s && tput setaf 3`$excludes`tty -s && tput op`"
  fi

  if [[ "$staging_port" ]]; then
    cmd="$ld_remote_rsync_cmd -e \"ssh -p $staging_port\" \"$staging_server:$staging_files/\" \"$config_dir/staging/files/\" --delete $ld_rsync_ex"
      echo "`tty -s && tput setaf 2`$cmd`tty -s && tput op`"
      eval $cmd;
  else
    cmd="$ld_remote_rsync_cmd \"$staging_server:$staging_files/\" \"$config_dir/staging/files/\" --delete $ld_rsync_ex"
    echo "`tty -s && tput setaf 2`$cmd`tty -s && tput op`"
    eval $cmd;
  fi

  # record the fetch date
  echo $now > $config_dir/staging/cached_files
}

##
 # Reset the local files with fetched prod files
 #
 # @param string $1
 #   description of param
 #
 # @return NULL
 #   Sets the value of global $reset_files_return
 #
function reset_files() {
  echo "This process will reset your local files to match the most recently fetched"
  echo "$source_server files, removing any local files that are not present in the fetched"
  echo "set. You will be given a preview of what will happen first. To absolutely"
  echo "match $source_server as of this moment in time, consider fetching first, however it is slower."
  echo
  echo "`tty -s && tput setaf 3`End result: Your local files directory will match fetched $source_server files.`tty -s && tput op`"

  source="$config_dir/$source_server/files"
  if [ ! -d $source ]; then
    end "Please fetch files first"
  fi

  # Excludes message...
  if test -e "$ld_rsync_exclude_file"; then
    excludes="$(cat $ld_rsync_exclude_file)"
    echo "`tty -s && tput setaf 3`Excluding per: $ld_rsync_exclude_file`tty -s && tput op`"
    echo "`tty -s && tput setaf 3`$excludes`tty -s && tput op`"
  fi

  # Have to exclude here because there might be some lingering files in the cache
  # say, if the exclude file was edited after an earlier sync. 2015-10-20T12:41, aklump
  cmd="rsync -av $source/ $local_files/ --delete $ld_rsync_ex"

  echo "`tty -s && tput setaf 2`Here is a preview:`tty -s && tput op`"
  eval "$cmd --dry-run"
  confirm "Are you sure you want to `tty -s && tput setaf 3`OVERWRITE LOCAL FILES with these $source_server files?`tty -s && tput op`"

  echo "`tty -s && tput setaf 2`$cmd`tty -s && tput op`"
  eval $cmd
}

##
 # Fetch the remote db and import it to local
 #
function fetch_db() {
  case $source_server in
    'prod' )
      _fetch_db_production
      ;;
    'staging' )
      _fetch_db_staging
      ;;
  esac
}

##
 # Fetch the remote db and import it to local
 #
function _fetch_db_production() {

  if [[ ! -d "$config_dir/prod/db" ]]; then
    mkdir "$config_dir/prod/db"
  fi

  # Cleanup local
  rm $config_dir/prod/db/fetched.sql* >/dev/null 2>&1

  echo "Exporting production db..."
  local _export_suffix='fetch_db'
  local _local_file="$config_dir/prod/db/fetched.sql.gz"

  ### Support for Pantheon
  if  [ "$terminus_site" ]; then
    if [ ! "$ld_terminus" ]; then
      end "Missing dependency terminus; please install per https://github.com/pantheon-systems/terminus/blob/master/README.md#installation"
    fi
    if [ ! "$terminus_machine_token" ]; then
      end "Create or add your terminus machine token as \$terminus_machine_token https://pantheon.io/docs/machine-tokens/"
    fi

    $ld_terminus auth:login --machine-token=$terminus_machine_token --quiet

    confirm "Creating a backup takes more time, shall we save time and download the lastest dashboard backup?" "noend"
    if [[ $confirm_result != 'true' ]]; then
      echo "Creating new backup using Terminus..."
      $ld_terminus backup:create $terminus_site.live --element=db
    fi
    echo "Downloading backup..."
    $ld_terminus backup:get $terminus_site.live --element=db --to="$_local_file"
    $ld_terminus auth:logout

  ### Default using SSH and SCP
  else
    load_production_config
    if [ ! "$production_script" ] || [ ! "$production_db_dir" ] || [ ! "$production_server" ] || [ ! "$production_db_name" ]; then
      end "Bad production db config"
    fi

    show_switch
    ssh $production_server$production_ssh_port "cd $production_root && . $production_script export $_export_suffix"
    wait

    echo "Downloading from production..."
    local _remote_file="$production_db_dir/${production_db_name}-$_export_suffix.sql.gz"
    scp $production_scp_port"$production_server:$_remote_file" "$_local_file"


    # delete it from remote
    echo "Deleting the production copy..."
    ssh $production_server$production_ssh_port "rm $_remote_file"
    show_switch

  fi

  # record the fetch date
  echo $now > $config_dir/prod/cached_db
}

##
 # Fetch the staging db and import it to local
 #
function _fetch_db_staging() {
  load_staging_config
  if [ ! "$staging_script" ] || [ ! "$staging_db_dir" ] || [ ! "$staging_server" ] || [ ! "$staging_db_name" ]; then
    end "Bad staging db config"
  fi

  if [[ ! -d "$config_dir/staging/db" ]]; then
    mkdir "$config_dir/staging/db"
  fi

  # Cleanup local
  rm $config_dir/prod/db/fetched.sql* >/dev/null 2>&1

  echo "Exporting staging db..."
  local _export_suffix='fetch_db'
  show_switch
  ssh $staging_server "cd $staging_root && . $staging_script export $_export_suffix"
  wait

  echo "Downloading from staging..."
  local _remote_file="$staging_db_dir/${staging_db_name}-$_export_suffix.sql.gz"
  local _local_file="$config_dir/staging/db/fetched.sql.gz"
  scp "$staging_server:$_remote_file" "$_local_file"

  # record the fetch date
  echo $now > $config_dir/staging/cached_db

  # delete it from remote
  echo "Deleting the staging copy..."
  ssh $staging_server "rm $_remote_file"
  show_switch
}

##
 # Reset the local database with a previously fetched copy
 #
 # @return NULL
 #   Sets the value of global $reset_db_return
 #
function reset_db() {
  echo "This process will reset your local db to match the most recently fetched"
  echo "$source_server db, first backing up your local db. To absolutely match $source_server,"
  echo "consider fetching the database first, however it is slower."
  echo
  echo "`tty -s && tput setaf 3`End result: Your local database will match the $source_server database.`tty -s && tput op`"

  confirm "Are you sure you want to `tty -s && tput setaf 3`OVERWRITE YOUR LOCAL DB`tty -s && tput op` with the $source_server db"

  local _file=($(find $config_dir/$source_server/db -name fetched.sql*))
  if [[ ${#_file[@]} -gt 1 ]]; then
    end "More than one fetched.sql file found; please remove the incorrect version(s) from $config_dir/$source_server/db"
  elif [[ ${#_file[@]} -eq 0 ]]; then
    end "Please fetch_db first"
  fi

  #backup local
#  confirm "Would you like a backup of the current db" "noend"
#  if [[ $confirm_result == 'true' ]]; then
    export_db "reset_backup_$now"
#  fi

  echo "Importing $_file"
  import_db "$_file"
}


##
 # Push local files to staging
 #
function push_files() {
  load_staging_config
  if [ ! "$staging_files" ]; then
    end "`tty -s && tput setaf 1`You cannot push your files unless you define a staging environment.`tty -s && tput op`"
  fi
  if [ ! "$local_files" ] || [ "$staging_files" == "$local_files" ]; then
    end "`tty -s && tput setaf 1`BAD CONFIG`tty -s && tput op`"
  fi

  echo "This process will push your local files to your staging server, removing any"
  echo "files on staging that are not present on local. You will be given"
  echo "a preview of what will happen first."
  echo
  echo "`tty -s && tput setaf 3`End result: Your staging files directory will match your local.`tty -s && tput op`"
  confirm 'Are you sure you want to push local files OVERWRITING STAGING files'
  echo 'Previewing...'
  if [[ "$ld_rsync_ex" ]]; then
    echo "`tty -s && tput setaf 3`Files listed in $ld_rsync_exclude_file are being ignored.`tty -s && tput op`"
  fi
  rsync -av $local_files/ $staging_server:$staging_files/ --delete --dry-run $ld_rsync_ex
  confirm 'That was a preview... do it for real?'
  rsync -av $local_files/ $staging_server:$staging_files/ --delete $ld_rsync_ex

  complete "Push files complete; please test your staging site."
}

##
 # Push local db (with optional export) to staging
 #
function push_db() {
  load_staging_config
  if [ ! "$staging_db_dir" ] || [ ! "$staging_server" ]; then
    end "You cannot push your database unless you define a staging environment."
  fi

  echo "This process will push your local database to your staging server, "
  echo "ERASING the staging database and REPLACING it with a copy from local."
  echo
  echo "`tty -s && tput setaf 3`End result: Your staging database will match your local.`tty -s && tput op`"
  confirm "Are you sure you want to push your local db to staging"

  suffix='push_db'
  export_db $suffix -f
  echo 'Pushing db to staging...'
  filename="$current_db_filename.gz"
  _remote_file="$staging_db_dir/$filename"
  scp "$current_db_dir/$filename" "$staging_server:$_remote_file"

  # Log into staging and import the database.
  show_switch
  ssh $staging_server "cd $staging_root && . $staging_script import $staging_db_dir/$filename"

  # delete it from remote
  echo "Deleting the db copy from production..."

  # Strip off the gz suffix
  _remote_file=${_remote_file%.*}
  ssh $staging_server "rm $_remote_file"
  show_switch

  # Delete our local copy
  rm "$current_db_dir/$filename"

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
  if [ "$local_db_dir" ]; then
    current_db_dir="$local_db_dir/"
  fi
  local _suffix=''
  if [ "$1" ]; then
    _suffix="-$1"
  fi
  current_db_filename="$local_db_name$_suffix.sql"
}

##
 # export the database with optional file suffix
 #
 # @param string $1
 #   Anything to add as a suffix
 # @param string $2
 #   If this is -f then we will just do it.
 #
function export_db() {
  _current_db_paths $1

  file="$current_db_dir$current_db_filename"
  file_gz="$file.gz"

  if [ -f "$file" ] && [ "$2" != '-f' ]; then
    if ! has_flag f; then
      confirm_result=false
      confirm "File $file exists, replace" noend
      if [ $confirm_result == false ]
      then
        echo "`tty -s && tput setaf 1`Cancelled.`tty -s && tput op`"
        return
      fi
    fi
    rm $file
  fi
  if [ -f "$file_gz" ] && [ "$2" != '-f' ]; then
    if ! has_flag f; then
      confirm_result=false
      confirm "File $file_gz exists, replace" noend
      if [ $confirm_result == false ]
      then
        echo "`tty -s && tput setaf 1`Cancelled.`tty -s && tput op`"
        return
      fi
    fi
    rm $file_gz
  fi

  if [ ! "$local_db_user" ] || [ ! "$local_db_pass" ] || [ ! "$local_db_name" ]; then
    end "Bad config"
  fi
  if [ ! "$local_db_host" ]; then
    local_db_host="localhost"
  fi

  echo "Exporting database as $file_gz..."

  # Do we need to process a db_tables_no_data file?
  handle_sql_files

  # There are two ways of doing this, it will depend if we are to exclude data
  # from some tables or not
  data=$(get_sql_ready_db_tables_data)
  if [[ "$data" ]]; then
    echo "`tty -s && tput setaf 3`Omitting data from some tables.`tty -s && tput op`"
    $ld_mysqldump -u $local_db_user -p"$local_db_pass" -h $local_db_host$local_mysql_port $local_db_name --no-data > "$file"
    $ld_mysqldump -u $local_db_user -p"$local_db_pass" -h $local_db_host$local_mysql_port $local_db_name $data --no-create-info >> "$file"
  else
    $ld_mysqldump -u $local_db_user -p"$local_db_pass" -h $local_db_host$local_mysql_port $local_db_name -r "$file"
  fi

  if [ "$2" == '-f' ]; then
    $ld_gzip -f "$file"
  else
    $ld_gzip "$file"
  fi
}

##
 # Import a db export file into local db, overwriting local
 #
 # @param string $1
 #   If this is not a path to a file, it will be assumed a filename in
 #   $local_db_dir
 #
function import_db() {
  _current_db_paths $1

  if [[ ! "$1" ]]; then
    echo "`tty -s && tput setaf 1`Filename of db dump required.`tty -s && tput op`"
    end
  fi

  if file=$1 && check1=$file && [ ! -f $1 ] && file=$current_db_dir$current_db_filename && check2=$file && [ ! -f $file ] && file=$file.gz && check3=$file && [ ! -f $file ]; then

    echo "File not found as:"
    echo $check1;
    echo $check2;
    echo $check3;
    end
  fi

  confirm "You are about to `tty -s && tput setaf 3`OVERWRITE YOUR LOCAL DATABASE`tty -s && tput op`, are you sure"
  # echo "It's advisable to empty the database first."
  _drop_tables
  echo "Importing $file to $local_db_host $local_db_name database..."

  if [[ ${file##*.} == 'gz' ]]; then
    $ld_gunzip "$file"
    file=${file%.*}
  fi
  $ld_mysql -u $local_db_user -p"$local_db_pass" -h $local_db_host$local_mysql_port $local_db_name < $file
}

##
 # Drop all local db tables
 #
function _drop_tables() {
  # confirm_result=false;
  # confirm "Should we `tty -s && tput setaf 3`DUMP ALL TABLES (empty database)`tty -s && tput op` from $local_db_host $local_db_name, first" noend
  # if [ $confirm_result == false ]; then
  #   return
  # fi
  tables=$($ld_mysql -u $local_db_user -p"$local_db_pass" -h $local_db_host$local_mysql_port $local_db_name -e 'show tables' | awk '{ print $1}' | grep -v '^Tables' )
  echo "Dropping all tables from the $local_db_name database..."
  for t	in $tables; do
    echo $t
    $ld_mysql -u $local_db_user -p"$local_db_pass" -h $local_db_host$local_mysql_port $local_db_name -e "drop table $t"
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
  if [ $# -ne 0 ]; then
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
  if [ "$a" != 'y' ]; then
    confirm_result=false
    if [ "$2" != 'noend' ]; then
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
  if _access_check $1; then
    left="<<<"
    right=">>>"
    case $2 in
        'l')
          color=$color_local
          icon="`tty -s && tput setaf $color_local`local`tty -s && tput op`"
          icon='';;

        'pl')
          color=$color_prod
          icon="`tty -s && tput setaf $color_prod`local $left`tty -s && tput op` prod";;
        'pld')
          color=$color_prod
          icon="`tty -s && tput setaf $color_prod`local db $left`tty -s && tput op` prod db";;
        'plf')
          color=$color_prod
          icon="`tty -s && tput setaf $color_prod`local files $left`tty -s && tput op` prod files";;

        #'lp')
        #  color=3
        #  icon="`tty -s && tput setaf 3`local $right`tty -s && tput op` prod";;
        #'lpd')
        #  icon="`tty -s && tput setaf 3`local db $right`tty -s && tput op` prod db";;
        #'lpf')
        #  icon="`tty -s && tput setaf 3`local files $right`tty -s && tput op` prod files";;

        'sl')
          icon="`tty -s && tput setaf 3`local $left`tty -s && tput op` staging";;
        'sld')
          icon="`tty -s && tput setaf 3`local db$left `tty -s && tput op` staging db";;
        'slf')
          icon="`tty -s && tput setaf 3`local files$left `tty -s && tput op` staging files";;

        'lst')
          color=$color_staging
          icon="local `tty -s && tput setaf $color_staging`$right staging`tty -s && tput op`";;
        'lsd')
          color=$color_staging
          icon="local db `tty -s && tput setaf $color_staging`$right staging db`tty -s && tput op`";;
        'lsf')
          color=$color_staging
          icon="local files `tty -s && tput setaf $color_staging`$right staging files`tty -s && tput op`";;
    esac

    echo "`tty -s && tput setaf $color`$1`tty -s && tput op`"
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
  if [ $# -eq 1 ]; then
    color=7
  else
    color=$2
  fi
  echo "`tty -s && tput setaf $color`~~$1~~`tty -s && tput op`"
}

function show_switch() {
  echo "`tty -s && tput setaf 6`!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!`tty -s && tput op`"
  echo "`tty -s && tput setaf 6`!!              CHANGING SERVERS                !!!`tty -s && tput op`"
  echo "`tty -s && tput setaf 6`!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!`tty -s && tput op`"
}


##
 # Display help for this script
 #
function show_help() {
  clear

  title=$(echo "Commands for a $local_role Environment" | tr "[:lower:]" "[:upper:]")
  theme_header "$title"

  theme_header 'local' $color_local
  theme_help_topic export 'l' 'Dump the local db with an optional suffix' 'export [suffix]' '-f to overwrite if exists'
  theme_help_topic import 'l' 'Import a db export file overwriting local' 'import [suffix]'
  theme_help_topic 'mysql' 'l' 'Start mysql shell using local credentials'
  theme_help_topic 'mysql "SQL"' 'l' 'Execute a mysql statement using local credentials'
  theme_help_topic 'scp' 'l' 'Display a scp stub using server values' 'see $production_scp for configuration'
  theme_help_topic help 'l' 'Show this help screen'
  theme_help_topic info 'l' 'Show info'
  theme_help_topic configtest 'l' 'Test configuration'
  theme_help_topic ls 'l' 'List the contents of various directories' '-d Database exports' '-f Files directory' 'ls can take flags too, e.g. loft_deploy -f ls -la'
  theme_help_topic pass 'l' 'Display password(s)' '--prod Production' 'staging Staging' '--all All'
  theme_help_topic terminus 'l' 'Login to terminus with prod credentials'
  theme_help_topic hook 'l' 'Run the indicated hook, e.g. hook reset'

  if [ "$local_role" != 'prod' ]; then
    theme_header 'from prod' $color_prod
  fi

  theme_help_topic fetch 'pl' 'Fetch production assets only; do not reset local.' '-f to only fetch files, e.g. fetch -f' '-d to only fetch database'
  theme_help_topic reset 'pl' 'Reset local with fetched assets' '-f only reset files' '-d only reset database'
  theme_help_topic pull 'pl' 'Fetch production assets and reset local.' '-f to only pull files' '-d to only pull database'

  if [ "$local_role" != 'staging' ]; then
    theme_header 'to/from staging' $color_staging
  fi

  theme_help_topic push 'lst' 'A push all shortcut' '-f files only' '-d database only'

  theme_help_topic fetch 'pl' 'Use `staging` to fetch staging assets only; do not reset local.' '-f to only fetch files, e.g. fetch -f staging' '-d to only fetch database'
  theme_help_topic reset 'pl' 'Use `staging` to reset local with fetched assets' '-f only reset files' '-d only reset database'
  theme_help_topic pull 'pl' 'Use `staging` to fetch staging assets and reset local.' '-f to only pull files' '-d to only pull database'

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
  local db_user=$1
  local db_pass=$2
  local db_name=$3
  local db_host=$4
  local db_port=$5

  if [ "$db_port" ]; then
    db_port="--port=$db_port"
  fi
  $ld_mysql -u "$db_user" -p'"$db_pass"' "$db_port" -h "$db_host" "$db_name" -e exit 2>/dev/null
  db_status=`echo $?`
  if [ $db_status -ne 0 ]; then
    mysql_check_result=false;
  else
    mysql_check_result=true;
  fi
}

##
 # Print out the header
 #
 #
function print_header() {
  echo "~ $local_title ~ $local_role ~" | tr "[:lower:]" "[:upper:]"
  if [[ "$motd" ]]; then
    echo
    echo "`tty -s && tput setaf 5`$motd`tty -s && tput op`"
  fi
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

  # Test for Pantheon support
  if  [ "$terminus_site" ]; then

    # assert can login
    if ! $ld_terminus auth:login --machine-token=$terminus_machine_token; then
        warning "Terminus cannot login; check variable terminus_machine_token."
        configtest_return=false
    fi
  fi

  # Test for the production_script variable.
  if [ "$production_server" ] && [ ! "$production_script" ]; then
    configtest_return=false
    warning "production_script variable is missing or empty in local coniguration."
  fi

  # Assert production script is found on remote
  if [ "$production_root" ] && ! ssh $production_server$production_ssh_port "[ -f '${production_script}' ]"; then
    configtest_return=false
    warning "production_script: ${production_script} not found. Make sure you're not using ~ in the path."
  fi

  if [ "$production_server" ]; then
    load_production_config
  fi

  # Test that local prod connects to a remote environment with a prod role
  if [ "$prod_server" ]; then
    role=$(ssh $prod_server$prod_ssh_port "cd $prod_root && . $prod_script get local_role")
    if [ "$role" != 'prod' ]; then
      configtest_return=false
      warning "Prod server as defined locally reports it's role as '$role'"
    fi
  fi

  # Test for the staging_script variable.
  if [ "$staging_server" ] && [ ! "$staging_script" ]; then
    configtest_return=false
    warning "staging_script variable is missing or empty in local coniguration."
  fi

  # Assert staging script is found on remote
  if [ "$staging_root" ] && ! ssh $staging_server$staging_ssh_port "[ -f '${staging_script}' ]"; then
    configtest_return=false
    warning "staging_script: ${staging_script} not found. Make sure you're not using ~ in the path."
  fi

  if [ "$staging_server" ]; then
    load_staging_config
  fi

  # Test that local staging connects to a remote environment with a staging role
  if [ "$staging_server" ]; then
    role=$(ssh $staging_server$staging_ssh_port "cd $staging_root && . $staging_script get local_role")
    if [ "$role" != 'staging' ]; then
      configtest_return=false
      warning "Staging server as defined locally reports it's role as '$role'"
    fi
  fi

  # Test if the staging and production files are the same, but only if we have production files
  if [ "$production_files" ] && [ "$local_files" == "$production_files" ]; then
    configtest_return=false;
    warning 'Your local files directory and production files directory should not be the same'
  fi

  # Assert the production script is found.

  # Assert that the production file directory exists
  if [ "$production_server" ] && [ "$production_files" ] && ! ssh $production_server$production_ssh_port "test -e $production_files"; then
    configtest_return=false;
    warning "Your production files directory doesn't exist: $production_files"
  fi

  # Test for the presence of the .htaccess file in the .loft_config dir
  if [ ! -f  "$config_dir/.htaccess" ]; then
    configtest_return=false
    warning "Missing .htaccess in $config_dir; if web accessible, your data is at risk!" "echo 'deny from all' > $config_dir/.htaccess"
  fi

  #Test to make sure the .htaccess contains deny from all
  contents=$(grep 'deny from all' $config_dir/.htaccess)
  if [ ! "$contents" ]; then
    configtest_return=false
    warning "$config_dir/.htaccess should contain the 'deny from all' directive; your data may be at risk!"
  fi

  # Test for prod server password in prod environments
  if ([ "$local_role" == 'prod' ] && [ "$production_pass" ]) || ([ "$local_role" == 'staging' ] && [ "$staging_pass" ]); then
    configtest_return=false;
    warning "For security purposes you should remove the $local_role server password from your config file in a $local_role environment."
  fi

  # Test for other environments than prod, in prod environment
  if [ "$local_role" == 'prod' ] && ( [ "$production_server" ] || [ "$staging_server" ] ); then
    configtest_return=false;
    warning "In a $local_role environment, no other environments should be defined.  Remove extra settings from config."
  fi

  # Test for directories
  if [ ! -d "$local_db_dir" ]; then
    configtest_return=false;
    warning "local_db_dir: $local_db_dir does not exist."
  fi

  if [ "$local_files" ] && [ ! -d "$local_files" ]; then
    configtest_return=false;
    warning "local_files: $local_files does not exist."
  fi

  # Test if files directory is inside of the parent of the config dir
  parent=$(dirname "$config_dir")
  if [[ "$local_files" != "$parent/"* ]]; then
    configtest_return=false
    warning 'Your local files directory is outside of your configuration root.'
  fi
  # Test if db directory is inside of the parent of the config dir
  if [[ "$local_db_dir" != "$parent/"* ]]; then
    configtest_return=false
    warning 'Your local db directory is outside of your configuration root.'
  fi


  if [ "$production_server" ] && ! ssh $production_server$production_ssh_port "test -e $production_db_dir"; then
    configtest_return=false
    warning "Production db dir doesn't exist: $production_db_dir"
  fi

  if [ "$staging_server" ] && ! ssh $staging_server "test -e $staging_db_dir"; then
    configtest_return=false
    warning "Staging db dir doesn't exist: $staging_db_dir"
  fi

  # Test for a production root in dev environments
  if [ "$production_server" ] && [ "$local_role" == 'dev' ] && [ ! "$production_root" ]; then
    configtest_return=false;
    warning "production_root: Please define the production environment's root directory "
  fi

  # Connection test for prod
  if [ "$production_server" ] && ! ssh -q $production_server$production_ssh_port exit; then
    configtest_return=false
    warning "Can't connect to production server."
  fi

  # Connection test for staging
  if [ "$staging_server" ] && ! ssh -q $staging_server exit; then
    configtest_return=false
    warning "Can't connect to staging server."
  fi

  # Test for a staging root in dev environments
  if [ "$staging_server" ] && [ "$local_role" == 'dev' ] && [ ! "$staging_root" ]; then
    configtest_return=false;
    warning "staging_root: Please define the staging environment's root directory"
  fi

  # Connection test to production/config test for production
  if [ "$production_root" ] && ! ssh $production_server$production_ssh_port "[ -f '${production_root}/.loft_deploy/config' ]"; then
    configtest_return=false
    warning "production_root: ${production_root}/.loft_deploy/config does not exist"
  fi

  # Connection test to staging/config test for staging
  if [ "$staging_root" ] && ! ssh $staging_server "[ -f '${staging_root}/.loft_deploy/config' ]"; then
    configtest_return=false
    warning "staging_root: ${staging_root}/.loft_deploy/config does not exist"
  fi

  # Connection test to staging script test for staging
  if [ "$staging_root" ] && ! ssh $staging_server "[ -f '${staging_script}' ]"; then
    configtest_return=false
    warning "staging_script: ${staging_script} not found. Make sure you're not using ~ in the path."
  fi

  # Test drupal settings file
  if [ "$local_drupal_settings" ]  && ! test -e "$local_drupal_settings"; then
    configtest_return=false
    warning "Drupal: Settings file cannot be found at $local_drupal_settings"
  fi

  # Test drupal settings has drupal_root
  if [ "$local_drupal_settings" ]  && ! [ "$local_drupal_root" ]; then
    configtest_return=false
    warning "Missing config variable: \$local_drupal_root"
  fi

  # Check for 127.0.0.1 and port usage on local
  if [[ "$local_db_port" ]]  && [[ "$local_db_host" == 'localhost' ]]; then
      warning 'When using $local_db_port, you should not set $local_db_host to "localhost", rather an IP.  See https://serverfault.com/questions/306421/why-does-the-mysql-command-line-tool-ignore-the-port-parameter'
  fi

  # Check for 127.0.0.1 and port usage on prod
  if [[ "$production_db_port" ]]  && [[ "$production_remote_db_host" == 'localhost' ]]; then
      warning 'When using $production_db_port, you should not set $production_remote_db_host to "localhost", rather an IP. See https://serverfault.com/questions/306421/why-does-the-mysql-command-line-tool-ignore-the-port-parameter'
  fi

  # Test for db access
  mysql_check_result=false
  mysql_check "$local_db_user" "$local_db_pass" "$local_db_name" "$local_db_host" "$local_db_port"
  if [ $mysql_check_result == false ]; then
    configtest_return=false;
    warning "Can't connect to local DB; check credentials"
  fi

  # @todo test for ssh connection to prod
  # @todo test for ssh connection to staging

  # @todo test local and remote paths match
  if [ "$configtest_return" == true ]; then
    echo "`tty -s && tput setaf $color_green`All tests passed.`tty -s && tput op`"
  else
    echo "`tty -s && tput setaf $color_red`Some tests failed.`tty -s && tput op`"
  fi

}

##
 # Show the password information
 #
 # @param string $1
 #   description of param
 #
 # @return NULL
 #   Sets the value of global $func_name_return
 #
function show_pass() {
  if has_param all || has_param prod || [ ${#params[@]} -eq 0 ]; then
    complete "Production Password: `tty -s && tput setaf 2`$production_pass`tty -s && tput op`"
  fi
  if has_param all || has_param staging; then
    complete "Staging Password: `tty -s && tput setaf 2`$staging_pass`tty -s && tput op`"
  fi
}

#
# Return a specific variable value
#
# Does not work on passwords
#
# @param string $name
#
function get_var() {
  eval "answer=${!1}"
  if [ "$answer" ]; then
    echo "$answer"
  else
    # Necessary to print something or the argument placeholder gets screwed up.  see load_production_config()
    echo "null"
  fi
}

##
 # Display configuation info
 #
function show_info() {
  clear
  print_header

  #echo "Configuration..."
  theme_header 'LOCAL' $color_local
  echo "Role          : $local_role " | tr "[:lower:]" "[:upper:]"
  echo "Config        : $config_dir"
  if [ "$local_drupal_settings" ]; then
    echo "DRUPAL_ROOT   : $local_drupal_root"
    echo "Drupal        : $local_drupal_settings"
  fi
  echo "DB Host       : $local_db_host"
  echo "DB Name       : $local_db_name"
  echo "DB User       : $local_db_user"
  if [ "$local_db_port" ]; then
    echo "DB Port       : $local_db_port"
  fi
  echo "Dumps         : $local_db_dir"
  echo "Files         : $local_files"
  if _access_check 'fetch_db'; then
    if [[ -f "$config_dir/cached_db" ]]; then
      echo "DB Fetched    : "$(cat $config_dir/cached_db)
    fi
  fi
  if _access_check 'fetch_files'; then
    if [[ "$ld_rsync_ex" ]]; then
      echo "`tty -s && tput setaf 3`Files listed in $ld_rsync_exclude_file are being ignored.`tty -s && tput op`"
    fi
    if [[ -f "$config_dir/prod/cached_files" ]]; then
      echo "Files Prod    : "$(cat $config_dir/prod/cached_files)
    fi
    if [[ -f "$config_dir/staging/cached_files" ]]; then
      echo "Files Staging : "$(cat $config_dir/staging/cached_files)
    fi
  fi
  echo

  if [ "$local_role" == 'dev' ]; then
    echo "Loading remote configurations..."
    load_staging_config
    load_production_config
    theme_header 'PRODUCTION' $color_prod
    echo "Server        : $production_server"
    if [ $production_port ]; then
      echo "Port          : $production_port"
    fi
    echo "DB Host       : $production_db_host"
    echo "DB Name       : $production_db_name"
    echo "Dumps         : $production_db_dir"
    echo "Files         : $production_files"
    echo
    theme_header 'STAGING' $color_staging
    echo "Server        : $staging_server"
    if [ $staging_port ]; then
      echo "Port          : $staging_port"
    fi
    echo "DB Host       : $staging_db_host"
    echo "DB Name       : $staging_db_name"
    echo "Dumps         : $staging_db_dir"
    echo "Files         : $staging_files"
    echo
  fi

  # version_result='?'
  # version
  theme_header 'LOFT_DEPLOY'
  echo "Version       : $ld_version"
}

function warning() {
  echo
  #echo "!!!!!!WARNING!!!!!!"
  echo "`tty -s && tput setaf 3`$1`tty -s && tput op`"
  if [ "$2" ]; then
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
  echo "`tty -s && tput setaf 2`$1`tty -s && tput op`"
  echo
}

function handle_pre_hook() {
    _handle_hook $1 pre
}

function handle_post_hook() {
    _handle_hook $1 post
}

function _handle_hook() {
  local hook="$config_dir/hooks/${1}_${2}.sh"
  local name=$(basename $hook)
  declare -a hook_args=("$1" "$production_server" "$staging_server" "" "" "" "" "" "" "" "" "" "$config_dir/hooks/");

  test -e "$hook" && echo "`tty -s && tput setaf 2`Calling ${2}-hook: $name`tty -s && tput op`" && source "$hook" "${hook_args[@]}"
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
 # Checks access (optionally for $1)
 #
 # @param string $1
 #   An op to test for against current config
 #
function _access_check() {

  # List out helper commands, with universal access regardless of local_role
  if [ "$1" == '' ] || [ "$1" == 'help' ] || [ "$1" == 'info' ] || [ "$1" == 'configtest' ] || [ "$1" == 'ls' ] || [ "$1" == 'init' ] || [ "$1" == 'update' ] || [ "$1" == 'mysql' ] || [ "$1" == 'hook' ]; then
    return 0
  fi

  # For each role, list the ops they MAY execute
  if [ "$local_role" == 'prod' ]; then
    case $1 in
      'get')
        return 0
        ;;
      'export')
        return 0
        ;;
    esac
  elif [ "$local_role" == 'staging' ]; then
    case $1 in
      'get')
        return 0
        ;;
      'export')
        return 0
        ;;
      'import')
        return 0
        ;;
      'pass')
        return 0
        ;;
    esac
  elif [ "$local_role" == 'dev' ]; then
    return 0
  fi

  return 1
}



##
 # Do the directory listing
 #
function do_ls() {
  complete "`tty -s && tput setaf $color_green`$1`tty -s && tput op`"
  declare -a ls_flags=()
  for flag in "${flags[@]}"
  do
    if [ $flag != 'd' ] && [ $flag != 'f' ]
    then
      ls_flags=("${ls_flags[@]}" "$flag")
    fi
  done
  ls -$ls_flags $1
  complete
}

##
 # End Functions
 #

##
 # Begin Controller
 #

# init has to come before configuration loading
if [ "$op" == 'init' ]; then
  if _access_check $op; then
    init $2
  else
    echo "`tty -s && tput setaf 1`ACCESS DENIED!`tty -s && tput op`"
    end "$local_role sites may not invoke: loft_deploy $op"
  fi
fi

load_config

if [ "$op" == 'update' ]; then
  if _access_check $op; then
    update $2
  else
    echo "`tty -s && tput setaf 1`ACCESS DENIED!`tty -s && tput op`"
    end "$local_role sites may not invoke: loft_deploy $op"
  fi
fi

# Help MUST COME AFTER CONFIG FOR ACCESS CHECKING!!!! DON'T MOVE
if [ ! "$op" ] || [ "$op" == 'help' ]; then
  show_help

  if [ ! "$op" ]; then
    echo "Please call with one or more arguments."
  fi
  end
fi

##
 # Access Check
 #
if ! _access_check $op; then
  echo "`tty -s && tput setaf 1`ACCESS DENIED!`tty -s && tput op`"
  end "$local_role sites may not invoke: loft_deploy $op"
fi

##
 # Call the correct handler
 #

# Determine the server being operated on
source_server='prod'
if [[ "$target" == 'staging' ]]; then
  source_server='staging'
fi

if [ $op == "get" ]; then
  get_var $2
  exit
fi

print_header
update_needed

handle_pre_hook $op

case $op in
  'hook')
    if [ "$2" ]; then
      handle_pre_hook "$2"
      handle_post_hook "$2"
    else
      echo "`tty -s && tput setaf 1`What type of hook? e.g. ldp hook reset`tty -s && tput op`"
    fi
    end
    ;;
  'init')
    init $2
    complete
    handle_post_hook $op
    end
    ;;
  'mysql')
    loft_deploy_mysql "$2"
    handle_post_hook $op
    complete 'Your mysql session has ended.'
    end
    ;;
  'scp')
    complete "scp $production_scp_port$production_server:$production_scp"
    handle_post_hook $op
    end
    ;;
  'ls')
    if has_flag d; then
      do_ls "$local_db_dir"
    fi
    if has_flag f; then
      do_ls "$local_files"
    fi
    handle_post_hook $op
    end
    ;;
  'configtest')
    configtest
    complete
    handle_post_hook $op
    end
    ;;
  'export')
    export_db $2
    complete
    handle_post_hook $op
    end
    ;;
  'pull')
    if has_flag d || [ ${#flags[@]} -eq 0 ]; then
      fetch_db
      reset_db
      echo 'Database fetched and reset'
    fi
    if has_flag f || [ ${#flags[@]} -eq 0 ]; then
      fetch_files
      reset_files
      echo 'Files fetched and reset'
    fi
    handle_post_hook $op
    end
    ;;
  'push')
    if has_flag d || [ ${#flags[@]} -eq 0 ]; then
      push_db
      complete 'Database pushed to staging'
    fi
    if has_flag f || [ ${#flags[@]} -eq 0 ]; then
      push_files
      complete 'Files pushed to staging'
    fi
    handle_post_hook $op
    end
    ;;
  'fetch')
    suffix=''
    if [[ "$source_server" != 'prod' ]]; then
      suffix=" --$source_server"
    fi
    if has_flag d || [ ${#flags[@]} -eq 0 ]; then
      fetch_db
      complete "The database has been fetched; use 'loft_deploy reset -d$suffix' when ready."
    fi
    if has_flag f || [ ${#flags[@]} -eq 0 ]; then
      fetch_files
      complete "Files have been fetched; use 'loft_deploy reset -f$suffix' when ready."
    fi
    handle_post_hook $op
    end
    ;;
  'reset')
    if has_flag d || [ ${#flags[@]} -eq 0 ]; then
      reset_db
      complete 'Local database has been reset with production.'
    fi
    if has_flag f || [ ${#flags[@]} -eq 0 ]; then
      reset_files
      complete 'Local files have been reset with production.'
    fi
    handle_post_hook $op
    end
    ;;
  'import')
    import_db $2
    complete
    handle_post_hook $op
    end
    ;;
  'help')
    show_help
    complete
    handle_post_hook $op
    end
    ;;
  'info')
    show_info
    complete
    handle_post_hook $op
    end
    ;;
  'pass')
    show_pass
    handle_post_hook $op
    end
    ;;
  'terminus')
    cmd="auth:login --machine-token=$terminus_machine_token"
    $ld_terminus $cmd
    end
    ;;
esac

end "loft_deploy $op is an unknown operation."
