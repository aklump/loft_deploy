#!/usr/bin/env bash

#
# @file
# Core functions used by the cloudy api.
#
function _cloudy_define_cloudy_vars() {
    # todo Can we move more things here, or would that break scope?
    LI="├──"
    LIL="└──"
    LI2="│   $LI"
    LIL2="│   $LIL"
}

function _cloudy_bootstrap_translations() {
    # todo Document this and add to schema.
    eval $(get_config_as "lang" "language" "en")
    CLOUDY_LANGUAGE=$lang

    # todo may not need to do these two?
    CLOUDY_SUCCESS=$(translate "Completed successfully.")
    CLOUDY_FAILED=$(translate "Failed.")
}

function _cloudy_bootstrap() {
    SECONDS=0
    local aliases
    local value
    local options
    local command

    _cloudy_bootstrap_translations

    command=$(get_command)
    # Add in the alias options based on master options.
    for option in "${CLOUDY_OPTIONS[@]}"; do
        value="true"
        [[ "$option" =~ ^(.*)\=(.*) ]] && option=${BASH_REMATCH[1]} && value=${BASH_REMATCH[2]}
        eval $(get_config_keys_as 'aliases' "commands.${command}.options.${option}.aliases")
        for alias in ${aliases[@]}; do
           if ! has_option $alias; then
               CLOUDY_OPTIONS=("${CLOUDY_OPTIONS[@]}" "$alias")
               eval "CLOUDY_OPTION__$(string_upper $alias)=\"$value\""
           fi
        done
    done

    # Using aliases search for the master option.
    eval $(get_config_keys_as 'options' "commands.${command}.options")

    for master_option in "${options[@]}"; do
        eval $(get_config_as -a 'aliases' "commands.${command}.options.${master_option}.aliases")
        for alias in "${aliases[@]}"; do
            if has_option $alias && ! has_option $master_option; then
                value=$(get_option "$alias")
                CLOUDY_OPTIONS=("${CLOUDY_OPTIONS[@]}" "$master_option")
                eval "CLOUDY_OPTION__$(string_upper $master_option)=\"$value\""
            fi
        done
    done
}

##
 # Delete $CACHED_CONFIG_FILEPATH as necessary.
 #
function _cloudy_auto_purge_config() {
    local cache_mtime_filepath="${CACHED_CONFIG_FILEPATH/.sh/.modified.txt}"

    if [[ "$cloudy_development_do_not_cache_config" == true ]] || _cloudy_has_config_changed; then
        if [[ "$cloudy_development_do_not_cache_config" == true ]]; then
            write_log_dev_warning "Configuration purge detected due to \$cloudy_development_do_not_cache_config = true."
        else
            write_log_notice "Config changes detected.  $CACHED_CONFIG_FILEPATH is out of date."
        fi
        if ! rm -f "$CACHED_CONFIG_FILEPATH"; then
            fail_because "Could not rm $CACHED_CONFIG_FILEPATH during purge."
            write_log_critical "Cannot delete $CACHED_CONFIG_FILEPATH.  Cached configuration may be stale."
        fi
    fi

    has_failed && exit_with_failure "Cannot auto purge config."
    return 0
}

##
 # Detect if cached config is stale against $CONFIG.
 #
function _cloudy_has_config_changed() {
    local cache_mtime_filepath="${CACHED_CONFIG_FILEPATH/.sh/.modified.txt}"
    [ -f "$CACHED_CONFIG_MTIME_FILEPATH" ] || touch "$CACHED_CONFIG_MTIME_FILEPATH" || fail

    local cache_mtime=$(cat "$CACHED_CONFIG_MTIME_FILEPATH")
    [[ "$cache_mtime" ]] || write_log_error "Missing timestamp in $CACHED_CONFIG_MTIME_FILEPATH"

    # Test if the yaml file was modified and automatically rebuild config.yml.sh
    [[ $(_cloudy_get_file_mtime $CONFIG) -gt "$cache_mtime" ]]
    return $?
}

