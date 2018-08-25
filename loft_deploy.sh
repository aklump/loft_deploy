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
INCLUDES="$root/includes"

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
ld_version=0.13.22

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
  get_var $2
  exit
fi

# Make sure we have a cnf file for the db creds.
source "$INCLUDES/cnf.sh"

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
