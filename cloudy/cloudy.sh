#!/usr/bin/env bash

##
 # Determine if a given directory has any files in it.
 #
function dir_has_files() {
    local path_to_dir="$1"

    [ -d "$path_to_dir" ] && [[ "$(ls "$path_to_dir")" ]]
}

function get_title() {
    local default="$1"

    local title
    eval $(get_config "title" "$default")
    echo $title
}

function get_version() {
    local version
    eval $(get_config "version" "1.0")
    echo $version
}

##
 # Return the current UNIX timestamp.
 #
function timestamp() {
    echo $(date +%s)
}

##
 # Return the current datetime in iso 8601 in UTC.
 #
 # @option -c Remove punctuation for a compressed output say, for a filename.
 #
function date8601() {
    parse_args $@
    if [[ "$parse_args__option__c" ]]; then
        echo $(date -u +%Y%m%dT%H%M%S)
    else
        echo $(date -u +%Y-%m-%dT%H:%M:%S)
    fi
    return 0
}

#
# SECTION: Arguments, options, parameters
#

##
 # Validate the CLI input arguments and options.
 #
function validate_input() {
    local command

    command=$(get_command)

    # Assert only defined operations are valid.
    [[ "$command" ]] && _cloudy_validate_command $command

    # Assert only defined options for a given op.
    _cloudy_get_valid_operations_by_command $command

    for name in "${CLOUDY_OPTIONS[@]}"; do
       array_has_value__array=(${_cloudy_get_valid_operations_by_command__array[@]})
       array_has_value $name || fail_because "Invalid option: $name"
       eval "value=\"\$CLOUDY_OPTION__$(string_upper $name)\""

       # Assert the provided value matches schema.
       eval $(_cloudy_validate_against_scheme "commands.$command.options.$name" "$name" "$value")
       if [[ "$schema_errors" ]]; then
            for error in "${schema_errors[@]}"; do
               fail_because "$error"
            done
       fi
    done

    has_failed && return 1
    return 0
}

##
 # Parses arguments into options, args and option values.
 #
 # @code
 #   function my_func{) {
 #     parse_args @$
 #     ...
 # @endcode
 #
 # The following variables are generated for:
 # @code
 #   my_func -ab --tree=life do re
 # @endcode
 #
 # - parse_args__args=(do re)
 # - parse_args__options=(a b tree)
 # - parse_args__option__a=true
 # - parse_args__option__b=true
 # - parse_args__option__tree=life
 # - parse_args__options_passthru="-a -b -tree=life"
 #
