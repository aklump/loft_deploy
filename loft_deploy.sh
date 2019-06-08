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

# Define the configuration file relative to this script.
CONFIG="loft_deploy.yml";

# Uncomment this line to enable file logging.
#LOGFILE="loft_deploy.log"

# TODO: Event handlers and other functions go here or source another file.

function on_compile_config() {
    # Make the instance configuration accessible to Cloudy.
    [ -f "$config_dir/config.yml" ] && echo "$config_dir/config.yml"
}

function on_clear_cache() {
    # Convert config from yaml to bash.
    $ld_php "$INCLUDES/config.php" "$config_dir" "$INCLUDES/schema--config.json"
    status=$?
    if [ $status -ne 0 ]; then
        fail_because "YAML config could not be converted." && return 1
    fi
    succeed_because "$(echo_green "config.yml.sh")"
    load_config
    generate_db_cnf && succeed_because "$(echo_green "local.cnf")"
}

# Begin Cloudy Bootstrap
s="${BASH_SOURCE[0]}";while [ -h "$s" ];do dir="$(cd -P "$(dirname "$s")" && pwd)";s="$(readlink "$s")";[[ $s != /* ]] && s="$dir/$s";done;r="$(cd -P "$(dirname "$s")" && pwd)";

INCLUDES="$r/includes"

# Import functions
source "$INCLUDES/functions.sh"
# Holds the directory of the config file and is modified by load_config().
# This has to happen before cloudy bootstrap.  Also _upsearch changes the PWD so
# we have to capture it first as $WDIR and then cd back to it so that other
# variables are calculated correctly inside of Cloudy.
WDIR="$PWD"
config_dir="$WDIR/.loft_deploy"
_upsearch $(basename "$config_dir")
cd "$WDIR"

source "$r/cloudy/cloudy.sh"
# End Cloudy Bootstrap

# Do not move this, it must come after Bootstrap.
function get_version() {
    local version=$(grep "version = " "$ROOT/web_package.info")
    echo ${version/version = / }
}

# Input validation.
validate_input || exit_with_failure "Input validation failed."

# Determine the version of php to use based on:
# 1. The option --php
# 2. ENV var LOFT_DEPLOY_PHP
# 3. the system 'php'
ld_php="/usr/bin/php"
if [[ "$LOFT_DEPLOY_PHP" ]]; then
    ld_php="$LOFT_DEPLOY_PHP"
fi
[[ ! -x "$ld_php" ]] && fail_because "$ld_php is not a path to a valid PHP executable" && exit_with_failure

##
 # Bootstrap
 #
eval $(get_config_as "ld_mysql" "bin.mysql" "/usr/bin/mysql")
eval $(get_config_as "ld_mysqldump" "bin.mysqldump" "/usr/bin/mysqldump")
eval $(get_config_as "ld_gzip" "bin.gzip" "/usr/bin/gzip")
eval $(get_config_as "ld_gunzip" "bin.gunzip" "/usr/bin/gunzip")
eval $(get_config_as "ld_scp" "bin.scp" "/usr/bin/scp")

eval $(get_config "migration.title")
eval $(get_config -a "migration.database")
eval $(get_config_as -a "migration_files" "migration.files.0")
eval $(get_config_as -a "migration_files2" "migration.files.1")
eval $(get_config_as -a "migration_files3" "migration.files.2")
eval $(get_config "local.url")
eval $(get_config "local.location")
eval $(get_config "local.role" "prod")
eval $(get_config "local.basepath")

declare -a SCRIPT_ARGS=()
declare -a flags=()
declare -a params=()
for arg in "$@"; do
  if [[ "$arg" =~ ^--(.*) ]]; then
    params=("${params[@]}" "${BASH_REMATCH[1]}")
  elif [[ "$arg" =~ ^-(.*) ]]; then
    flags=("${flags[@]}" "${BASH_REMATCH[1]}")
  else
    SCRIPT_ARGS=("${SCRIPT_ARGS[@]}" "$arg")
  fi
done
##
 # End Bootstrap
 #


# The user's operation
op=$(get_command)

# The target of the operation
target=${SCRIPT_ARGS[1]}

# Holds the starting directory
start_dir=${PWD}

# holds the full path to the last db export
current_db_dir=''

# holds the filename of the last db export
current_db_filename=''

# holds the result of connect()
mysql_check_result=false

# theme color definitions
color_red=1
color_green=2
color_yellow=3
color_blue=4
color_magenta=5
color_cyan=6
color_white=7

ld_remote_rsync_cmd="rsync -azP"
has_option "v" && ld_remote_rsync_cmd="rsync -azPv"

##
 # Begin Controller
 #

# Input validation.
validate_input || exit_with_failure "Unknown command."
implement_cloudy_basic


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

##
 # Access Check
 #
if ! _access_check $op; then
    exit_with_failure "The \"$op\" command is not allowed for \"$local_role\" role environments."
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
  get_var $2 && exit 0
  exit 1
fi


if [[ "$(get_migration_type)" != "push" ]]; then
    print_header
    auto_update
fi

#
# status will go to false at any time that an operation fails, e.g. hook, or step, etc.
#
status=true
handle_pre_hook $op || status=false

case $op in
  'config')
      [[ "$EDITOR" ]] && $EDITOR "$config_dir/config.yml" && exit_with_cache_clear
      exit_with_failure "You must set environment variable \$EDITOR with a command first, e.g. in ~/.bash_profile, export EDITOR=nano"
    ;;

  'migrate')
    [[ "$status" == true ]] && do_migrate || status=false
    handle_post_hook $op $status || status=false
    [[ "$status" == true ]] && exit_with_success_elapsed "Migration complete"
    exit_with_failure "Migration failed."
    ;;
  'init')
    [[ "$status" == true ]] && init ${SCRIPT_ARGS[1]} || status=false
    handle_post_hook $op $status && exit 0
    exit 1
    ;;

  'configtest')
    [[ "$status" == true ]] && configtest || status=false
    handle_post_hook $op $status || status=false
    [[ "$status" == true ]] && exit_with_success_elapsed 'Test complete.'
    exit_with_failure 'Test complete with failure(s).'
    ;;

  'import')
    [[ "$status" == true ]] && import_db ${SCRIPT_ARGS[1]} || status=false
    handle_post_hook $op $status || status=false
    [[ "$status" == true ]] && exit_with_success_elapsed "Import complete."
    exit_with_failure "Import failed."
    ;;

  'export')
    suffix=${SCRIPT_ARGS[1]}
    has_option "time" && suffix="${suffix}-$(date8601 -c)"
    [[ "$status" == true ]] && export_db ${suffix#-} || status=false
    handle_post_hook $op $status || status=false
    [[ "$status" == true ]] && exit_with_success_elapsed 'Export complete.'
    exit_with_failure 'Export failed.'
    ;;

  'export-purge')
    _current_db_paths

    if [ ! -d "$current_db_dir" ]; then
      fail_because "$current_db_dir is not a directory" && exit_with_failure
    fi

    days=$(get_command_arg "days")
    paths=($(find $current_db_dir/*.sql.gz -mtime +$days))
    paths=("${paths[@]}" $(find $current_db_dir/*.sql -mtime +$days))
    echo_heading "Purge Export Files"
    table_clear
    table_add_row "Directory" "$current_db_dir"
    table_add_row "Age in Days" "$days"
    table_add_row "Total Found" "${#paths[@]}"
    echo_table

    list_clear
    for path in "${paths[@]}"; do
      if has_option "dry-run"; then
        list_add_item "$(basename $path)"
      else
        if has_option "yes" || confirm "$LI $(basename $path) $(echo_red "Delete?")"; then
          if rm "$path"; then
            succeed_because "$(basename $path) deleted."
          else
            fail_because "Could not delete $path"
          fi
        else
          echo_yellow_highlight "Skipped."
        fi
      fi
    done

    if has_option "dry-run"; then
      echo_list
    fi

    has_failed && exit_with_failure
    exit_with_success
    ;;

  'fetch')
    suffix=''
    status=true
    if [[ "$source_server" != 'prod' ]]; then
      suffix=" --$source_server"
    fi
    if [[ "$status" == true ]] && has_asset database; then
      fetch_db || status=false
    fi
    if [[ "$status" == true ]] && has_asset files; then
      fetch_files || status=false
    fi
    handle_post_hook $op $status || status=false
    [[ "$status" == true ]] && complete_elapsed "Fetch complete." && exit 0
    exit_with_failure "Fetch failed."
    ;;

  'reset')
    if [[ "$status" == true ]] && has_asset database; then
        reset_db && echo "Local database has been reset to match $source_server." || status=false
    fi
    if [[ "$status" == true ]] && has_asset files; then
        reset_files && echo "Local files have been reset to match $source_server." || status=false
    fi
    handle_post_hook $op $status || status=false
    [[ "$status" == true ]] && complete_elapsed "Reset complete." && exit 0
    exit_with_failure "Reset failed."
    ;;

  'pull')
    [[ "$status" == true ]] && do_pull || status=false
    handle_post_hook $op $status || status=false
    [[ "$status" == true ]] && complete_elapsed "Pull complete." && exit 0
    exit_with_failure "Pull failed."
    ;;

  'push')
    if [[ "$status" == true ]] && has_asset database; then
      push_db || status=false
    fi
    if [[ "$status" == true ]] && has_asset files; then
      push_files || status=false
    fi

    handle_post_hook $op $status || status=false
    [[ "$status" == true ]] && complete_elapsed "Push complete." && exit 0
    exit_with_failure "Push failed."
    ;;

  'hook')
    if [ "${SCRIPT_ARGS[1]}" ]; then
      handle_pre_hook "${SCRIPT_ARGS[1]}" $status || status=false
      handle_post_hook "${SCRIPT_ARGS[1]}" $status || status=false
    else
        echo_red "What type of hook? e.g. ldp hook reset"
    fi
    end
    ;;

  'mysql')
    loft_deploy_mysql "${SCRIPT_ARGS[1]}" || status=false
    handle_post_hook $op || status=false
    complete 'Your mysql session has ended.'
    exit 0
    ;;

  'ls')
    if has_option d; then
      do_ls "$local_db_dir"
    fi
    if has_option f; then
      do_ls "$local_files"
    fi
    handle_post_hook $op
    end
    ;;

  'info')
    show_info || status=false
    handle_post_hook $op $status && complete_elapsed "Info displayed" && exit 0
    exit_with_failure
    ;;

  'terminus')
    cmd="auth:login --machine-token=$terminus_machine_token"

    # Todo need to array_shift and then pass the entire bit to terminus to make
    # this really work correctly.
    if [[ "${SCRIPT_ARGS[1]}" ]]; then
      cmd="${SCRIPT_ARGS[1]}"
    fi
    $ld_terminus $cmd && echo_green "└── $config_dir/vendor/bin/terminus" || exit_with_failure
    end
    ;;

  'config-export')
    echo_heading "Copy and paste the following:"
    echo
    if [[ "$local_role" == "prod" ]]; then
      echo "production:"
    elif [[ "$local_role" == "staging" ]]; then
      echo "staging:"
    fi
    echo "  config: $config_dir"
    echo "  script: $0"
    echo "  user: $(whoami)"
    echo "  host: $(get_public_ip)"
    exit_with_success
    ;;

esac

exit_with_failure "\"$op\" is an unhandled operation."