function _cloudy_get_file_mtime() {
    local filepath=$1
    echo $(php -r "echo filemtime('$filepath');")
}

##
 # Return config eval code for a given config path.
 #
 # @param string
 #   The config path, e.g. "commands.help.help"
 # @param string
 #   The default value if not found. This yields an exit status of 2.
 #
 # Options:
 # --as={custom_var_name}
 # --keys You want to return array keys.
 # --mutator={function name} Optional mutator function name.
 #
function _cloudy_get_config() {
    local config_path="$1"
    local default_value="$2"

    local default_type
    local var_name
    local var_type
    local var_value
    local var_code
    local array_keys
    local mutator
    local eval_code
    local dev_null
    local code
    local cached_var_name
    local cached_var_name_keys
    local file_list

    parse_args $@
    config_path=${parse_args__args[0]/-/_}
    cached_var_name="cloudy_config___${config_path//./___}"

    # This is the name of the variable containing the keys for $cached_var_name
    cached_var_name_keys=${cached_var_name/cloudy_config___/cloudy_config_keys___}

    get_array_keys=${parse_args__option__keys}
    [[ "$get_array_keys" ]] && cached_var_name="cloudy_config_keys___${config_path//./___}"
    default_value=${parse_args__args[1]}
    # Use the synonym if --as is passed
    var_name=${parse_args__option__as:-${config_path//./_}}

    [[ "${parse_args__option__a}" == true ]] && default_type='array'
    mutator=${parse_args__option__mutator}

    # todo Can we simplify this a bit?
    var_value=$(eval "echo "\$$cached_var_name"")
    if [[ "$var_value" ]]; then
        code=$(declare -p "$cached_var_name")
        code="${code/$cached_var_name=/var_value=}"
        eval "$code"
    fi

    # Todo should we try and autodetect?
    var_type="$default_type"

    # Determine the default value
    # @todo How to handle array defaults, syntax?
    # @link https://trello.com/c/6JXskrQn/9-c-619-allow-arrays-to-have-default-values-in-getconfig
    if ! [[ "$var_value" ]]; then
        if [[ "$var_type" == 'array' ]]; then
            # Todo this is not fully implemented yet.
            local eval_code="declare -a local $cached_var_name=("$default_value")"
        else
            local eval_code="local $cached_var_name="$default_value""
        fi
        eval $eval_code
    fi

    # Determine what type of array.
    if [[ "$var_type" == "array" ]]; then
        eval "local var_keys=("\${$cached_var_name_keys[@]}")"
        if [[ "${var_keys[0]}" == 0 ]] || [[ "${var_keys[0]}" == "" ]]; then
            var_type="indexed_array"
        else
            var_type="associative_array"
        fi
    fi

    # It's an array and the keys are being asked for.
    if [[ "$get_array_keys" ]] && [[ "$var_type" =~ _array$ ]]; then
        #todo mutator for array values.
        code=$(declare -p $cached_var_name_keys)
        code="${code//$cached_var_name=/$var_name=}"

    elif [[ "$var_type" == "associative_array" ]]; then
        code=''
        for key in "${var_keys[@]}"; do
            var_code=$(declare -p ${cached_var_name}___${key})
            code="${code}${var_code/${cached_var_name}___${key}/${var_name}_${key}};"
            # todo mutator for array values.
        done
    else

        if [[ "$mutator" == "_cloudy_realpath" ]]; then

            # On first pass we will try to expand globbed filenames, which will
            # cause file_list to be longer than var_value.
            file_list=()
            for path in "${var_value[@]}"; do
                # This will expand a glob finder.
                if [ -d "$path" ]; then
                    file_list=("${file_list[@]}" $path)
                elif [ -f "$path" ]; then
                    file_list=("${file_list[@]}" $(ls $path))
                else
                    file_list=("${file_list[@]}" $path)
                fi
            done

            # Glob may have increased our file_list so we apply realpath to all
            # of them here.
            local i=0
            for path in "${file_list[@]}"; do
                if [ -e "$path" ]; then
                    file_list[$i]=$(realpath "$path")
                fi
                let i++
            done
            eval "$cached_var_name=("${file_list[@]}")"
        fi

        code=$(declare -p $cached_var_name)
        code="${code//$cached_var_name=/$var_name=}"
    fi

    echo ${code%;} && return 0
}



function _cloudy_exit() {
    exit $CLOUDY_EXIT
}

##
 # Prepare a message with optional suffix and fallback.
 #
 # * default is used if no override is given.
 # * Ensures ends with period.
 #
function _cloudy_message() {
    local override=$1
    local default=$2
    local suffix=$3

    if [[ "$override" ]]; then
      echo ${override%.}${suffix} && return 0
    fi
    echo ${default%.}${suffix} && return 2
}

function _cloudy_echo_color() {
    local color=$1
    local message=$2
    local bg=$3

    if [[ "$bg" ]]; then
        echo "$(tput setaf $color)$(tput setab $bg)$message$(tput sgr0)"
    else
        echo "$(tput setaf $color)$message$(tput sgr0)"
    fi
}

function _cloudy_echo_credits() {
    echo "Cloudy $(get_version) by Aaron Klump"
}

##
 # Echo a list of items with bullets in color
 #
function _cloudy_echo_list() {
    local line_item
    local color_items=$1
    local color_bullets=$2
    local bullet
    local item
    for i in "${echo_list__array[@]}"; do
        bullet="$LI"
        if [[ "$color_bullets" ]]; then
            bullet=$(_cloudy_echo_color $color_bullets "$LI")
        fi
        item="$line_item"
        if [[ "$color_items" ]]; then
            item=$(_cloudy_echo_color $color_items "$line_item")
        fi
        [[ "$line_item" ]] && echo "$bullet $item"
        line_item="$i"
    done

    bullet="$LIL"
    if [[ "$color_bullets" ]]; then
        bullet=$(_cloudy_echo_color $color_bullets "$LIL")
    fi
    item="$line_item"
    if [[ "$color_items" ]]; then
        item=$(_cloudy_echo_color $color_items "$line_item")
    fi
    [[ "$line_item" ]] && echo "$bullet $item"
}

function _cloudy_exit_with_success() {
    local message=$1
    echo && echo_blue "👍  $message"

    ## Write out the failure messages if any.
    if [ ${#CLOUDY_SUCCESSES[@]} -gt 0 ]; then
        echo_list__array=("${CLOUDY_SUCCESSES[@]}")
        echo_blue_list
    fi

    echo
    CLOUDY_EXIT_STATUS=0 && _cloudy_exit
}

##
 # Echo command or command alias' target.
 #
function _cloudy_get_master_command() {
    local command_or_alias="$1"

    # See if it's a master command.
    eval $(get_config_keys "commands")
    array_has_value__array=(${commands[@]})
    array_has_value "$command_or_alias" && echo $command_or_alias && return 0

    # Look for command as an alias.
    for c in "${commands[@]}"; do
        eval $(get_config_as -a "aliases" "commands.$c.aliases")
        array_has_value__array=(${aliases[@]})
        array_has_value "$command_or_alias" && echo $c && return 0
    done

    return 1
}

##
 # Set $_cloudy_get_valid_operations_by_command__array to all defined operations included aliases for a given op.
 #
function _cloudy_get_valid_operations_by_command() {
    local command=$1

    local option
    local options
    local aliases

    eval $(get_config_keys_as 'options' -a "commands.${command}.options")

    for option in "${options[@]}"; do
        eval $(get_config_as 'aliases' -a "commands.${command}.options.${option}.aliases")

        options=("${options[@]}" "${aliases[@]}")
    done

    _cloudy_get_valid_operations_by_command__array=("${options[@]}")
}

function _cloudy_validate_against_scheme() {
    local config_path_to_schema=$1
    local name=$2
    local value=$3

    local errors
    echo $(php $CLOUDY_ROOT/php/validate_against_schema.php "$CLOUDY_CONFIG_JSON" "$config_path_to_schema" "$name" "$value")
    return $?
}

function _cloudy_help_commands() {
    local commands
    local help_command
    local help

    echo_title "$(get_title) VER $(get_version)"

    echo_yellow "Available commands:"
    eval $(get_config_keys "commands")
    for help_command in "${commands[@]}"; do
        eval $(get_config_as 'help' "commands.$help_command.help")
        echo_list__array=("${echo_list__array[@]}" "$(echo_green "${help_command}") $help")
    done
    echo_list
}

function _cloudy_help_for_single_command() {
    local command_help_topic=$1

    local arguments
    local options
    local usage
    local option
    local option_value
    local option_type
    local help_option
    local help_options
    local help_alias
    local help_argument

    eval $(get_config_keys_as 'arguments' -a "commands.${command_help_topic}.arguments")
    eval $(get_config_keys_as -a 'options' "commands.${command_help_topic}.options")

    echo_title "Help Topic: $command_help_topic"

    eval $(get_config_as 'help' "commands.${command_help_topic}.help")
    echo_green "$help"
    echo

    usage="./$(basename $SCRIPT) CMD"
    [ ${#arguments} -gt 0 ] && usage="$usage <arguments>"
    [ ${#options} -gt 0 ] && usage="$usage <options>"

    # Generate a list of command + aliases.
    eval $(get_config_as 'usage_commands' "commands.${command_help_topic}.aliases")
    usage_commands=("$command_help_topic" ${usage_commands[@]})
    for usage_command in "${usage_commands[@]}"; do
        echo_list__array=("${echo_list__array[@]}" "${usage/CMD/$usage_command}")
    done
    echo_yellow "Usage:"
    echo_list
    echo

    # The arguments.
    if [ ${#arguments} -gt 0 ]; then
        echo_yellow "Arguments:"
        echo_list__array=()

        for help_argument in "${arguments[@]}"; do
            eval $(get_config_as 'help' "commands.${command_help_topic}.arguments.${help_argument}.help")
            echo_list__array=("${echo_list__array[@]}" "$(echo_green "$help_argument") $help")
        done
        echo_list
        echo
    fi

    # The options.
    if [ ${#options} -gt 0 ]; then
        echo_yellow "Available options:"
        echo_list__array=()

        for option in "${options[@]}"; do

            option_value=''
            eval $(get_config_as 'option_type' "commands.${command_help_topic}.options.${option}.type" "boolean")
            [[ "$option_type" != "boolean" ]] && option_value="=<$option_type>"

            help_options=("$option")

            # Add in the aliases
            eval $(get_config_as -a 'aliases' "commands.${command_help_topic}.options.${option}.aliases")
            for help_alias in "${aliases[@]}"; do
               help_options=("${help_options[@]}" "$help_alias")
            done

            array_sort_by_item_length__array=(${help_options[@]})
            array_sort_by_item_length

            # Add in hyphens and values
            help_options=()
            for help_option in "${array_sort_by_item_length__array[@]}"; do
               if [ ${#help_option} -eq 1 ]; then
                    help_options=("${help_options[@]}" "-${help_option}${option_value}")
               else
                    help_options=("${help_options[@]}" "--${help_option}${option_value}")
               fi
            done

            array_join__array=(${help_options[@]})
            help_options=$(array_join ", ")

            eval $(get_config_as 'help' "commands.${command_help_topic}.options.${option}.help")

            echo_list__array=("${echo_list__array[@]}" "$(echo_green "$help_options") $help")
        done
        echo_list
    fi
}

function _cloudy_validate_command() {
    local command=$1

    local commands

    # See if it's a master command.
    eval $(get_config_keys "commands")
    array_has_value__array=(${commands[@]})
    array_has_value "$command" && return 0

    # Look for command as an alias.
    for c in "${commands[@]}"; do
        eval $(get_config_as -a "aliases" "commands.$c.aliases")
        array_has_value__array=(${aliases[@]})
        array_has_value "$command" && return 0
    done

    fail_because "You have called $(basename $SCRIPT) using the command \"$command\", which does not exist."
    return 1
}

function _cloudy_debug_helper() {
    local sidebar=''
    local IFS=";"; read default fg bg message basename funcname lineno  <<< "$@"
    [[ "$basename" ]] && sidebar="$sidebar${basename##./}"
    [[ "$funcname" ]] && sidebar="$funcname in $sidebar"
    [[ "$lineno" ]] && sidebar="$sidebar on line $lineno"
    [[ "$sidebar" ]] || sidebar="$default"
    echo && echo "$(tput setaf $fg)$(tput setab $bg) $sidebar $(tput smso) "$message" $(tput sgr0)" && echo
}

function _cloudy_assert_failed() {
    local actual=$1
    local reason="$(echo "$2")"

    [ ${#actual} -eq 0 ] && actual='""'
    actual="$(echo_yellow "$actual")"
    [[ $# -gt 2 ]] && expected="$(echo_green "$3")"

    let CLOUDY_FAILED_ASSERTION_COUNT=(CLOUDY_FAILED_ASSERTION_COUNT + 1)
    [[ "$CLOUDY_ACTIVE_TEST" ]] && fail_because "Failed test: $CLOUDY_ACTIVE_TEST in $(basename $CLOUDY_ACTIVE_TESTFILE)" && CLOUDY_ACTIVE_TEST=''

    local because="$actual $reason"
    [[ $# -gt 2 ]] && because="$because expected $expected"
    fail_because "$because"

    return 1
}

function _cloudy_write_log() {
    [[ "$LOGFILE" ]] || return
    local level="$1"
    shift
    local directory=$(dirname $LOGFILE)
    test -d "$directory" || mkdir -p "$directory"
    touch "$LOGFILE"
    echo "[$(date)] [$level] $@" >> "$LOGFILE"
}

function _cloudy_trigger_event() {
    local hook_name="on_${1}"

    shift
    if [[ "$(type -t $hook_name)" == "function" ]]; then
        eval $hook_name $@ || return 1
    fi
    return 0
}

##
 # Helper to echo a table-like output.
 #
function _cloudy_echo_aligned_columns() {
    parse_args $@
    local lpad=${parse_args__option__lpad:-1}
    local rpad=${parse_args__option__rpad:-4}
    local lborder="${parse_args__option__lborder}"
    local mborder="${parse_args__option__mborder}"
    local rborder="${parse_args__option__rborder}"
    local top="${parse_args__option__top}"

    # Draw a line
    local width=${#lborder}
    local column_width
    local line

    i=1
    for column_width in "${_cloudy_table_col_widths[@]}"; do
        width=$(( $width + $lpad + $column_width + $rpad))
        if [[ $i -lt ${#_cloudy_table_col_widths} ]]; then
            width=$(( $width + ${#mborder}))
        fi
        let i++
    done
    if [ ${#_cloudy_table_col_widths[@]} -gt 1 ]; then
        width=$(( $width + ${#rborder}))
    fi
    line="$(string_repeat "$top" $width)"

    echo "$line"

    # Deal with header
    if [ ${#_cloudy_table_header[@]} -gt 0 ]; then
        array_join__array=("${_cloudy_table_header[@]}")
        _cloudy_table_rows=("$(array_join '|')" "${_cloudy_table_rows[@]}")
    fi

    # Output the body
    local row_id=0
    for string_split__string in "${_cloudy_table_rows[@]}"; do
        string_split '|'
        local column_index=0
        echo -n "${lborder}"
        local last_column=${#_cloudy_table_col_widths[@]}
        let last_column--
        for cell in "${string_split__array[@]}"; do
            echo -n "$(string_repeat " " $lpad)$cell"
            echo -n "$(string_repeat " " $(( ${_cloudy_table_col_widths[$column_index]} - ${#cell} + $rpad )))"

            if [ $column_index -eq $last_column ]; then
                echo -n "${rborder}"
            else
                echo -n "${mborder}"
            fi
            let column_index++
        done
        echo

        if [ ${#_cloudy_table_header[@]} -gt 0 ] && [ $row_id -eq 0 ]; then
            echo $line
        fi

        let row_id++
    done

    echo "$line"

    # Reset the table global vars.
    _cloudy_table_col_widths=()
    _cloudy_table_header=()
    _cloudy_table_rows=()
}

#
# Begin Core Controller Section.
#

# Expand some vars from our controlling script.
CONFIG="$(cd $(dirname "$r/$CONFIG") && pwd)/$(basename $CONFIG)"
if [[ "$LOGFILE" ]]; then
    log_dir="$(dirname $r/$LOGFILE)"
    mkdir -p "$log_dir" || exit_with_failure "Please manually create \"$log_dir\" and ensure it is writeable."
    LOGFILE="$(cd $log_dir && pwd)/$(basename $LOGFILE)"
fi

_cloudy_define_cloudy_vars

# Store the script options for later use.
parse_args $@

declare -a CLOUDY_ARGS=("${parse_args__args[@]}")
declare -a CLOUDY_OPTIONS=("${parse_args__options[@]}")
for option in "${CLOUDY_OPTIONS[@]}"; do
    eval "CLOUDY_OPTION__$(string_upper $option)=\"\$parse_args__option__${option}\""
done

# Define shared variables
declare -a CLOUDY_FAILURES=()
declare -a CLOUDY_SUCCESSES=()
CLOUDY_EXIT_STATUS=0

#
# Setup caching
#

# For scope reasons we have to source these here and not inside _cloudy_bootstrap.
CACHE_DIR="$CLOUDY_ROOT/cache"
CACHED_CONFIG_FILEPATH="$CACHE_DIR/_cached.$(path_filename $SCRIPT).config.sh"
CACHED_CONFIG_MTIME_FILEPATH="${CACHED_CONFIG_FILEPATH/.sh/.modified.txt}"

# Ensure the configuration cache environment is present and writeable.
if [ ! -d "$CACHE_DIR" ]; then
    mkdir -p "$CACHE_DIR" || exit_with_failure "Unable to create cache folder: $CACHE_DIR"
fi

# Detect changes in YAML and purge config cache if necessary.
_cloudy_auto_purge_config

# Generate the cached configuration file.
if [ ! -f "$CACHED_CONFIG_FILEPATH" ]; then
    touch $CACHED_CONFIG_FILEPATH || exit_with_failure  "Unable to write cache file: $CACHED_CONFIG_FILEPATH"

    # Normalize the config file to JSON.
    additional_config=$(_cloudy_trigger_event "compile_config")
    CLOUDY_CONFIG_JSON="$(php $CLOUDY_ROOT/php/config_to_json.php "$ROOT" "$CONFIG" "$cloudy_development_skip_config_validation" "$additional_config")"
    [ $? -ne 0 ] && exit_with_failure "$CLOUDY_CONFIG_JSON"

    [[ "$cloudy_development_skip_config_validation" == true ]] && write_log_dev_warning "Configuration validation is disabled due to \$cloudy_development_skip_config_validation == true."

    # Convert the JSON to bash config.
    php "$CLOUDY_ROOT/php/json_to_bash.php" "$ROOT" "$CLOUDY_CONFIG_JSON" > "$CACHED_CONFIG_FILEPATH"
    if [ $? -ne 0 ]; then
        compiled=$(cat  "$CACHED_CONFIG_FILEPATH")
        fail_because "$(IFS="|"; read file reason <<< "$compiled"; echo "$reason")"
        exit_with_failure "Cannot create cached config filepath."
    else
        echo "$(_cloudy_get_file_mtime $CONFIG)" > "$CACHED_CONFIG_MTIME_FILEPATH"
        write_log_notice "$(basename $CONFIG) configuration compiled to $CACHED_CONFIG_FILEPATH."
    fi
fi

# Import the cached config variables at this top scope into memory.
source "$CACHED_CONFIG_FILEPATH" || exit_with_failure "Cannot load cached configuration."

#
# End caching setup
#

_cloudy_trigger_event "boot" || exit_with_failure "Could not bootstrap $(get_title)"
_cloudy_bootstrap $@


