#!/usr/bin/env bash

##
# @file
# Function Declarations
#

##
# Return an array of assets being operated on by the current operation.
#
# This is based on the flags used and will set $operation_assets to contain
# 'files', 'database' or both (if no flags are used by the user)
#
declare -a operation_assets=()
function refresh_operation_assets() {
  operation_assets=()
  local flag_count=${#flags[@]}
  (has_option f || (! has_option f && ! has_option d)) && operation_assets=("${operation_assets[@]}" "files")
  (has_option d || (! has_option f && ! has_option d)) && operation_assets=("${operation_assets[@]}" "database")
}

##
# Determine if the current operation contains an asset
#
# @param string $1
#   One of files, database
#
function has_asset() {
  refresh_operation_assets
  for i in "${operation_assets[@]}"; do
    [[ "$i" == "$1" ]] && return 0
  done
  return 1
}

function loft_deploy_mysql() {
  #@todo When we switch to lobster we need to add taking arguments for prod and staging.
  if has_option 'prod'; then
    _mysql_production
  elif has_option 'staging'; then
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
  cmd="$ld_mysql --defaults-file=$local_db_cnf $local_db_name"
  if [ "$1" ]; then
    echo "$1"
    cmd="$cmd --execute=\"$1\""
  fi
  eval $cmd
}

function auto_update() {
  local need=0
  # Test for _update_0_7_0
  if [[ ! -d "$config_dir/prod" ]]; then
    _update_0_7_0
  fi

  # Test for _update_0_7_6
  if [[ -d "$config_dir/production" ]]; then
    _update_0_7_6
  fi
}

##
# Perform any necessary update functions
#
function update() {
  _update_0_7_6
  _update_0_7_0
  complete 'Updates complete.' && end
  exit_with_failure 'Updates failed'
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
      mv "$config_dir/cached_db" "$config_dir/prod/cached_db.txt"
    fi

    if [[ -f "$config_dir/cached_files" ]]; then
      mv "$config_dir/cached_files" "$config_dir/prod/cached_files.txt.txt"
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
      rm -rf "$config_dir/production"
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
    mkdir $config_dir && rsync -a "$ROOT/init/base/" "$config_dir/" --exclude=.gitkeep
    chmod 0644 "$config_dir/.htaccess"
    cp "$ROOT/init/config/$1.yml" "$config_dir/config.yml"
    cd "$start_dir"
    complete "Initialization almost done; please configure and save $config_dir/config.yml.  Then run: clearcache"
    end
  else
    end "Invalid argument: $1"
  fi
}

function handle_sql_files() {

  local sql_dir="$config_dir/sql"

  # We have to clean this on out because it determines how the mysql
  # is processed in the export function.
  local file=$(get_filename_db_tables_data)
  test -f "$file" && rm $file

  test -e "$sql_dir" || return

  local processed_dir="$config_dir/cache"
  test -d "$processed_dir" || mkdir -p "$processed_dir"

  # Copy over text files direct
  for file in $(find $sql_dir -type f -iname "*.txt"); do
    local name=$(basename "$file")
    cp "$file" "$processed_dir/$name"
  done

  # First compile sql files' dynamic variables
  for file in $(find $sql_dir -type f -iname "*.sql"); do
    local sql=$(cat $file)

    sql=$(echo $sql | sed -e "s/\$local_db_name/$local_db_name/g")
    # sql=$(echo $sql | sed -e "s/\$local_db_user/$local_db_user/g")
    # sql=$(echo $sql | sed -e "s/\$local_db_pass/$local_db_pass/g")
    # sql=$(echo $sql | sed -e "s/\$local_role/$local_role/g")

    name=$(basename "$file")
    echo $sql >"$processed_dir/$name"
  done

  # Now execute the sql files
  for file in $(find $processed_dir -type f -iname "*.sql"); do
    local cmd=$(cat $file)
    local outfile=${file%.*}.txt
    $ld_mysql --defaults-file=$local_db_cnf $local_db_name -s -N -e "$cmd" >"$outfile"
    rm $file
  done

  # Create the inversion of the no_data list as this is what we'll need
  local no_data="$processed_dir/db_tables_no_data.txt"
  if [[ -f "$no_data" ]]; then
    local i=0
    while read line; do
      tables[i]=$line
      i=$(($i + 1))
    done <$no_data
    local tables=$(printf ",\'%s\'" "${tables[@]}")
    tables=${tables:1}
    cmd="SELECT table_name FROM information_schema.tables WHERE table_schema = '$local_db_name' AND table_name NOT IN ($tables)"
    outfile=$(get_filename_db_tables_data)
    $ld_mysql --defaults-file=$local_db_cnf $local_db_name -s -N -e "$cmd" >"$outfile"
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
  done <$no_data
  # tables=$(printf " %s" "${tables[@]}")
  # tables=${tables:1}
  echo ${tables[@]}
}

##
# Load the configuration file
#
function load_config() {
  if ! _upsearch $(basename $config_dir); then
    fail_because "Please create .loft_deploy or make sure you are in a child directory."
    exit_with_failure "No configuration file found"
  fi

  motd=''
  if [[ -f "$config_dir/motd" ]]; then
    motd=$(cat "$config_dir/motd")
  fi

  # Do we have a files exclude for rsync
  if [[ -f "$config_dir/files_exclude.txt" ]]; then
    ld_rsync_exclude_file="$config_dir/files_exclude.txt"
    ld_rsync_ex="--exclude-from=$ld_rsync_exclude_file"
  fi
  if [[ -f "$config_dir/files2_exclude.txt" ]]; then
    ld_rsync_exclude_file2="$config_dir/files2_exclude.txt"
    ld_rsync_ex2="--exclude-from=$ld_rsync_exclude_file2"
  fi
  if [[ -f "$config_dir/files3_exclude.txt" ]]; then
    ld_rsync_exclude_file3="$config_dir/files3_exclude.txt"
    ld_rsync_ex3="--exclude-from=$ld_rsync_exclude_file3"
  fi

  # these are defaults
  local_db_host='localhost'
  production_root=''

  # For Pantheon support we need to find terminus.
  ld_terminus="$config_dir/vendor/bin/terminus"

  # Legacy Support.
  test -f "$config_dir/config" && source $config_dir/config

  local_db_cnf="$config_dir/cache/local.cnf"

  # As of v 0.14 we have yaml support, which is the defacto.
  local mod_cached_path="$config_dir/cache/config.yml.modified.txt"
  [ -f "$mod_cached_path" ] || touch "$mod_cached_path"
  local last_modified_cached=$(cat "$config_dir/cache/config.yml.modified.txt")
  local last_modified=$($ld_php -r "echo filemtime('$config_dir/config.yml');")

  # Test if the yaml file was modified and automatically rebuild config.yml.sh
  if [[ "$last_modified_cached" != "$last_modified" ]]; then
    $ld_php "$INCLUDES/config.php" "$config_dir" "$INCLUDES/schema--config.json" && echo_green "Changes detected in config.yml." || return 1
    rm -f "$local_db_cnf"
    echo "$last_modified" >"$mod_cached_path"
  fi

  test -f "$config_dir/cache/config.yml.sh" && source "$config_dir/cache/config.yml.sh"

  # Handle reading the drupal settings file if asked
  if [ "$local_drupal_settings" ]; then
    read -r -a settings <<<$(php "$ROOT/includes/drupal_settings.php" "$local_drupal_root" "$local_drupal_settings" "$local_drupal_db")
    local_db_host=${settings[0]}
    local_db_name=${settings[1]}
    local_db_user=${settings[2]}
    local_db_pass=${settings[3]}
    local_db_port=${settings[4]}
  fi

  # Define and ensure the mysql credentials.
  test -f $local_db_cnf || generate_db_cnf

  if [[ ! $production_scp ]]; then
    production_scp=$production_root
  fi

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
  echo_heading "Checking production config..."
  if [ "$production_server" ] && [ "$production_script" ]; then
    production=($(ssh $production_server$production_ssh_port "cd $production_root && $production_script get local_db_host; $production_script get local_db_name; $production_script get local_db_user; $production_script get local_db_pass; $production_script get local_db_dir; $production_script get local_files; $production_script get local_files2; $production_script get local_files3; $production_script get local_db_port; $production_script get local_copy_source;"))
    production_db_host="${production[0]}"
    production_db_name="${production[1]}"
    production_db_user="${production[2]}"
    production_db_pass="${production[3]}"
    production_db_dir="${production[4]}"
    production_files="${production[5]}"
    production_files2="${production[6]}"
    production_files3="${production[7]}"
    production_db_port="${production[8]}"
    production_copy_source="${production[9]}"
  elif [ "$pantheon_live_uuid" ]; then
    production_server="live.${pantheon_live_uuid}@appserver.live.${pantheon_live_uuid}.drush.in"
    production_port=2222
    production_remote_db_host="dbserver.live.$pantheon_live_uuid.drush.in"
    production_db_host="Pantheon via Terminus"
    production_db_name="$terminus_site"
  fi
}

##
# Logs in to staging for dynamic variables
#
function load_staging_config() {
  echo_heading "Checking staging config..."
  if [ "$staging_server" ] && [ "$staging_script" ]; then
    staging=($(ssh $staging_server$staging_ssh_port "cd $staging_root && $staging_script get local_db_host; $staging_script get local_db_name; $staging_script get local_db_user; $staging_script get local_db_pass; $staging_script get local_db_dir; $staging_script get local_files; $staging_script get local_files2; $staging_script get local_files3; $staging_script get local_db_port; $staging_script get local_copy_source;"))
    staging_db_host="${staging[0]}"
    staging_db_name="${staging[1]}"
    staging_db_user="${staging[2]}"
    staging_db_pass="${staging[3]}"
    staging_db_dir="${staging[4]}"
    staging_files="${staging[5]}"
    staging_files2="${staging[6]}"
    staging_files3="${staging[7]}"
    staging_db_port="${staging[8]}"
    staging_copy_source="${staging[9]}"
  fi
}

##
# Recursive search for file in parent dirs
#
function _upsearch() {
  test / == "$PWD" && return 1
  test -e "$1" && config_dir=${PWD}/.loft_deploy && return 0 || cd .. && _upsearch "$1"
}

function get_migration_type() {
  local command=$(get_command)
  [[ "$command" != "migrate" ]] && return 0
  [[ "$migration_title" ]] || return 0
  eval $(get_config_as "host" "migration.push_to.host")
  eval $(get_config_as "user" "migration.push_to.user")
  if [[ "$host" ]] || [[ "$user" ]]; then
    echo "push"
  else
    echo "pull"
  fi
  return 0
}

function do_migrate() {
  if [[ "$(get_migration_type)" == "push" ]]; then
    _do_migrate_push
    exit
  elif [[ "$(get_migration_type)" == "pull" ]]; then
    _do_migrate_pull
    return $?
  fi
  fail_because "A migration resource has not been configured in $config_dir/config.yml." && return 1
}

##
# Echo the instructions for a remote push migration.
# This will also exit the app.
#
function _do_migrate_push() {
  eval $(get_config_as "host" "migration.push_to.host")
  eval $(get_config_as "user" "migration.push_to.user")

  local destination=$(url_host $local_url)
  local migrate_files=false
  (! has_option "files" && ! has_option "database" || has_option "files") && migrate_files=true
  local migrate_db=false
  (! has_option "files" && ! has_option "database" || has_option "database") && migrate_db=true

  echo "# Manual Push Migration Instructions"
  echo "## $migration_title ---> $destination"
  echo
  echo "1. SSH into the SOURCE server, _${migration_title}_."

  if [[ "$migrate_db" == true ]]; then
    echo "1. Push your database dump to destination server:"
    echo

    filepath=$(_get_path_with_user_and_host $user $host ${config_dir}/migrate/db/$(basename $migration_database_path))
    echo "        scp ${migration_database_path} ${filepath} || echo \"Failed to push database.\""
    echo
  fi

  if [[ "$migrate_files" == true ]]; then
    echo "1. Push user files to destination server:"
    echo

    if [[ "$local_files" ]]; then
      filepath=$(_get_path_with_user_and_host $user $host $local_files)
      echo "        rsync -azP --delete ${migration_files_path%/}/ ${filepath%/}/ || echo \"Failed to push files.\""
    fi

    if [[ "$local_files2" ]]; then
      filepath=$(_get_path_with_user_and_host $user $host $local_files2)
      echo "        rsync -azP --delete ${migration_files2_path%/}/ ${filepath%/}/ || echo \"Failed to push files2.\""
    fi

    if [[ "$local_files3" ]]; then
      filepath=$(_get_path_with_user_and_host $user $host $local_files3)
      echo "        rsync -azP --delete ${migration_files3_path%/}/ ${filepath%/}/ || echo \"Failed to push files3.\""
    fi

    if [[ "$local_files" ]] || [[ "$local_files" ]] || [[ "$local_files" ]]; then
      echo
    fi
  fi

  if [[ "$migrate_db" == true ]]; then
    echo "1. SSH in to DESTINATION server, _${destination}_."
    echo "1. Import the database dump:"
    echo
    echo "        ldp import ${config_dir}/migrate/db/$(basename $migration_database_path)"
    echo
  fi

  CLOUDY_EXIT_STATUS=0 && _cloudy_exit
}

function _do_migrate_pull() {

  # -p will preserve the times so we can detect how old this database is.
  local db_command="scp -p"
  local migrate_files=false
  (! has_option "files" && ! has_option "database" || has_option "files") && migrate_files=true
  local migrate_db=false
  (! has_option "files" && ! has_option "database" || has_option "database") && migrate_db=true

  local files_command="$ld_remote_rsync_cmd --delete"
  has_option 'q' && db_command="$db_command -q"
  has_option 'q' && files_command="$files_command -q"

  echo_title "Migration from \"$migration_title\""

  local backup_message="Your database will be backed up, but your files will not."
  has_option "nobu" && backup_message=$(echo_red "Nothing will be backed up.")

  confirmation_message="Migration will overwrite your local $(echo_yellow_highlight "files and database")."
  if [[ "$migrate_files" == true ]] && [[ "$migrate_db" == false ]]; then
    confirmation_message="Migration will overwrite your local $(echo_yellow_highlight "files only"); your database will not be touched."
  fi
  if [[ "$migrate_files" == false ]] && [[ "$migrate_db" == true ]]; then
    confirmation_message="Migration will overwrite your local $(echo_yellow_highlight "database only"); files will not be touched."
  fi

  echo "${confirmation_message}"
  if ! confirm "${backup_message}  Do you want to continue?"; then
    fail_because "User cancelled."
    return 1
  fi

  local base="$config_dir/migrate"

  # Database
  if [[ "$migrate_db" == true ]] && [[ "$migration_database_path" ]]; then
    echo_heading "Copying database from $migration_title..."
    [ -d "$base/db" ] || mkdir -p "$base/db"
    rm "$base/db/fetched.sql"* >/dev/null 2>&1

    local from=$(_get_path_with_user_and_host $migration_database_user $migration_database_host $migration_database_path)

    local to="$base/db/fetched.sql"
    if [ $(path_extension "$migration_database_path") == "gz" ]; then
      local to="$base/db/fetched.sql.gz"
    fi

    $db_command $from $to || fail_because "Could not migrate database $(basename $migration_database_path)"

    # Do a test to make sure the db source is not too old.
    local now=$(timestamp)
    local mtime=$(path_mtime $to)
    local age_in_minutes
    local age_in_hours
    local age_in_days
    let "age_in_minutes=($now - $mtime) / 60"
    let "age_in_hours=($now - $mtime) / 3600"
    let "age_in_days=($now - $mtime) / 86400"
    local threshold
    local severity="danger"
    eval $(get_config_as max_db_seconds "migration.max_db_age" 1800)
    let "max_db_minutes=$max_db_seconds / 60"
    if [ $age_in_days -gt 1 ]; then
      threshold="$age_in_days days"
    elif [ $age_in_hours -gt 1 ]; then
      threshold="$age_in_hours hours"
    elif [ $age_in_minutes -gt $max_db_minutes ]; then
      threshold="$age_in_minutes minutes"
      severity="caution"
    fi
    if [[ "$threshold" ]] && ! confirm --$severity "Your migration database source is older than $threshold; do you wish to continue?"; then
      fail_because "Database snapshot was too old; create a newer export of the migration database and try again."
      return 1
    fi

    reset_db --source=migrate -y || fail_because "Could not import the database."

    [ -f $to ] && ! rm $to && fail_because "Could not remove $to"
    [ -f ${to/.gz/ } ] && ! rm ${to/.gz/ } && fail_because "Could not remove $to"

    ! has_failed && echo_green "$LIL db done."
  fi

  # Copy files
  if [[ "$migrate_files" == true ]] && [[ "$migration_files_path" ]]; then
    echo_heading "Copying files..."
    local from=$(_get_path_with_user_and_host $migration_files_user $migration_files_host $migration_files_path)
    local to="$local_files"
    if [[ "$to" ]]; then
      $files_command $from/ $to/ || fail_because "Could not migrate files $(basename $from)"
    else
      fail_because "There is no local path to \"files\"."
    fi
    ! has_failed && echo_green "$LIL files done."
  fi

  # Copy files2
  if [[ "$migrate_files" == true ]] && [[ "$migration_files2_path" ]]; then
    echo_heading "Copying files2..."
    local from=$(_get_path_with_user_and_host $migration_files2_user $migration_files2_host $migration_files2_path)
    local to="$local_files2"
    if [[ "$to" ]]; then
      $files_command $from/ $to/ || fail_because "Could not migrate files2 $(basename $from)"
    else
      fail_because "There is no local path to \"files2\"."
    fi
    ! has_failed && echo_green "$LIL files2 done."
  fi

  # Copy files3
  if [[ "$migrate_files" == true ]] && [[ "$migration_files3_path" ]]; then
    echo_heading "Copying files3..."
    local from=$(_get_path_with_user_and_host $migration_files3_user $migration_files3_host $migration_files3_path)
    local to="$local_files3"
    if [[ "$to" ]]; then
      $files_command $from/ $to/ || fail_because "Could not migrate files2 $(basename $from)"
    else
      fail_because "There is no local path to \"files3\"."
    fi
    ! has_failed && echo_green "$LIL files3 done."
  fi

  has_failed && return 1
  return 0
}

function _get_path_with_user_and_host() {
  local user=$1
  local host=$2
  local path=$3

  echo "$user@$host:$path"
}

##
# Process the pull operation.
#
function do_pull() {
  local status=true
  case "$source_server" in
  'prod')
    load_production_config
    ;;
  'staging')
    load_staging_config
    ;;
  esac

  if [[ "$source_server" == "staging" ]] && [[ ! "$staging_server" ]]; then
    fail_because "You must define a Staging environment before pulling from it." && return 1
  fi
  if [[ "$source_server" == "prod" ]] && [[ ! "$production_server$terminus_site" ]]; then
    fail_because "You must define a Production environment before pulling from it." && return 1
  fi

  if [[ "$status" == true ]]; then handle_pre_hook fetch || status=false; fi
  if [[ "$status" == true ]] && has_asset database; then fetch_db || status=false; fi
  if [[ "$status" == true ]] && has_asset files; then fetch_files || status=false; fi
  if [[ "$status" == true ]]; then handle_post_hook fetch || status=false; fi
  if [[ "$status" == true ]]; then handle_pre_hook reset || status=false; fi
  if [[ "$status" == true ]] && has_asset database; then reset_db || status=false; fi
  if [[ "$status" == true ]] && has_asset files; then reset_files || status=false; fi
  if [[ "$status" == true ]]; then handle_post_hook reset || status=false; fi

  [[ "$status" == true ]] || return 1
  return 0
}

