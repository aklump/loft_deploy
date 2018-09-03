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
ROOT="$( cd -P "$( dirname "$source" )" && pwd )"
INCLUDES="$ROOT/includes"

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
ld_version=0.14.8

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

# Import functions
source "$INCLUDES/functions.sh"

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
  get_var $2 && exit 0
  exit 1
fi

print_header
update_needed

#
# status will go to false at any time that an operation fails, e.g. hook, or step, etc.
#
status=true
handle_pre_hook $op || status=false

case $op in
  'init')
    [[ "$status" == true ]] && init $2 && handle_post_hook $op && exit 0
    exit 1
    ;;

  'configtest')
    [[ "$status" == true ]] && configtest && handle_post_hook $op && complete 'Test complete.' && exit 0
    did_not_complete 'Test complete with failure(s).' && exit 1
    ;;

  'import')
    [[ "$status" == true ]] && import_db $2 && handle_post_hook $op && complete "Import complete." && exit 0
    did_not_complete "Import failed." && exit 1
    ;;

  'export')
    [[ "$status" == true ]] && export_db $2 && handle_post_hook $op && complete 'Export complete.' && exit 0
    did_not_complete 'Export failed.' && exit 1
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
    [[ "$status" == true ]] && handle_post_hook $op && complete "Fetch complete." && exit 0
    did_not_complete "Fetch failed." && exit 1
    ;;

  'reset')
    if [[ "$status" == true ]] && has_asset database; then
        reset_db && echo "Local database has been reset to match $source_server." || status=false
    fi
    if [[ "$status" == true ]] && has_asset files; then
        reset_files && echo "Local files has been reset to match $source_server." || status=false
    fi
    [[ "$status" == true ]] && handle_post_hook $op && complete "Reset complete." && exit 0
    did_not_complete "Reset failed." && exit 1
    ;;

  'pull')
    if [[ "$status" == true ]]; then handle_pre_hook fetch || status=false; fi
    if [[ "$status" == true ]] && has_asset database; then fetch_db || status=false; fi
    if [[ "$status" == true ]] && has_asset files; then fetch_files || status=false; fi
    if [[ "$status" == true ]]; then handle_post_hook fetch || status=false; fi
    if [[ "$status" == true ]]; then handle_pre_hook reset || status=false; fi
    if [[ "$status" == true ]] && has_asset database; then reset_db || status=false; fi
    if [[ "$status" == true ]] && has_asset files ; then reset_files || status=false; fi
    if [[ "$status" == true ]]; then handle_post_hook reset || status=false; fi

    [[ "$status" == true ]] && handle_post_hook $op && complete "Pull complete." && exit 0
    did_not_complete "Pull failed." && exit 1
    ;;

  'push')
    if [[ "$status" == true ]] && has_asset database; then
      push_db && echo_green 'Database pushed to staging.' || status=false
    fi
    if [[ "$status" == true ]] && has_asset files; then
      push_files || status=false
    fi
    [[ "$status" == true ]] && handle_post_hook $op && complete "Push complete." && exit 0
    did_not_complete "Push failed." && exit 1
    ;;

  'hook')
    if [ "$2" ]; then
      handle_pre_hook "$2"
      handle_post_hook "$2"
    else
      echo "`tty -s && tput setaf 1`What type of hook? e.g. ldp hook reset`tty -s && tput op`"
    fi
    end
    ;;

  'mysql')
    loft_deploy_mysql "$2"
    handle_post_hook $op
    complete 'Your mysql session has ended.'
    exit 0
    ;;

  'scp')
    echo_green "scp $production_scp_port$production_server:$production_scp"
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

  'help')
    show_help
    handle_post_hook $op
    end
    ;;

  'info')
    show_info
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

  'clearcache')
    do_clearcache && complete "Caches cleared." && end
    did_not_complete "Caches failed to clear." && end
    ;;

esac

did_not_complete "\"$op\" is an unknown operation; please try something else."
exit 1