function parse_args() {
    local name
    local value

    # Purge any previous values.
    for name in "${parse_args__options[@]}"; do
        eval "unset parse_args__option__${name}"
    done
    parse_args__options=()
    parse_args__args=()
    parse_args__options_passthru=''

    # Set the new values.
    for arg in "$@"; do
        if ! [[ "$arg" =~ ^(-{1,2})(.+)$ ]]; then
            parse_args__args=("${parse_args__args[@]}" "$arg")
            continue
        fi

        # a=1, dog=bark
        if [[ ${BASH_REMATCH[2]} = *"="* ]]; then
            [[ ${BASH_REMATCH[2]} =~ (.+)=(.+) ]]
            name="${BASH_REMATCH[1]}"
            value="${BASH_REMATCH[2]}"

            parse_args__options=("${parse_args__options[@]}" "$name")
            eval "parse_args__option__${name}=\"${value}\""
            parse_args__options_passthru="$parse_args__options_passthru $arg"

        # bc, tree
        else
            if [ ${#BASH_REMATCH[1]} -gt 1 ]; then
                options=("${BASH_REMATCH[2]}")
            else
                options=($(echo "${BASH_REMATCH[2]}" | grep -o .))
            fi
            for name in "${options[@]}"; do
                parse_args__options=("${parse_args__options[@]}" "$name")
                eval "parse_args__option__${name}=true"
                parse_args__options_passthru="$parse_args__options_passthru -${name}"
            done
        fi
    done
}

##
 # Determine if the script was called with a command.
 #
function has_command() {
  [ ${#CLOUDY_ARGS[0]} -gt 0 ]
}

function get_command() {
    local command
    local c

    # Return default if no command given.
    if [ ${#CLOUDY_ARGS[0]} -eq 0 ]; then
        eval $(get_config_as "command" "default_command")
        echo $command && return 2
    fi

    command="${CLOUDY_ARGS[0]}"

    # See if it's a master command.
    eval $(get_config_keys "commands")
    array_has_value__array=(${commands[@]})
    array_has_value "$command" && echo $command && return 0

    # Look for command as an alias.
    for c in "${commands[@]}"; do
        eval $(get_config_as -a "aliases" "commands.$c.aliases")
        array_has_value__array=(${aliases[@]})
        array_has_value "$command" && echo $c && return 0
    done

    echo $command && return 1
}

##
 # Determine if the script was called with a given option.
 #
function has_option() {
    local option=$1

    array_has_value__array=(${CLOUDY_OPTIONS[@]})
    array_has_value "$1" && return 0
    return 1
}

##
 # Determine if any options were used when calling the script.
 #
function has_options() {
    [ ${#CLOUDY_OPTIONS[@]} -gt 0 ] && return 0
    return 1
}

##
 # Get the value of a given script parameter, if it exists.
 #
function get_option() {
    local param=$1
    local default=$2

    local var_name="\$CLOUDY_OPTION__$(string_upper $1)"
    local value=$(eval "echo $var_name")
    [[ "$value" ]] && echo "$value" && return 0
    echo "$default" && return 2
}

##
 # Search $array_has_value__array for a value.
 #
 # You must provide your array as $array_has_value__array like so:
 # @code
 #   array_has_value__array=("${some_array_to_search[@]}")
 #   array_has "tree" && echo "found tree"
 # @endcode
 #
function array_has_value() {
    local needle="$1"
    local value
    local index=0
    array_has_value__index=null
    for value in "${array_has_value__array[@]}"; do
       [[ "$value" == "$needle" ]] && array_has_value__index=$index && return 0
       let index++
    done
    return 1
}

##
 # Join a stack into an array with delimiter.
 #
 # @code
 #  string_split__string="do<br />re<br />mi"
 #  string_split '<br />' && local words=("${string_split__array}")
 # @endcode
 #
 #
function string_split() {
    local delimiter="$1"

    if [ ${#delimiter} -eq 1 ]; then
        IFS=$delimiter; string_split__array=($string_split__string); unset IFS;
    else
        #http://www.linuxquestions.org/questions/programming-9/bash-shell-script-split-array-383848/#post3270796
        string_split__array=(${string_split__string//$delimiter/ })
    fi
}

##
 # Join a stack into an array with delimiter.
 #
function array_join() {
    local glue="$1"

    local string
    string=$(printf "%s$glue" "${array_join__array[@]}") && string=${string%$glue} || return 1
    echo $string
    return 0
}

##
 # Alphabetically sort a stack.
 #
function array_sort() {
    local IFS=$'\n'
    array_sort__array=($(sort <<< "${array_sort__array[*]}"))
}

##
 # Sort and mutate an array based on length of values.
 #
 # @code
 #  array_sort_by_item_length__array=("september" "five" "three" "on")
 #  array_sort_by_item_length
 # @endcode
 #
function array_sort_by_item_length() {
    local sorted
    local eval=$(php "$CLOUDY_ROOT/php/helpers.php" "array_sort_by_item_length" "sorted" "${array_sort_by_item_length__array[@]}")
    result=$?
    eval $eval
    array_sort_by_item_length__array=("${sorted[@]}")
    return $result
}

##
 # Determine if there are any arguments for the script "command".
 #
function has_command_args() {
    [ ${#CLOUDY_ARGS[@]} -gt 1 ] && return 0
    return 1
}

##
 # Return a operation argument by zero-based index key.
 #
 # As an example see the following code:
 # @code
 #   ./script.sh action blue apple
 #   get_command --> "action"
 #   get_command_arg 0 --> "blue"
 #   get_command_arg 1 --> "apple"
 # @endcode
 #
function get_command_arg() {
    local index=$1
    local default="$2"
    let index=(index + 1)
    [ ${#CLOUDY_ARGS[@]} -gt $index ] && echo  ${CLOUDY_ARGS[$index]} && return 0
    echo $default && return 2
}

##
 # Purges all cached configuration from disk and memory.
 #
 # @todo This may not be needed.
 #
function purge_config() {
    local purge="${CACHED_CONFIG_FILEPATH/.sh/.purge.sh}"

    # remove all variables from memory.
    [ -f "$purge" ] && source "$purge"

    # empty the purge script.
    echo "" > "$purge"

    # empty the set var script.
    echo "" > "${CACHED_CONFIG_FILEPATH}"
}

##
 # Get a config path assignment.
 #
 # @code
 #   eval $(get_config 'path.to.config')
 # @code
 #
 # When requesting an array you must pass -a as the first argument if there's
 # any chance that the return value will be empty.
 #
 # @code
 #   eval $(get_config 'path.to.string' 'default_value')
 #   eval $(get_config -a 'path.to.array' 'default_value')
 # @code
 #
function get_config() {
    local config_path=$1
    local default_value=$2

    parse_args $@
    local config_path="${parse_args__args[0]}"
    local default_value="${parse_args__args[1]}"
    _cloudy_get_config "$config_path" "$default_value" $parse_args__options_passthru
}

##
 # Get config path but assign it's value to a custom variable.
 #
 # @code
 #   eval $(get_config_as 'title' 'path.to.some.title' 'default')
 #   eval $(get_config_as 'title' -a 'path.to.some.array' )
 # @code
 #
function get_config_as() {
    local custom_var_name=$1
    local config_path=$2
    local default_value=$3

    parse_args $@
    local custom_var_name="${parse_args__args[0]}"
    local config_path="${parse_args__args[1]}"
    local default_value="${parse_args__args[2]}"
    _cloudy_get_config "$config_path" "$default_value" --as="$custom_var_name" $parse_args__options_passthru
}

function get_config_keys() {
    local config_key_path="$1"

    _cloudy_get_config -a --keys "$config_key_path"
}

function get_config_keys_as() {
    local custom_var_name=$1
    local config_key_path=$2

    parse_args $@
    custom_var_name="${parse_args__args[0]}"
    config_key_path="${parse_args__args[1]}"
    _cloudy_get_config -a --keys "$config_key_path" "" --as="$custom_var_name"
}

##
 # Return configuration value or values as full path(s) relative to $ROOT.
 #
function get_config_path() {
    local config_key_path=$1
    local default_value=$2

    parse_args $@
    config_key_path="${parse_args__args[0]}"
    local default_value="${parse_args__args[1]}"
    _cloudy_get_config "$config_key_path" "$default_value" --mutator=_cloudy_realpath $parse_args__options_passthru
}

function get_config_path_as() {
    local custom_var_name=$1
    local config_key_path=$2
    local default_value=$3

    parse_args $@
    custom_var_name="${parse_args__args[0]}"
    config_key_path="${parse_args__args[1]}"
    default_value="${parse_args__args[2]}"
    _cloudy_get_config "$config_key_path" "$default_value"  --as="$custom_var_name" --mutator=_cloudy_realpath $parse_args__options_passthru
}

##
 # Translate a message id into $CLOUDY_LANGUAGE.
 #
function translate() {
    local untranslated_message="$1"

    # A faster way to response if no translate.
    [ ${#cloudy_config_keys___translate[@]} -eq 0 ] && echo "$untranslated_message" && return 2

    # Look up the index of the translation id...
    eval $(_cloudy_get_config -a --as=ids "translate.ids")
    array_has_value__array=("${ids[@]}")
    ! array_has_value "$untranslated_message" && echo "$untranslated_message" && return 2

    # Look for a string under that index in the current language.
    eval $(_cloudy_get_config --as=translated "translate.strings.$CLOUDY_LANGUAGE.$array_has_value__index")

    # Echo the translate or the original.
    echo ${translated:-$untranslated_message} && return 0
}

#
# SECTION: User feedback and output
#

##
 # Accept a y/n confirmation message or end
 #
 # @param string $1
 #   A question to ask ending with a '?' mark.  Leave blank for default.
 #
 # @return bool
 #   Sets the value of confirm_result
 #
function confirm() {
    while true; do
        read -r -n 1 -p "${1:-Continue?} [y/n]: " REPLY
        case $REPLY in
            [yY]) echo ; return 0 ;;
            [nN]) echo ; return 1 ;;
            *) printf " \033[31m %s \n\033[0m" "invalid input"
        esac
    done
}

##
 # Echo a string in red.
 #
function echo_red() {
    _cloudy_echo_color 1 "$1";
}

##
 # Echo a string in green.
 #
function echo_green() {
    _cloudy_echo_color 2 "$1";
}

##
 # Echo a string in yellow.
 #
function echo_yellow() {
    _cloudy_echo_color 3 "$1";
}

##
 # Echo a string in blue.
 #
function echo_blue() {
    _cloudy_echo_color 4 "$1";
}

##
 # Print out a headline for a section of user output.
 #
function echo_title() {
    local headline="$1"
    [[ ! "$headline" ]] && return 1
    echo && echo "🔶  $(string_upper "${headline}")" && echo
}

##
 # Print out a headline for a section of user output.
 #
function echo_heading() {
    local headline="$1"
    [[ ! "$headline" ]] && return 1
    echo "🔸  ${headline}"
}

function list_clear() {
    echo_list__array=()
}

function list_add_item() {
    local item="$1"
    echo_list__array=("${echo_list__array[@]}" "$item")
    return 0
}

function list_has_items() {
    [ ${#echo_list__array[@]} -gt 0 ]
}

##
 # Echo an array as a bulletted list.
 #
 # @param $echo_list__array
 #
 # You must add items to your list first:
 # @code
 #   list_add_item "List item"
 #   echo_list
 # @endcode
 #
 # @see echo_list__array=("${some_array_to_echo[@]}")
 #
function echo_list() {
    _cloudy_echo_list
}

##
 # @param $echo_list__array
 #
function echo_red_list() {
    _cloudy_echo_list 1 1
}

##
 # @param $echo_list__array
 #
function echo_green_list() {
    _cloudy_echo_list 2 2
}

##
 # @param $echo_list__array
 #
function echo_yellow_list() {
    _cloudy_echo_list 3 3
}

##
 # @param $echo_list__array
 #
function echo_blue_list() {
    _cloudy_echo_list 4 4
}

##
 # Return the elapsed time in seconds since the beginning of the script.
 #
function echo_elapsed() {
    echo $SECONDS
}

#
# SECTION: Ending the script.
#
# @link https://www.tldp.org/LDP/abs/html/exit-status.html
#

##
 # Implement cloudy common commands and options.
 #
 # An optional set of commands for all scripts.  This is just the handlers,
 # you must still set up the commands in the config file as usual.
 #
function implement_cloudy_basic() {

    # Handle options on any command.
    has_option "h" && exit_with_help $command

    # Handle certain commands.
    case $(get_command) in

        "help")
            exit_with_help $(get_command_arg 0)
            ;;

        "clear-cache")
            exit_with_cache_clear
            ;;

    esac
}
##
 # Empties caches in $CLOUDY_ROOT or other directory if provided.
 #
function exit_with_cache_clear() {
    local cloudy_dir="${1:-$CLOUDY_ROOT}"
    _cloudy_trigger_event "clear_cache" "$cloudy_dir" || exit_with_failure "Clearing caches failed"
    if dir_has_files "$cloudy_dir/cache"; then
        clear=$(rm -rv "$cloudy_dir/cache/"*)
        status=$?
        [ $status -eq 0 ] || exit_with_failure "Could not remove all cached files in $cloudy_dir"
        file_list=($clear)
        for i in "${file_list[@]}"; do
           succeed_because "$(echo_green "$(basename $i)")"
        done
        exit_with_success "Caches have been cleared."
    fi
    exit_with_success "Caches are clear."
}


function exit_with_help() {
    local help_command=$(_cloudy_get_master_command "$1")

    # Focused help_command, show info about single command.
    if [[ "$help_command" ]]; then
        _cloudy_validate_command $help_command || exit_with_failure "No help for that!"
        _cloudy_help_for_single_command $help_command
        exit_with_success "Use just \"help\" to list all commands"
    fi

    # Top-level just show all commands.
    _cloudy_help_commands
    exit_with_success "Use \"help <command>\" for specific info"
}

function exit_with_success() {
    local message=$1
    _cloudy_exit_with_success "$(_cloudy_message "$message" "$CLOUDY_SUCCESS")"
}

function exit_with_success_elapsed() {
    local message=$1
    _cloudy_exit_with_success "$(_cloudy_message "$message" "$CLOUDY_SUCCESS" " in $SECONDS seconds.")"
}

##
 # Add a warning message to be shown on exit.
 #
function warn_because() {
    local message=$1
    [[ "$message" ]] || return 1
    message=$(echo_yellow "$(_cloudy_message "$message")")
    [[ "$message" ]] && CLOUDY_SUCCESSES=("${CLOUDY_SUCCESSES[@]}" "$message")
}

##
 # Add a success message to be shown on exit.
 #
function succeed_because() {
    local message=$1
    [[ "$message" ]] || return 1
    message=$(_cloudy_message "$message")
    CLOUDY_EXIT_STATUS=0
    [[ "$message" ]] && CLOUDY_SUCCESSES=("${CLOUDY_SUCCESSES[@]}" "$message")
}

##
 # Checks for a non-empty variable in memory or exist with failure.
 #
 # Asks the user to add to their configuration filepath.
 #
 # @param string
 #   This should be the same as passed to get_config, using dot separation.
 #
function exit_with_failure_if_empty_config() {
    parse_args $@
    if [[ "$parse_args__option__status" ]]; then
      CLOUDY_EXIT_STATUS=$parse_args__option__status
    fi
    local variable=${1//./_}

    local code=$(echo_blue "eval \$(get_config_path \"$variable\")")
    local config_name=$(echo_blue "$variable")

    [[ ! "$(eval "echo \$$variable")" ]] && exit_with_failure "Failed due to missing configuration; please add $config_name $(echo_red "to your configuration in $CONFIG.  Also, make sure it is being read into memory with") $code"
    return 0
}

##
 # @option --status=N Optional, set the exit status, a number > 0
 #
function exit_with_failure() {
    parse_args $@

    echo && echo_red "🔥  $(_cloudy_message "$1" "$CLOUDY_FAILED")"

    ## Write out the failure messages if any.
    if [ ${#CLOUDY_FAILURES[@]} -gt 0 ]; then
        echo_list__array=("${CLOUDY_FAILURES[@]}")
        echo_red_list
        for i in "${CLOUDY_FAILURES[@]}"; do
           write_log_error "Failed because: $i"
        done
    fi

    echo

    if [ $CLOUDY_EXIT_STATUS -lt 2 ]; then
      CLOUDY_EXIT_STATUS=1
    fi

    if [[ "$parse_args__option__status" ]]; then
      CLOUDY_EXIT_STATUS=$parse_args__option__status
    fi

    _cloudy_exit
}

##
 # Set the exit status to fail with no message.  Does not stop execution.
 #
 # Try not to use this because it gives no indication as to why
 #
 # @option --status=N Optional, set the exit status, a number > 0
 #
 # @see exit_with_failure
 #
function fail() {
    parse_args $@
    if [[ "$parse_args__option__status" ]]; then
      CLOUDY_EXIT_STATUS=$parse_args__option__status && return 0
    fi
    CLOUDY_EXIT_STATUS=1 && return 0
}

##
 # Add a failure message to be shown on exit.
 #
function fail_because() {
    local message=$1
    fail $@
    if [[ "$message" ]]; then
        CLOUDY_FAILURES=("${CLOUDY_FAILURES[@]}" "$message")
    fi
}

function has_failed() {
    [ $CLOUDY_EXIT_STATUS -gt 0 ] && return 0
    return 1
}

##
 # Echo the host portion an URL.
 #
function url_host() {
    local url_path="$1"
    echo "$url_path" | awk -F/ '{print $3}'
}

#
# Filepaths
#

##
 # Expand a relative path using $ROOT as base.
 #
 # If the path begins with / it is unchanged.
 #
function path_relative_to_root() {
    local path=$1
    [[ "${path:0:1}" != '/' ]] && path="$ROOT/$path"
    echo $path
}

##
 # Return the basename less the extension.
 #
function path_filename() {
    local path=$1

    filename=$(basename "$path")
    echo "${filename%.*}"
}

##
 # Return the extension of a file.
 #
function path_extension() {
    local path=$1

    echo "${path##*.}"
}

function string_upper() {
    local string="$1"

    echo "$string" | tr [a-z] [A-Z]
}

function string_lower() {
    local string="$1"

    echo "$string" | tr [A-Z] [a-z]
}

#
# Development
#

##
 # Echo the arguments sent to this is an eye-catching manner.
 #
 # Call as in the example below for better tracing.
 # @code
 #   debug "Some message to show|$0|$FUNCNAME|$LINENO"
 # @endcode
 #
function debug() {
    _cloudy_debug_helper "Debug;3;0;$@"
}

function echo_key_value() {
    local key=$1
    local value=$2
    echo "$(tput setaf 0)$(tput setab 7) $key $(tput smso) "$value" $(tput sgr0)"
}

##
 # Echo an exception message and exit.
 #
function throw() {
    _cloudy_debug_helper "Exception;1;7;$@"
    exit 3
}

##
 # @link https://www.php-fig.org/psr/psr-3/
 #
function write_log_emergency() {
    local args=("emergency" "$@")
    _cloudy_write_log ${args[@]}
}

##
 # You may include 1 or two arguments; when 2, the first is a log label
 #
function write_log() {
    local arbitrary_log_label=$1

    local args=("$@")
    if [ $# -eq 1 ]; then
        args=("log" "${args[@]}")
    fi
    _cloudy_write_log ${args[@]}
}

function write_log_alert() {
    local args=("alert" "$@")
    _cloudy_write_log ${args[@]}
}

function write_log_critical() {
    local args=("critical" "$@")
    _cloudy_write_log ${args[@]}
}

function write_log_error() {
    local args=("error" "$@")
    _cloudy_write_log ${args[@]}
}

function write_log_warning() {
    local args=("warning" "$@")
    _cloudy_write_log ${args[@]}
}

##
 # Log states that should only be thus during development or debugging.
 #
 # Adds a "... in dev only message to your warning"
 #
function write_log_dev_warning() {
    local args=("warning" "$@")
    _cloudy_write_log "${args[@]}  This should only be the case for development/debugging."
}

function write_log_notice() {
    local args=("notice" "$@")
    _cloudy_write_log ${args[@]}
}

function write_log_info() {
    local args=("info" "$@")
    _cloudy_write_log ${args[@]}
}

function write_log_debug() {
    local args=("debug" "$@")
    _cloudy_write_log ${args[@]}
}

##
 # Send any number of arguments, each is a column value for a single row.
 #
function table_set_header() {
    _cloudy_table_header=()
    i=0
    for cell in "$@"; do
        if [[ ${#cell} -gt "${_cloudy_table_col_widths[$i]}" ]]; then
            _cloudy_table_col_widths[$i]=${#cell}
        fi
        _cloudy_table_header=("${_cloudy_table_header[@]}" "$cell")
        let i++
    done
}

function table_clear() {
    _cloudy_table_rows=()
}

function table_has_rows() {
    [ ${#_cloudy_table_rows[@]} -gt 0 ]
}

##
 # Send any number of arguments, each is a column value for a single row.
 #
function table_add_row() {
    array_join__array=()
    i=0
    for cell in "$@"; do
        if [[ ${#cell} -gt "${_cloudy_table_col_widths[$i]}" ]]; then
            _cloudy_table_col_widths[$i]=${#cell}
        fi
        array_join__array=("${array_join__array[@]}" "$cell")
        let i++
    done

    _cloudy_table_rows=("${_cloudy_table_rows[@]}" "$(array_join '|')")
}

function string_repeat() {
    local string="$1"
    local repetitions=$2
    for ((i=0; i < $repetitions; i++)){ echo -n "$string"; }
}

function echo_slim_table() {
    _cloudy_echo_aligned_columns --lpad=1 --top="" --lborder="" --mborder=":" --rborder=""
}
function echo_table() {
    _cloudy_echo_aligned_columns --lpad=1 --top="-" --lborder="|" --mborder="|" --rborder="|"
}

#
# End Public API
#

# Begin Cloudy Core Bootstrap
SCRIPT="$s";ROOT="$r";WDIR="$PWD";s="${BASH_SOURCE[0]}";while [ -h "$s" ];do dir="$(cd -P "$(dirname "$s")" && pwd)";s="$(readlink "$s")";[[ $s != /* ]] && s="$dir/$s";done;CLOUDY_ROOT="$(cd -P "$(dirname "$s")" && pwd)";source "$CLOUDY_ROOT/inc/cloudy.core.sh" || exit_with_failure "Missing cloudy/inc/cloudy.core.sh"