##
# Fetch the remote db and import it to local
#
function fetch_db() {
  case $source_server in
  'prod')
    _fetch_db_production
    ;;
  'staging')
    _fetch_db_staging
    ;;
  esac
}

##
# Fetch the remote db and import it to local
#
function _fetch_db_production() {

  # @todo Add status var here with return value.

  if [[ ! -d "$config_dir/prod/db" ]]; then
    mkdir "$config_dir/prod/db"
  fi

  # Cleanup local
  rm $config_dir/prod/db/fetched.sql* >/dev/null 2>&1

  echo "Exporting production db..."
  local _export_suffix='fetch_db'
  local _local_file="$config_dir/prod/db/fetched.sql.gz"

  # Support for Pantheon.
  if [ "$terminus_site" ]; then
    if [ ! "$ld_terminus" ]; then
      end "Missing dependency terminus; please install per https://github.com/pantheon-systems/terminus/blob/master/README.md#installation"
    fi
    if [ ! "$terminus_machine_token" ]; then
      end "Create or add your terminus machine token as \$terminus_machine_token https://pantheon.io/docs/machine-tokens/"
    fi

    $ld_terminus auth:login --machine-token=$terminus_machine_token --quiet

    if ! has_option y && ! confirm "Creating a backup takes more time, shall we save time and download the lastest dashboard backup?"; then
      echo "Creating new backup using Terminus..."
      $ld_terminus backup:create $terminus_site.live --element=db
    fi
    echo "Downloading latest backup from Pantheon..."
    $ld_terminus backup:get $terminus_site.live --element=db --to="$_local_file"
    $ld_terminus auth:logout

  # Default using SSH and SCP.
  else
    load_production_config
    if [ ! "$production_script" ] || [ ! "$production_db_dir" ] || [ ! "$production_server" ] || [ ! "$production_db_name" ]; then
      end "Bad production db config"
    fi

    show_switch
    if has_option v; then
      ssh $production_server$production_ssh_port "cd $production_root && . $production_script export $_export_suffix"
    else
      ssh $production_server$production_ssh_port "cd $production_root && . $production_script export $_export_suffix" >/dev/null
    fi
    wait
    [[ $? -eq 0 ]] && echo_green "├── Database exported and ready to download." || echo_red "Remote export failed."

    local _remote_file="$production_db_dir/${production_db_name}-$_export_suffix.sql.gz"
    if has_option v; then
      scp $production_scp_port"$production_server:$_remote_file" "$_local_file"
    else
      scp $production_scp_port"$production_server:$_remote_file" "$_local_file" >/dev/null
    fi
    [[ $? -eq 0 ]] && echo_green "└── Database downloaded from production." || echo_red "Download failed."

    # delete it from remote
    if has_option v; then
      ssh $production_server$production_ssh_port "rm $_remote_file"
    else
      ssh $production_server$production_ssh_port "rm $_remote_file" >/dev/null
    fi
    show_switch

  fi

  # record the fetch date
  echo "$(date8601)" >$config_dir/prod/cached_db.txt
}

##
# Fetch the staging db and import it to local.
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
  echo "$(date8601)" >$config_dir/staging/cached_db.txt

  # delete it from remote
  echo "Deleting the staging copy..."
  ssh $staging_server "rm $_remote_file"
  show_switch
}

##
# Fetch files from the appropriate server
#
function fetch_files() {
  local status=false
  case $source_server in
  'prod')
    status=true
    load_production_config
    if [ "$local_copy_production_to" ]; then
      _fetch_copy "Production" "$production_server" "$production_copy_source" "$local_copy_production_to" || status=false
    fi
    if ! has_option ind; then
      if [[ "$status" == true ]] && [ "$local_files" ] && [ "$production_files" ]; then
        _fetch_dir 'files/*' "$production_server" "$production_port" "$production_files" "$local_files" "$config_dir/prod/files" "$ld_rsync_exclude_file" "$ld_rsync_ex" || status=false
      fi
      if [[ "$status" == true ]] && [ "$local_files2" ] && [ "$production_files2" ]; then
        _fetch_dir 'files2/*' "$production_server" "$production_port" "$production_files2" "$local_files2" "$config_dir/prod/files2" "$ld_rsync_exclude_file2" "$ld_rsync_ex2" || status=false
      fi
      if [[ "$status" == true ]] && [ "$local_files3" ] && [ "$production_files3" ]; then
        _fetch_dir 'files3/*' "$production_server" "$production_port" "$production_files3" "$local_files3" "$config_dir/prod/files3" "$ld_rsync_exclude_file3" "$ld_rsync_ex3" || status=false
      fi
    fi
    ;;

  'staging')
    status=true
    load_staging_config
    if [ "$local_copy_staging_to" ]; then
      _fetch_copy "Staging" "$staging_server" "$staging_copy_source" "$local_copy_staging_to" || status=false
    fi
    if ! has_option ind; then
      echo_warning "(When fetching files from staging, the --ind flag is assumed.)"
      echo
    fi
    ;;
  esac

  [[ "$status" == true ]] && echo "$(date8601)" >"$config_dir/$source_server/cached_files.txt" && return 0
  return 1
}

##
# Handle the copy of a colon separated list of files from remote server to the config stage.
#
# @param string $1
#   The production file list separated by colons.
# @param string $2
#   The local file list separated by colons.
#
function _fetch_copy() {
  local title=$1
  local server=$2
  oldIFS="$IFS"
  IFS=':'

  echo "Fetching individual files from $source_server to local cache..."

  [[ "$3" == null ]] && return 1
  [[ "$4" == null ]] && return 1
  read -r -a source <<<"$3"
  read -r -a destination <<<"$4"
  IFS="$oldIFS"

  local i=0
  local to=''
  (test ! -d "$config_dir/$source_server/copy" || rm -rf "$config_dir/$source_server/copy") && mkdir -p "$config_dir/$source_server/copy"
  local output=''
  local error=''
  for from in "${source[@]}"; do
    [[ "$output" ]] && echo_green "├── $output"
    [[ "$error" ]] && echo_green "├── $error"
    to=$config_dir/$source_server/copy/$i~${destination[$i]##*/}
    if [[ ! "$to" ]]; then
      error="No local path configured for: ${from##*/}"
      output=''
    else
      local verbose=''
      has_option v && verbose=' -p -v' && echo_yellow "$server:$from $to"
      $($ld_scp $verbose "$server:$from" "$to")
      test -f "$to" && output="${from##*/}"
    fi
    ((++i))
  done
  [[ "$output" ]] && echo_green "└── $output"
  [[ "$error" ]] && echo_red "└── $error failed"
  return 0
}

##
# Helper function to fetch remote files to local.
#
function _fetch_dir() {
  local status=true
  local title="$1"
  local server_remote="$2"
  local port_remote="$3"
  local path_remote="$4"
  local path_local="$5"
  local path_stash="$6"
  local exclude_file="$7"
  local exclude="$8"

  if [ ! "$path_remote" ]; then
    end "\$path_remote cannot be blank, try '.' instead."
  fi
  if [ ! "$path_local" ]; then
    end "\local_files cannot be blank, try '.' instead."
  fi
  if [ "$path_remote" != '.' ] && [ "$path_remote" == "$path_local" ]; then
    end "\$path_remote and \$path_local should not be the same path."
  fi

  echo "Fetching $title directory contents to local cache..."

  # rsync exclude file indication to user....
  if has_option v && test -e "$exclude_file"; then
    excludes="$(cat $exclude_file)"
    echo "$(tty -s && tput setaf 3)Excluding per: $exclude_file$(tty -s && tput op)"
    echo "$(tty -s && tput setaf 3)$exclude_files$(tty -s && tput op)"
  fi

  if [[ "$port_remote" ]]; then
    cmd="$ld_remote_rsync_cmd -e \"ssh -p $port_remote\" \"$server_remote:$path_remote/\" \"$path_stash\" --delete $exclude"
  else
    cmd="$ld_remote_rsync_cmd \"$server_remote:$path_remote/\" \"$path_stash\" --delete $exclude"
  fi

  has_option v && echo $cmd && echo

  eval $cmd >/dev/null 2>&1
  [[ $? -ne 0 ]] && status=false

  [[ $status == 'true' ]] && echo_green "└── complete." && return 0
  echo_red "└── failed to fetch." && return 1
}

##
# Reset the local files with fetched prod files
#
function reset_files() {
  local status=true
  if [ "$local_copy_production_to" ] || [ "$local_copy_local_to" ] || [ "$local_copy_staging_to" ] || [ "$local_files" ] || [ "$local_files2" ] || [ "$local_files3" ]; then
    if has_option v; then
      echo "This process will reset your local files to match the most recently fetched"
      echo "$source_server files, removing any local files that are not present in the fetched"
      echo "set. You will be given a preview of what will happen first. To absolutely"
      echo "match $source_server as of this moment in time, consider fetching first, however it is slower."
      echo
      echo "$(tty -s && tput setaf 3)End result: Your local files directory will match fetched $source_server files.$(tty -s && tput op)"
    fi

    if [ "$status" == true ] && [ "$local_copy_local_to" ]; then
      _reset_local_copy "$local_copy_source" "$local_copy_local_to" || status=false
    fi

    if has_option "local"; then
      [[ "$status" == false ]] && return 1
      return 0
    fi

    if [ "$status" == true ] && [ "$source_server" == 'prod' ] && [ "$local_copy_production_to" ]; then
      _reset_copy "$local_copy_production_to" || status=false
    fi

    if [ "$status" == true ] && [ "$source_server" == 'staging' ] && [ "$local_copy_staging_to" ]; then
      _reset_copy "$local_copy_staging_to" || status=false
    fi

    if ! has_option "ind" && [[ "$source_server" == 'prod' ]]; then
      if [ "$status" == true ] && [ "$local_files" ]; then
        _reset_dir "Files" "$config_dir/$source_server/files" "$local_files" "$ld_rsync_exclude_file" "$ld_rsync_ex" || status=false
        if [[ "$status" == true ]]; then
          echo_green "└── done."
        else
          echo_red "└── failed." && status=false
        fi
      fi

      if [ "$status" == true ] && [ "$local_files2" ]; then
        _reset_dir "Files2" "$config_dir/$source_server/files2" "$local_files2" "$ld_rsync_exclude_file2" "$ld_rsync_ex2" || status=false
        if [[ "$status" == true ]]; then
          echo_green "└── done."
        else
          echo_red "└── failed." && status=false
        fi
      fi

      if [ "$status" == true ] && [ "$local_files3" ]; then
        _reset_dir "Files3" "$config_dir/$source_server/files3" "$local_files3" "$ld_rsync_exclude_file3" "$ld_rsync_ex3" || status=false
        if [[ "$status" == true ]]; then
          echo_green "└── done."
        else
          echo_red "└── failed." && status=false
        fi
      fi
    fi
  fi

  [[ "$status" == true ]] && return 0
  return 1
}

##
# Copy files from the staging to the correct local location.
#
# @param string $1
#   The destination file list separated by colons.
#
function _reset_copy() {
  local status=true
  oldIFS="$IFS"
  IFS=':'
  read -r -a destination <<<"$1"
  IFS="$oldIFS"

  local i=0
  local to=''
  local output=''

  has_option 'y' || confirm --caution "Reset $source_server individual files, are you sure?" || return 2

  echo "Resetting individual $source_server files from cache..."
  for from in "${destination[@]}"; do
    [[ "$output" ]] && echo_green "├── $output"
    [[ "$error" ]] && echo_red "├── $error"
    from="$config_dir/$source_server/copy/"$i~${from##*/}
    to=${destination[$i]}
    local verbose=''
    has_option v && verbose=' -v'
    local to_dir=$(dirname $to)

    # Create the parent directories of the destination if necessary
    test -d "$to_dir" || mkdir -p "$to_dir"

    cp -f -p$verbose "$from" "$to" || status=false
    if [[ "$status" == true ]]; then
      output=${to[@]##*/}
    else
      error=${to[@]##*/}
    fi
    ((++i))
  done
  [[ "$output" ]] && echo_green "└── $output"
  [[ "$error" ]] && echo_red "└── $error"

  [[ "$status" == true ]] && return 0
  return 1
}

##
# Copy local from point a to point b
#
# @param string $1
#   The source file list separated by colons.
# @param string $1
#   The destination file list separated by colons.
#
function _reset_local_copy() {
  local status=true
  oldIFS="$IFS"
  IFS=':'
  read -r -a source <<<"$1"
  read -r -a destination <<<"$2"
  IFS="$oldIFS"

  local i=0
  local to=''
  local output=''

  has_option 'y' || confirm --danger "Overwrite local individual files, are you sure?" || return 2

  echo "Copying individual local files..."
  for from in "${source[@]}"; do
    [[ "$output" ]] && echo_green "├── $output"
    [[ "$error" ]] && echo_red "├── $error"
    to=${destination[$i]}
    local verbose=''
    has_option v && verbose=' -v'
    local to_dir=$(dirname $to)

    # Create the parent directories of the destination if necessary
    test -d "$to_dir" || mkdir -p "$to_dir"

    cp -f -p$verbose "$from" "$to" || status=false
    if [[ "$status" == true ]]; then
      output=${to[@]##*/}
    else
      error=${to[@]##*/}
    fi
    ((++i))
  done
  [[ "$output" ]] && echo_green "└── $output"
  [[ "$error" ]] && echo_red "└── $error"

  [[ "$status" == true ]] && return 0
  return 1
}

##
# Helper function to reset a single files directory.
#
function _reset_dir() {
  local title="$1"
  local path_stash="$2"
  local path_local="$3"
  local exclude_file="$4"
  local exclude="$5"

  if [ ! -d $path_stash ]; then
    echo_red "Please fetch files first." && return 1
  fi

  echo "Reset cached $source_server file directory: $title..."

  # rsync exclude file indication to user....
  if has_option v && test -e "$exclude_file"; then
    excludes="$(cat $exclude_file)"
    echo "$(tty -s && tput setaf 3)Excluding per: $exclude_file$(tty -s && tput op)"
    echo "$(tty -s && tput setaf 3)$excludes$(tty -s && tput op)"
    echo
    echo "$(tty -s && tput setaf 2)Here is a preview:$(tty -s && tput op)"
    cmd="rsync -av $path_stash/ $path_local/ --delete $exclude"
    eval "$cmd --dry-run"
  else
    cmd="rsync -a $path_stash/ $path_local/ --delete $exclude"
  fi

  # Have to exclude here because there might be some lingering files in the cache
  # say, if the exclude file was edited after an earlier sync. 2015-10-20T12:41, aklump
  has_option 'y' || confirm --danger "Overwrite local \"$title\" with $source_server, are you sure?" || return 2

  has_option v && echo $cmd && echo
  eval $cmd

  return $?
}

##
# Reset the local database with a previously fetched copy
#
function reset_db() {
  parse_args "$@"

  local source=$source_server
  [[ "$parse_args__options__source" ]] && source=$parse_args__options__source

  if has_option v; then
    echo "This process will reset your local db to match the most recently fetched"
    echo "$source db, first backing up your local db. To absolutely match $source,"
    echo "consider fetching the database first, however it is slower."
    echo
    echo "$(tty -s && tput setaf 3)End result: Your local database will match the $source database.$(tty -s && tput op)"
  fi
  [[ "$parse_args__options__y" ]] || has_option 'y' || confirm "Are you sure you want to $(tty -s && tput setaf 3)OVERWRITE YOUR LOCAL DB$(tty -s && tput op) with the $source db" || return 2

  local fetched_db_dump=($(find $config_dir/$source/db -name fetched.sql*))

  if [[ ${#fetched_db_dump[@]} -gt 1 ]]; then
    end "More than one fetched.sql file found; please remove the incorrect version(s) from $config_dir/$source/db"
  elif [[ ${#fetched_db_dump[@]} -eq 0 ]]; then
    end "Expecting to find $config_dir/$source/db/fetched.sql or fetched.sql.gz; file not found."
  fi

  has_option nobu || export_db "reset_backup-$(date8601 -c)" '' 'Creating a backup of the local db...'

  import_db_silent=true
  import_db "$fetched_db_dump"
}

##
# Push local files to staging
#
function push_files() {
  local status=true
  load_staging_config
  if [[ "$staging_files" ]] || [[ "$staging_files2" ]] || [[ "$staging_files3" ]]; then
    if [ ! "$staging_files" ]; then
      echo_red "You cannot push your files unless you define a staging environment" && return 1
    fi

    if has_option v; then
      echo "This process will push your local files to your staging server, removing any"
      echo "files on staging that are not present on local. You will be given"
      echo "a preview of what will happen first."
      echo
      echo "$(tty -s && tput setaf 3)End result: Your staging files directory will match your local.$(tty -s && tput op)"
    fi

    # Todo staging_copy_dev_to?

    if [[ "$status" == true ]] && [[ "$local_files" ]]; then
      _push_dir 'files/*' "$staging_server" "$staging_port" "$staging_files" "$local_files" "$ld_rsync_exclude_file" "$ld_rsync_ex" || status=false
    fi

    if [[ "$status" == true ]] && [[ "$local_files2" ]]; then
      _push_dir 'files2/*' "$staging_server" "$staging_port" "$staging_files2" "$local_files2" "$ld_rsync_exclude_file2" "$ld_rsync_ex2" || status=false
    fi

    if [[ "$status" == true ]] && [[ "$local_files3" ]]; then
      _push_dir 'files3/*' "$staging_server" "$staging_port" "$staging_files3" "$local_files3" "$ld_rsync_exclude_file3" "$ld_rsync_ex3" || status=false
    fi
  fi

  [[ "$status" == true ]] && return 0
  return 1
}

##
# Push a single directory from local to staging.
#
function _push_dir() {
  local status=true
  local title="$1"
  local server_remote="$2"
  local port_remote="$3"
  local path_remote="$4"
  local path_local="$5"
  local exclude_file="$6"
  local exclude="$7"

  if [ ! "$path_remote" ]; then
    echo_red "\$path_remote cannot be blank, try '.' instead." && return 1
  fi
  if [ ! "$path_local" ]; then
    echo_red "\local_files cannot be blank, try '.' instead." && return 1
  fi
  if [ "$path_remote" != '.' ] && [ "$path_remote" == "$path_local" ]; then
    echo_red "\$path_remote and \$path_local should not be the same path." && return 1
  fi

  # rsync exclude file indication to user....
  if has_option v && test -e "$exclude_file"; then
    excludes="$(cat $exclude_file)"
    echo "$(tty -s && tput setaf 3)Excluding per: $exclude_file$(tty -s && tput op)"
    echo "$(tty -s && tput setaf 3)$exclude_files$(tty -s && tput op)"
  fi

  if [[ "$port_remote" ]]; then
    cmd="$ld_remote_rsync_cmd -e \"ssh -p $port_remote\" \"$path_local/\" \"$server_remote:$path_remote/\" --delete $exclude"
  else
    cmd="$ld_remote_rsync_cmd \"$path_local/\" \"$server_remote:$path_remote/\" --delete $exclude"
  fi

  has_option y || confirm "Bring staging \"$title\" into sync with local, are you sure?" || return 2
  has_option v && echo $cmd && echo

  eval $cmd >/dev/null 2>&1
  [[ $? -ne 0 ]] && status=false

  [[ $status == 'true' ]] && echo_green "└── complete." && return 0
  echo_red "└── failed to push." && return 1
}

##
# Push local db (with optional export) to staging
#
function push_db() {
  local status=true
  load_staging_config
  if [ ! "$staging_db_dir" ] || [ ! "$staging_server" ]; then
    echo_red "You cannot push your database unless you define a staging environment." && return 1
  fi

  if has_option v; then
    echo "This process will push your local database to your staging server, "
    echo "ERASING the staging database and REPLACING it with a copy from local."
    echo
    echo "$(tty -s && tput setaf 3)End result: Your staging database will match your local.$(tty -s && tput op)"
  fi
  has_option y || confirm "Are you sure you want to push your local db to staging" || return 2

  export_db push_db -y || return 1

  echo 'Pushing db to staging...'
  filename="$current_db_filename.gz"
  _remote_file="$staging_db_dir/$filename"
  $ld_scp "$current_db_dir/$filename" "$staging_server:$_remote_file" || return 1

  # Log into staging and import the database.
  show_switch
  ssh $staging_server "cd $staging_root && . $staging_script -y import $staging_db_dir/$filename" || status=false

  # Strip off the gz suffix then delete file from staging.  We pushed the
  # gzipped file, but it was unzipped during import, leaveing a file without
  # the .gz suffix orphaned on the remote server.
  _remote_file=${_remote_file%.*}
  ssh $staging_server "[ ! -e $_remote_file ] || rm $_remote_file" || status=false
  show_switch

  # Delete our local copy
  [ ! -e "$current_db_dir/$filename" ] || rm "$current_db_dir/$filename" || status=false

  [[ "$status" == true ]] && return 0
  return 1
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
  local suffix=''
  if [ "$1" ]; then
    suffix="-$1"
  fi
  current_db_filename="${local_db_name}${suffix}.sql"
}

##
# export the database with optional file suffix
#
# @param string $1
#   Anything to add as a suffix
# @param string $2
#   If this is -f then we will just do it.
# @param string $3
#   A title to use instead of 'Exporting database...'
#
function export_db() {
  _current_db_paths $1

  # Allow modification of the output directory via --dir
  if has_option "dir"; then
    dir="$(get_option dir)"
    [ -d $dir ] || exit_with_failure "The --dir option points to a non-existent directory \"$dir\"."
    current_db_dir="$dir"
  fi
  file="${current_db_dir%/}/$current_db_filename"
  file_gz="$file.gz"

  if [ -f "$file" ] && [ "$2" != '-y' ]; then
    if ! has_option y; then
      confirm --danger "File $file exists, replace" || return 2
      echo
    fi
    rm $file
  fi
  if [ -f "$file_gz" ] && [ "$2" != '-y' ]; then
    if ! has_option y; then
      confirm --danger "File $file_gz exists, replace" || return 2
      echo
    fi
    rm $file_gz
  fi

  if [ ! "$local_db_user" ] || [ ! "$local_db_pass" ] || [ ! "$local_db_name" ]; then
    fail_because "Missing one or more of: local.user, local.password, local.name"
    return 1
  fi
  if [ ! "$local_db_host" ]; then
    local_db_host="localhost"
  fi

  ([[ "$3" ]] && echo_heading $3) || echo_heading "Exporting database..."

  # Do we need to process a db_tables_no_data file?
  handle_sql_files

  # There are two ways of doing this, it will depend if we are to exclude data
  # from some tables or not
  data=$(get_sql_ready_db_tables_data)
  if [[ "$data" ]]; then
    echo_yellow "├── Omitting data from some tables..."
    # Omit table content.
    $ld_mysqldump --defaults-file=$local_db_cnf $local_db_name --no-data >"$file"
    # Omit certain create tables.
    $ld_mysqldump --defaults-file=$local_db_cnf $local_db_name $data --no-create-info >>"$file"
  else
    $ld_mysqldump --defaults-file=$local_db_cnf $local_db_name -r "$file"
  fi
  local status=$?

  if [[ $status -eq 0 ]]; then
    if [ "$2" == '-y' ]; then
      $ld_gzip -f "$file"
    else
      $ld_gzip "$file"
    fi
    status=$?
  fi

  # Keep this as a full path as it's easier to copy and paste for user.
  [[ $status -eq 0 ]] && succeed_because "Saved to: ${file_gz}"

  return $status
}

##
# Import a db export file into local db, overwriting local
#
# @param string $1
#   If this is not a path to a file, it will be assumed a filename in
#   $local_db_dir
#
import_db_silent=false
function import_db() {
  local filename_or_path=$1

  echo_heading "Import New Database"

  if [[ ! "$filename_or_path" ]]; then
    fail_because "Filename of db dump required." || return 1
  fi

  _current_db_paths $filename_or_path
  # Determine all the possible locations.

  declare -a local check=("$WDIR/$(basename $filename_or_path)")
  if [ "$filename_or_path" != "$(basename "$filename_or_path")" ]; then
    check=("$filename_or_path" "${check[@]}")
  fi
  if [ "${WDIR%/}" != "${current_db_dir%/}" ]; then
    check=("${check[@]}" "${current_db_dir}$(basename $filename_or_path)")
  fi
  check=("${check[@]}" "${current_db_dir}${current_db_filename}" "${current_db_dir}${current_db_filename}.gz")

  local filepath=''
  for check_filepath in "${check[@]}"; do
    if [[ ! "$filepath" ]] && [ -f "$check_filepath" ]; then
      filepath="$check_filepath"
    fi
  done

  if [[ ! "$filepath" ]]; then
    fail_because "File not found as one of:"
    for path in ${check[@]}; do
      fail_because "$path"
    done
    return 1
  fi

  echo "Data will be read from: $(dirname $filepath)/$(echo_yellow_highlight $(basename $filepath))"
  echo

  has_option 'y' || [ $import_db_silent = true ] || confirm --danger "You are about to overwrite your entire database. Are you sure?" || return 2
  echo "Importing data into $local_db_host:$local_db_name..."
  _drop_tables || return 1

  if [[ "${filepath##*.}" == 'gz' ]]; then
    $ld_gunzip "$filepath" || return 1
    filepath=${filepath%.*}
  fi
  $ld_mysql --defaults-file=$local_db_cnf $local_db_name <$filepath && echo_green "└── ${filepath##*/} has been imported."
  return $?
}

##
# Drop all local db tables
#
function _drop_tables() {
  local status=true
  tables=$($ld_mysql --defaults-file=$local_db_cnf $local_db_name -e 'show tables' | awk '{ print $1}' | grep -v '^Tables')
  for t in $tables; do
    has_option v && echo "├── $t"
    $ld_mysql --defaults-file=$local_db_cnf $local_db_name -e "DROP TABLE $t" || status=false
  done

  if [[ "$status" == true ]]; then
    echo_green "├── All tables dropped from $local_db_name."
    return 0
  fi

  echo_red "├── Could not drop all tables."
  return 1
}

##
# Echo an operation complete message.
#
# @param string $1
#   The message to delive
#
function complete_elapsed() {
  echo
  echo "👍  $(tty -s && tput setaf 4)${1//./} in $SECONDS seconds.$(tty -s && tput op)"
  echo

  return 0
}

##
# Echo an operation complete message.
#
# @param string $1
#   The message to delive
#
function complete() {
  echo
  echo "👍  $(tty -s && tput setaf 4)$1$(tty -s && tput op)"
  echo

  return 0
}

show_switch_state='remote'
function show_switch() {
  local title="Connecting to remote..."
  if [[ "$show_switch_state" == 'local' ]]; then
    title="Remote connection closed."
    show_switch_state='return'
  else
    show_switch_state='local'
  fi
  echo_yellow "🌎 $title"
  return 0
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
#   Sets the value of $mysql_check_local_result
#
function mysql_check_local() {
  local db_name=$1
  $ld_mysql --defaults-file=$local_db_cnf "$db_name" -e exit 2>/dev/null
  db_status=$(echo $?)
  if [ $db_status -ne 0 ]; then
    mysql_check_local_result=false
  else
    mysql_check_local_result=true
  fi
}

##
# Print out the header
#
#
function print_header() {
  echo_title "$local_location ~ $(url_host $local_url) 🔸  $local_role"
  if [[ "$op" != 'terminus' ]]; then
    if [[ "$motd" ]]; then
      echo
      echo "$(tty -s && tput setaf 5)$motd$(tty -s && tput op)"
    fi
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
  configtest_return=true
  echo 'Testing...'

  # Test for tools
  if ! [ -e "$ld_mysql" ]; then
    warning "\"$ld_mysql\" not found; you must set bin.mysql in your config file"
    configtest_return=false
  fi
  if ! [ -e "$ld_mysqldump" ]; then
    warning "\"$ld_mysqldump\" not found; you must set bin.mysql in your config file"
    configtest_return=false
  fi
  if ! [ -e "$ld_gunzip" ]; then
    warning "\"$ld_gunzip\" not found; you must set bin.mysql in your config file"
    configtest_return=false
  fi
  if ! [ -e "$ld_gzip" ]; then
    warning "\"$ld_gzip\" not found; you must set bin.mysql in your config file"
    configtest_return=false
  fi
  if ! [ -e "$ld_scp" ]; then
    warning "\"$ld_scp\" not found; you must set bin.mysql in your config file"
    configtest_return=false
  fi

  # Test for Pantheon support
  if [ "$terminus_site" ]; then

    if [ ! -f "$ld_terminus" ]; then
      warning "Terminus has not been installed; cd .loft_deploy && composer require terminus"
      configtest_return=false
    fi

    # assert can login
    if ! $ld_terminus auth:login --machine-token="$terminus_machine_token"; then
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

  # Test that production has copy source when local wants it
  if [[ "$local_copy_production_to" ]]; then
    if [[ ! "$production_copy_source" ]]; then
      configtest_return=false
      warning "Local:local.copy_production_to is expecting to copy individual files from production, however production:local.copy_source is not defined"
    fi

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
    configtest_return=false
    warning 'Your local files directory and production files directory should not be the same'
  fi

  # Assert the production script is found.

  # Assert that the production file directory exists
  if [ "$production_server" ] && [ "$production_files" ] && ! ssh $production_server$production_ssh_port "test -e $production_files"; then
    configtest_return=false
    warning "Your production files directory doesn't exist: $production_files"
  fi

  # Test for the presence of the .htaccess file in the .loft_config dir
  if [ ! -f "$config_dir/.htaccess" ]; then
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
  if [[ "$production_pass" ]] || [[ "$staging_pass" ]]; then
    configtest_return=false
    warning "You should no longer include production_pass nor staging_pass in your configuration; you must use key-based authentication instead.  Remove those values from your configuration files."
  fi

  # Test for other environments than prod, in prod environment
  if [ "$local_role" == 'prod' ] && ([ "$production_server" ] || [ "$staging_server" ]); then
    configtest_return=false
    warning "In a $local_role environment, no other environments should be defined.  Remove extra settings from config."
  fi

  # Test for directories
  if [ ! -d "$local_db_dir" ]; then
    configtest_return=false
    warning "local_db_dir: $local_db_dir does not exist."
  fi

  if [ "$local_files" ] && [ ! -d "$local_files" ]; then
    configtest_return=false
    warning "local_files: $local_files does not exist."
  fi

  # Test if files directory is inside of the parent of the config dir
  parent=$(realpath $(dirname "$config_dir"))
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
    configtest_return=false
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
    configtest_return=false
    warning "staging_root: Please define the staging environment's root directory"
  fi

  # Connection test to production/config test for production
  if [ "$production_root" ] && ! ssh $production_server$production_ssh_port "[ -f '${production_root}/.loft_deploy/config.yml' ]"; then
    configtest_return=false
    warning "production config.yml not found in  ${production_root}/.loft_deploy"
  fi

  # Connection test to staging/config test for staging
  if [ "$staging_root" ] && ! ssh $staging_server$staging_ssh_port "[ -f '${staging_root}/.loft_deploy/config.yml' ]"; then
    configtest_return=false
    warning "staging config.yml not found in  ${staging_root}/.loft_deploy"
  fi

  # Connection test to staging script test for staging
  if [ "$staging_root" ] && ! ssh $staging_server "[ -f '${staging_script}' ]"; then
    configtest_return=false
    warning "staging_script: ${staging_script} not found. Make sure you're not using ~ in the path."
  fi

  # Test drupal settings file
  if [ "$local_drupal_settings" ] && ! test -e "$local_drupal_settings"; then
    configtest_return=false
    warning "Drupal: Settings file cannot be found at $local_drupal_settings"
  fi

  # Test drupal settings has drupal_root
  if [ "$local_drupal_settings" ] && ! [ "$local_drupal_root" ]; then
    configtest_return=false
    warning "Missing config variable: \$local_drupal_root"
  fi

  # Check for 127.0.0.1 and port usage on local
  if [[ "$local_db_port" ]] && [[ "$local_db_host" == 'localhost' ]]; then
    warning 'When using $local_db_port, you should not set $local_db_host to "localhost", rather an IP.  See https://serverfault.com/questions/306421/why-does-the-mysql-command-line-tool-ignore-the-port-parameter'
  fi

  # Check for 127.0.0.1 and port usage on prod
  if [[ "$production_db_port" ]] && [[ "$production_remote_db_host" == 'localhost' ]]; then
    warning 'When using $production_db_port, you should not set $production_remote_db_host to "localhost", rather an IP. See https://serverfault.com/questions/306421/why-does-the-mysql-command-line-tool-ignore-the-port-parameter'
  fi

  # Test for db access
  mysql_check_local_result=false
  mysql_check_local "$local_db_name"
  if [ $mysql_check_local_result == false ]; then
    configtest_return=false
    warning "Can't connect to local DB; check credentials"
  fi

  # @todo test for ssh connection to prod
  # @todo test for ssh connection to staging

  # @todo test local and remote paths match
  if [ "$configtest_return" == true ]; then
    echo "$(tty -s && tput setaf $color_green)All tests passed.$(tty -s && tput op)"
  else
    echo "$(tty -s && tput setaf $color_red)Some tests failed.$(tty -s && tput op)"
  fi

  [[ $configtest_return == false ]] && return 1
  return 0
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
  echo_heading 'Local'
  table_add_row "Role" "$(echo $local_role | tr [:lower:] [:upper:])"
  table_add_row "Config" "$config_dir"
  if [ "$local_drupal_settings" ]; then
    table_add_row "DRUPAL_ROOT" "$local_drupal_root"
    table_add_row "Drupal" "$local_drupal_settings"
  fi

  table_add_row "DB Host" "$local_db_host"
  table_add_row "DB Name" "$local_db_name"
  table_add_row "DB User" "$local_db_user"
  [ "$local_db_port" ] && table_add_row "DB Port" "$local_db_port"
  table_add_row "DB Dumps" "$local_db_dir"

  table_add_row "Files" "$local_files"
  [ "$local_files2" ] && table_add_row "Files2" "$local_files2"
  [ "$local_files3" ] && table_add_row "Files3" "$local_files3"

  echo_slim_table

  if _access_check 'fetch_files'; then
    list_clear
    if [[ "$ld_rsync_ex" ]] && [[ "$(cat $ld_rsync_exclude_file)" ]]; then
      list_add_item "$ld_rsync_exclude_file"
    fi

    if [[ "$ld_rsync_ex2" ]] && [[ "$(cat $ld_rsync_exclude_file2)" ]]; then
      list_add_item "$ld_rsync_exclude_file2"
    fi

    if [[ "$ld_rsync_ex3" ]] && [[ "$(cat $ld_rsync_exclude_file3)" ]]; then
      list_add_item "$ld_rsync_exclude_file3"
    fi
    if list_has_items; then
      echo "Some files are $(echo_yellow "ignored") because of these file(s):"
      echo_list && echo && echo
    fi
  fi

  # Fetch Dates.
  if _access_check 'fetch_db'; then
    if [[ -f "$config_dir/prod/cached_db.txt" ]]; then
      table_add_row "Production Database" "$(cat $config_dir/prod/cached_db.txt)"
    fi
    if [[ -f "$config_dir/staging/cached_db.txt" ]]; then
      table_add_row "Staging Database" "$(cat $config_dir/staging/cached_db.txt)"
    fi
  fi

  if _access_check 'fetch_files'; then
    if [[ -f "$config_dir/prod/cached_files.txt" ]]; then
      table_add_row "Production Files" "$(cat $config_dir/prod/cached_files.txt)"
    fi

    if [[ -f "$config_dir/staging/cached_files.txt" ]]; then
      table_add_row "Staging Files" "$(cat $config_dir/staging/cached_files.txt)"
    fi
  fi
  if table_has_rows; then
    echo_heading 'Last Fetches'
    echo_slim_table && echo
  fi

  if [ "$local_role" == 'dev' ]; then
    load_staging_config
    load_production_config
    if [[ "$production_server" ]]; then
      echo_heading 'Production'
      table_add_row "Server" "$production_server"
      if [ $production_port ]; then
        table_add_row "Port" "$production_port"
      fi
      table_add_row "DB Host" "$production_db_host"
      table_add_row "DB Name" "$production_db_name"
      table_add_row "DB Dumps" "$production_db_dir"
      table_add_row "Files" "$production_files"
      [[ "$production_files2" != null ]] && table_add_row "Files2" "$production_files2"
      [[ "$production_files3" != null ]] && table_add_row "Files3" "$production_files3"
      echo_slim_table
    fi

    if [[ "$staging_server" ]]; then
      echo_heading 'Staging'
      table_add_row "Server" "$staging_server"
      if [ $staging_port ]; then
        table_add_row "Port" "$staging_port"
      fi
      table_add_row "DB Host" "$staging_db_host"
      table_add_row "DB Name" "$staging_db_name"
      table_add_row "DB Dumps" "$staging_db_dir"
      table_add_row "Files" "$staging_files"
      [[ "$staging_files2" != null ]] && table_add_row "Files2" "$staging_files2"
      [[ "$staging_files3" != null ]] && table_add_row "Files3" "$staging_files3"
      echo_slim_table
    fi
  fi

  if [[ "$migration_title" ]]; then
    echo_heading "Migration"
    table_add_row "From" "$migration_title"
    [[ "$migration_database_path" ]] && table_add_row "Database" "$migration_database_user@$migration_database_host:$migration_database_path"
    [[ "$migration_files_path" ]] && table_add_row "Files" "$migration_files_user@$migration_files_host:$migration_files_path"
    [[ "$migration_files2_path" ]] && table_add_row "Files2" "$migration_files2_user@$migration_files2_host:$migration_files2_path"
    [[ "$migration_files3_path" ]] && table_add_row "Files3" "$migration_files3_user@$migration_files3_host:$migration_files3_path"
    echo_slim_table
  fi

  echo && echo "$(get_title) VER $(get_version)"
}

function warning() {
  echo
  echo "$(tty -s && tput setaf 3)$1$(tty -s && tput op)"
  if [ "$2" ]; then
    echo_fix "$2"
  fi
  confirm 'Disregard warning' && return 0
  exit_with_failure --status=2 "Tests did not complete"
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
  echo "$(tty -s && tput setaf 2)$1$(tty -s && tput op)"
  echo
}

##
# Handle a pre hook for an op.
#
# @param string $1
#   The operation being called, e.g. reset, fetch, pull
# @param bool $2
#   The return status of the operation.
#
function handle_pre_hook() {
  _handle_hook $1 pre $2
}

##
# Handle a post hook for an op.
#
# @param string $1 The operation being called, e.g. reset, fetch, pull
#
function handle_post_hook() {
  _handle_hook $1 post $2
}

##
# Handle a single hook
#
# @param string $1 The operation being called, e.g. reset, fetch, pull
# @param string $2 The timing, e.g. pre, post
#
function _handle_hook() {
  refresh_operation_assets
  local op=$1
  local op_status=$3
  local timing=$2
  local status=true
  declare -a local hooks=()

  for item in "${operation_assets[@]}"; do
    [[ 'files' == "$item" ]] && hooks=("${hooks[@]}" "${op}_files_${timing}")
    [[ 'database' == "$item" ]] && hooks=("${hooks[@]}" "${op}_db_${timing}")
  done
  hooks=("${hooks[@]}" "${op}_${timing}")

  for hook_stub in "${hooks[@]}"; do
    local hook="$config_dir/hooks/$hook_stub.sh"
    has_option v && echo "├──  Looking for hook: ${hook##*/}"
    local basename=$(basename $hook)
    declare -a hook_args=("$op" "$production_server" "$staging_server" "$local_basepath" "$config_dir/$source_server/copy" "$source_server" "$op_status" "" "" "" "" "" "$config_dir/hooks/")
    if test -e "$hook"; then
      echo_heading "Calling hook: $basename"
      source "$hook" "${hook_args[@]}"
      [[ $? -ne 0 ]] && echo_red "└── Hook failed." && status=false
    fi
  done

  [[ "$status" == true ]] && return 0
  return 1
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
  exit
}

##
# Checks access (optionally for $1)
#
# @param string $1
#   An op to test for against current config
#
function _access_check() {

  # List out helper commands, with universal access regardless of local_role
  if [ "$1" == '' ] || [ "$1" == 'config' ] || [ "$1" == 'clearcache' ] || [ "$1" == 'help' ] || [ "$1" == 'info' ] || [ "$1" == 'configtest' ] || [ "$1" == 'ls' ] || [ "$1" == 'init' ] || [ "$1" == 'update' ] || [ "$1" == 'mysql' ] || [ "$1" == 'hook' ]; then
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
    'export-purge')
      return 0
      ;;
    'config-export')
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
    'export-purge')
      return 0
      ;;
    'import')
      return 0
      ;;
    'pass')
      return 0
      ;;
    'migrate')
      return 0
      ;;
    'config-export')
      return 0
      ;;
    'pull')
      eval $(get_config stage_may_pull_prod false)
      [[ "$stage_may_pull_prod" == true ]] && return 0
      return 1
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
  complete "$(tty -s && tput setaf $color_green)$1$(tty -s && tput op)"
  declare -a ls_flags=()
  for flag in "${flags[@]}"; do
    if [ $flag != 'd' ] && [ $flag != 'f' ]; then
      ls_flags=("${ls_flags[@]}" "$flag")
    fi
  done
  ls -$ls_flags $1
  complete
}

##
# Generate the local.cnf with db creds.
#
function generate_db_cnf() {

  # Create the .cnf file
  test -f $local_db_cnf && chmod 600 $local_db_cnf
  echo "# AUTOGENERATED, DO NOT EDIT!" >$local_db_cnf
  echo "[client]" >>$local_db_cnf
  echo "host=\"$local_db_host\"" >>$local_db_cnf
  [ "$local_db_port" ] && echo "port=\"$local_db_port\"" >>$local_db_cnf
  echo "user=\"$local_db_user\"" >>$local_db_cnf
  echo "password=\"$local_db_pass\"" >>$local_db_cnf
  chmod 400 $local_db_cnf
}

##
# Remove the value of a $conf or $settings variable as found in a Drupal settings file.
#
# @param string $1
#   The filepath to the PHP settings file.
# @param string $2
#   The key of the $conf variable to empty.
#
# @code
#   $settings['hash_salt'] = NULL;
# @endcode
#
# @return int
#   - 0 success
#   - 1 file not found
#   - 2 replacement in file failed
#
function hooks_empty_drupal_conf() {
  local file=$1
  local key=$2

  if [[ ! -f "$file" ]]; then
    echo_red "├── file \"$file\" does not exist."
    return 1
  fi
  local key_escaped="${key//\]\[/\\]\\[}"
  sed -i '' "s/[\"']$key_escaped[\"'].*$/'$key_escaped'] = NULL;/g" $file || return 2
  echo_green "├── \"$key\" set to NULL."
  return 0
}

##
# Remove the value of a key in an associative array..
#
# @param string $1
#   The filepath to the PHP file.
# @param string $2
#   The key of the array variable to empty.
#
# @return int
#   - 0 success
#   - 1 file not found
#   - 2 replacement in file failed
#
# To use this on an associative array such as:
#
#   $config['reroute_email.settings']['address'] = 'aklump@mbp-aaron.local';
#
# Call in this manner:
#
#   hooks_empty_drupal_conf $file "reroute_email.settings'\]\['address" || return 1
#
function hooks_empty_array_key() {
  local file="$1"

  if [[ ! -f "$file" ]]; then
    echo_red "├── file \"$file\" does not exist."
    return 1
  fi
  local key=$2
  local success=false
  local extension=$(path_extension $file)
  local before=$(cat $file)

  case $extension in
  php)
    sed -i '' "s/^.*$key.*$/'$key' => NULL,/g" $file && success=true
    ;;
  yml)
    sed -i '' "s/^.*$key.*$/$key: NULL,/g" $file && success=true
    ;;
  esac

  [[ "$before" == "$(cat $file)" ]] && success=false

  [[ $success == true ]] && echo_green "├── $key set to NULL." && return 0
  return 2
}

function hooks_yaml_set_var() {
  local file="$1"
  local var_names_csv="$2"
  local value="$3"

  if [[ ! -f "$file" ]]; then
    echo_red "├── file \"$file\" does not exist."
    return 1
  fi

  php "$ROOT/includes/scrubber.php" "$file" "$var_names_csv" "$value" yamlSetVar
  local result=$?

  if [[ $result -ne 0 ]]; then
    echo_red "├── hooks_yaml_set_var failed setting \"$var_names_csv\" on $(basename $file)"
    return 1
  fi
  echo_green "├── $var_names_csv set to NULL."
  return $result
}

# Empty the value of a PHP variable assignment
#
# $1 - string Path to the file.
# $2 - string The name of the variable, omit the leading $, e.g, 'wgDBpassword'.
#  Can also be a CSV list of variable names.
#
# You will use this to remove the password from a file containing something like
# the following:
# @code
#   $wgDBpassword       = "some_secret_password";
# @endcode
#
# ... becomes
#
# @code
#   $wgDBpassword       = null;;
# @endcode
#
# Returns 0 if .
function hooks_set_vars_to_null() {
  local file="$1"
  local var_names_csv="$2"

  if [[ ! -f "$file" ]]; then
    echo_red "├── file \"$file\" does not exist."
    return 1
  fi

  php "$ROOT/includes/scrubber.php" "$file" "$var_names_csv" setVariableByName
  local result=$?

  [[ $result -eq 0 ]] && echo_green "├── $var_names_csv set to NULL."
  return $result
}

# Replace the password in a standard URL with PASSWORD.
#
# Returns 0 if a change was made in the file.
function hooks_env_sanitize_url() {
  local file="$1"
  local var_names_csv="$2"
  php "$ROOT/includes/scrubber.php" "$file" "$var_names_csv" envSanitizeUrl
  local result=$?

  [[ $result -eq 0 ]] && echo_green "├── Password(s) in $var_names_csv have been masked."
  return $result
}

# Set the value of variable in .env file.
#
# $1 - string file
# $2 - string var_names_csv
# $1 - string value (optional) Omit to set to "".
#
# Returns 0 if a change was made in the file.
function hooks_env_set_var() {
  local file="$1"
  local var_names_csv="$2"
  local value="$3"

  php "$ROOT/includes/scrubber.php" "$file" "$var_names_csv" "$value" envSetVar
  local result=$?
  [[ "$value" ]] || value="''"

  if [[ $result -ne 0 ]]; then
    echo_red "├── hooks_env_set_var failed setting \"$var_names_csv\" on $(basename $file)"
    return 1
  fi
  echo_green "├── $var_names_csv set to: $value."
  return $result
}

# Echo the public IP of the current server
#
# Returns 0 if found 1 otherwise.
function get_public_ip() {
  local ip
  ip=$(curl -s http://checkip.dyndns.org/ | sed 's/[a-zA-Z<>/ :]//g')
  [[ "$ip" ]] && echo "$ip" && exit 0

  exit 1
}
