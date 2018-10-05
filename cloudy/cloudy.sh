#!/usr/bin/env bash

# Prompt for a Y or N confirmation.
#
# $1 - The confirmation message
# --caution - Use when answering Y requires caution.
# --danger - Use when answering Y is a dangerous thing.
#
# Returns 0 if the user answers Y; 1 if not.
function confirm() {
    local message="$1"

    parse_args "$@"
    local message="${parse_args__args:-Continue?} [y/n]:"
    [[ "$parse_args__options__caution" ]] && message=$(echo_warning "$message")
    [[ "$parse_args__options__danger" ]] && message=$(echo_error "$message")
    while true; do
        read -r -n 1 -p "$message " REPLY
        case $REPLY in
            [yY]) echo; echo; return 0 ;;
            [nN]) echo; echo; return 1 ;;
            *) printf " \033[31m %s \n\033[0m" "invalid input"
        esac
    done
}

# Determine if a given directory has any files in it.
#
# $1 - The path to a directory to check
#
# Returns 0 if the path contains non-hidden files or 1 if not.
function dir_has_files() {
    local path_to_dir="$1"

    [ -d "$path_to_dir" ] && [[ "$(ls "$path_to_dir")" ]]
}

# Echo the title as defined in the configuration.
#
# $1 - A default value if no title is defined.
#
# Returns nothing.
function get_title() {
    local default="$1"

    local title
    eval $(get_config "title" "$default")
    echo $title
}

# Echos the version of the script.
#
# Returns nothing.
function get_version() {
    local version
    eval $(get_config "version" "1.0")
    echo $version
}

# Echo the current unix timestamp.
#
# Returns nothing.
function timestamp() {
    echo $(date +%s)
}

# Return the current datatime in ISO8601 in UTC.
#
# options -
#   -c - Remove hyphens and colons for use in a filename
#
# Returns 0 if .
function date8601() {
    parse_args "$@"
    if [[ "$parse_args__options__c" ]]; then
        echo $(date -u +%Y%m%dT%H%M%S)
    else
        echo $(date -u +%Y-%m-%dT%H:%M:%S)
    fi
    return 0
}

# Validate the CLI input arguments and options.
#
# Returns 0 if all input is valid; 1 otherwise.
function validate_input() {
    local command

    [[ "$CLOUDY_CONFIG_JSON" ]] || fail_because "$FUNCNAME() cannot be called if \$CLOUDY_CONFIG_JSON is empty."

    command=$(get_command)

    # Assert only defined operations are valid.
    [[ "$command" ]] && _cloudy_validate_command $command && _cloudy_validate_command_arguments $command

    # Assert only defined options for a given op.
    _cloudy_get_valid_operations_by_command $command

    for name in "${CLOUDY_OPTIONS[@]}"; do
       array_has_value__array=(${_cloudy_get_valid_operations_by_command__array[@]})
       array_has_value $name || fail_because "Invalid option: $name"
       eval "value=\"\$CLOUDY_OPTION__$(string_upper $name)\""

       # Assert the provided value matches schema.
       eval $(_cloudy_validate_input_against_schema "commands.$command.options.$name" "$name" "$value")
       if [[ "$schema_errors" ]]; then
            for error in "${schema_errors[@]}"; do
               fail_because "$error"
            done
       fi
    done

    has_failed && return 1
    return 0
}

# Parses arguments into options, args and option values.
#
# Use this in your my_func function: parse_args "$@"
#
# The following variables are generated for:
# @code
#   my_func -ab --tree=life do re
# @endcode
#
# - parse_args__args=(do re)
# - parse_args__options=(a b tree)
# - parse_args__options__a=true
# - parse_args__options__b=true
# - parse_args__options__tree=life
# - parse_args__options_passthru="-a -b -tree=life"
#
function parse_args() {
    local name
    local value

    # Purge any previous values.
    for name in "${parse_args__options[@]}"; do
        eval "unset parse_args__options__${name}"
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
            eval "parse_args__options__${name}=\"${value}\""
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
                eval "parse_args__options__${name}=true"
                parse_args__options_passthru="$parse_args__options_passthru -${name}"
            done
        fi
    done
}

# Determine if the script was called with a command.
#
# Returns 0 if a command was used.
function has_command() {
  [ ${#CLOUDY_ARGS[0]} -gt 0 ]
}

# Echo the command that was used to call the script.
#
# Returns 0 if a valid command, 1 otherwise.
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

# Determine if the script was called with a given option.
#
# $1 - The option to check for.
#
# Returns 0 if the option was used; 1 if not.
function has_option() {
    local option=$1

    array_has_value__array=(${CLOUDY_OPTIONS[@]})
    array_has_value "$1" && return 0
    return 1
}

# Determine if any options were used when calling the script.
#
# Returns 0 if at least one option was used; 1 otherwise.
function has_options() {
    [ ${#CLOUDY_OPTIONS[@]} -gt 0 ] && return 0
    return 1
}

# Echo the value of a script option, or a default.
#
# $1 - The name of the option
# $2 - A default value if the option was not used.
#
# Returns 0 if the option was used; 2 if the default is echoed.
function get_option() {
    local param=$1
    local default=$2

    local var_name="\$CLOUDY_OPTION__$(string_upper $1)"
    local value=$(eval "echo $var_name")
    [[ "$value" ]] && echo "$value" && return 0
    echo "$default" && return 2
}

# Search $array_has_value__array for a value.
#
# array_has_value__array
#
# $1 - The value to search for in array.
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

# Split a string by a delimiter.
#
# string_split__string
# string_split__array
#
# @code
#  string_split__string="do<br />re<br />mi"
#  string_split '<br />' && local words=("${string_split__array}")
# @endcode
#
# $1 - The delimiter string.
#
# Returns 0 if .
function string_split() {
    local delimiter="$1"

    if [ ${#delimiter} -eq 1 ]; then
        IFS=$delimiter; string_split__array=($string_split__string); unset IFS;
    else
        #http://www.linuxquestions.org/questions/programming-9/bash-shell-script-split-array-383848/#post3270796
        string_split__array=(${string_split__string//$delimiter/ })
    fi
}

# Echo a string, which is an array joined by a substring.
#
# array_join__array
#
# $1 - The string to use to glue the pieces together with.
#
# Returns 0 if all goes well; 1 on failure.
function array_join() {
    local glue="$1"

    local string
    string=$(printf "%s$glue" "${array_join__array[@]}") && string=${string%$glue} || return 1
    echo $string
    return 0
}

# Mutate an array sorting alphabetically.
#
# array_sort__array
#
# Returns nothing.
function array_sort() {
    local IFS=$'\n'
    array_sort__array=($(sort <<< "${array_sort__array[*]}"))
}

# Mutate an array sorting by the length of each item, short ot long
#
# array_sort__array
#
# @code
#  array_sort_by_item_length__array=("september" "five" "three" "on")
#  array_sort_by_item_length
# @endcode
#
# Returns 0 on success; 1 on failure.
function array_sort_by_item_length() {
    local sorted
    local eval=$(php "$CLOUDY_ROOT/php/helpers.php" "array_sort_by_item_length" "sorted" "${array_sort_by_item_length__array[@]}")
    result=$?
    eval $eval
    array_sort_by_item_length__array=("${sorted[@]}")
    return $result
}

# Determine if there are any arguments for the script "command".
#
# Returns 0 if the command has any arguments; 1 if not.
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

    parse_args "$@"
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

    parse_args "$@"
    local custom_var_name="${parse_args__args[0]}"
    local config_path="${parse_args__args[1]}"
    local default_value="${parse_args__args[2]}"
    _cloudy_get_config "$config_path" "$default_value" --as="$custom_var_name" $parse_args__options_passthru
}

# Echos eval code for the keys of a configuration associative array.
#
# $1 - The path to the config item, e.g. "files.private"
#
# Returns 0 on success.
function get_config_keys() {
    local config_key_path="$1"

    _cloudy_get_config -a --keys "$config_key_path"
}

# Echo eval code for keys of a configuration associative array using custom var.
#
# $1 - The path to the config item, e.g. "files.private"
#
# Returns 0 on success.
function get_config_keys_as() {
    local custom_var_name=$1
    local config_key_path=$2

    parse_args "$@"
    custom_var_name="${parse_args__args[0]}"
    config_key_path="${parse_args__args[1]}"
    _cloudy_get_config -a --keys "$config_key_path" "" --as="$custom_var_name"
}

# Echo eval code for paths of a configuration item.
#
# $1 - The path to the config item, e.g. "files.private"
# -a - If you are expecting an array
#
# Returns 0 on success.
function get_config_path() {
    local config_key_path=$1
    local default_value=$2

    parse_args "$@"
    config_key_path="${parse_args__args[0]}"
    local default_value="${parse_args__args[1]}"
    _cloudy_get_config "$config_key_path" "$default_value" --mutator=_cloudy_realpath $parse_args__options_passthru
}

# Echo eval code for paths of a configuration item using custom var.
#
# $1 - The path to the config item, e.g. "files.private"
# -a - If you are expecting an array
#
# Returns 0 on success.
function get_config_path_as() {
    local custom_var_name=$1
    local config_key_path=$2
    local default_value=$3

    parse_args "$@"
    custom_var_name="${parse_args__args[0]}"
    config_key_path="${parse_args__args[1]}"
    default_value="${parse_args__args[2]}"
    _cloudy_get_config "$config_key_path" "$default_value"  --as="$custom_var_name" --mutator=_cloudy_realpath $parse_args__options_passthru
}

# Echo the translation of a message id into $CLOUDY_LANGUAGE.
#
# $1 - The untranslated message.
#
# Returns 0 if translated; 2 if not translated.
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

# Echo a string with white text.
#
# $1 - The string to echo.
#
# Returns nothing.
function echo_white() {
    _cloudy_echo_color 37 "$1"
}

# Echo a string with red text.
#
# $1 - The string to echo.
#
# Returns nothing.
function echo_red() {
    _cloudy_echo_color 31 "$1"
}

# Echo a string with a red background.
#
# $1 - The string to echo.
#
# Returns nothing.
function echo_red_highlight() {
    _cloudy_echo_color 37 "$1" 1 41
}

# Echo an error message
#
# $1 - The error message.
#
# Returns nothing.
function echo_error() {
    _cloudy_echo_color 37 "$1" 1 41
}

# Echo a warning message
#
# $1 - The warning message.
#
# Returns nothing.
function echo_warning() {
    _cloudy_echo_color 30 "$1" 1 43
}

# Echo a string with green text.
#
# $1 - The string to echo.
#
# Returns nothing.
function echo_green() {
    _cloudy_echo_color 32 "$1" 0
}

# Echo a string with yellow text.
#
# $1 - The string to echo.
#
# Returns nothing.
function echo_yellow() {
    _cloudy_echo_color 33 "$1" 0
}

# Echo a string with a yellow background.
#
# $1 - The string to echo.
#
# Returns nothing.
function echo_yellow_highlight() {
    _cloudy_echo_color 30 "$1" 1 43
}

# Echo a string with blue text.
#
# $1 - The string to echo.
#
# Returns nothing.
function echo_blue() {
    _cloudy_echo_color 34 "$1" 0
}

# Echo a title string.
#
# $1 - The title string.
#
# Returns nothing.
function echo_title() {
    local headline="$1"
    [[ ! "$headline" ]] && return 1
    echo && echo "🔶  $(string_upper "${headline}")" && echo
}

# Echo a heading string.
#
# $1 - The heading string.
#
# Returns nothing.
function echo_heading() {
    local headline="$1"
    [[ ! "$headline" ]] && return 1
    echo "🔸  ${headline}"
}

# Remove all items from the list.
#
# Returns nothing
function list_clear() {
    echo_list__array=()
}

# Add an item to the list.
#
# echo_list__array
#
# $1 - The string to add as a list item.
#
# Returns nothing.
function list_add_item() {
    local item="$1"
    echo_list__array=("${echo_list__array[@]}" "$item")
}

# Detect if the list has any items.
#
# Returns 0 if the list has at least one item.
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
    _cloudy_echo_list 31 31
}

##
 # @param $echo_list__array
 #
function echo_green_list() {
    _cloudy_echo_list 32 32 -i=0
}

##
 # @param $echo_list__array
 #
function echo_yellow_list() {
    _cloudy_echo_list 33 33 i=0
}

##
 # @param $echo_list__array
 #
function echo_blue_list() {
    _cloudy_echo_list 34 34 -i=0
}

# Echo the elapsed time in seconds since the beginning of the script.
#
# Returns nothing.
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

# Performs an initialization (setup default config, etc.)
#
# You must set up an init command in your core config file.
# Then call this function from inside `on_pre_config`, e.g.
# [[ "$(get_command)" == "init" ]] && exit_with_init
# The translation service is not yet bootstrapped in on_pre_config, so if you
# want to alter the strings printed you can do something like this:
# if [[ "$(get_command)" == "init" ]]; then
#     CLOUDY_FAILED="Initialization failed."
#     CLOUDY_SUCCESS="Initialization complete."
#     exit_with_init
# fi
#
# Returns nothing.
function exit_with_init() {
    local path_to_files_map="$ROOT/init/cloudypm.files_map.txt"
    [ -f "$path_to_files_map" ] || fail_because "Missing required initialization file: $path_to_files_map."

    local init_source_dir="$ROOT/init"
    [ -d "$init_source_dir" ] || fail_because "Missing initialization source directory: $init_source_dir"
    local from_map=()
    local to_map=()
    local init_config_dir
    local from
    local to

    while read -r from to || [[ -n "$line" ]]; do
        if [[ "$from" == "*" ]]; then
            to="${to%\*}"
            init_config_dir="${to%/}"
        else
            from_map=("${from_map[@]}" "$from")
            to_map=("${to_map[@]}" "$to")
        fi
    done < $path_to_files_map

    [[ "$init_config_dir" ]] || fail_because "Missing default initialization directory; should be defined in: $(basename $path_to_files_map)."

    if ! has_failed; then
        for file in $(ls $init_source_dir); do
            [[ "$file" == cloudypm* ]] && continue
            destination=$(path_relative_to_root "$init_config_dir/$file")
            local i=0
            for special_file in "${from_map[@]}"; do
               if [[ "$special_file" == "$file" ]];then
                    destination=$(path_relative_to_root ${to_map[$i]})
               fi
               let i++
            done
            if [[ "$file" == "gitignore" ]]; then
                destination=$(realpath "$ROOT/../../../opt/.gitignore")
                [ -d $(dirname "$destination") ] || mkdir -p $(dirname $destination)
                # todo This will write more than once, so this is not very elegant.  Should figure that out somehow.
                touch "$destination" && cat "$init_source_dir/$file" >> "$destination" && succeed_because "$destination merged."
            elif ! [ -e "$destination" ]; then
                [ -d $(dirname "$destination") ] || mkdir -p $(dirname $destination)
                cp "$init_source_dir/$file" "$destination" && succeed_because "$(realpath $destination) created." || fail_because "Could not copy $file."
            fi
        done
    fi
    has_failed && exit_with_failure "${CLOUDY_FAILED:-Initialization failed.}"
    exit_with_success "${CLOUDY_SUCCESS:-Initialization complete.}"
}

##
 # Empties caches in $CLOUDY_ROOT (or other directory if provided) and exits.
 #
 # Returns nothing.
 #
function exit_with_cache_clear() {
    local cloudy_dir="${1:-$CLOUDY_ROOT}"
    event_dispatch "clear_cache" "$cloudy_dir" || exit_with_failure "Clearing caches failed"
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

# Echo the help screen and exit.
#
# Return 0 on success; 1 otherwise.
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

# Echo a success message plus success reasons and exit
#
# $1 - The success message to use.
#
# Returns 0.
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

# Add a success reason to be shown on exit.
#
# $1 - The success reason.
#
# Returns 1 if the message is empty; 0 otherwise.
function succeed_because() {
    local message=$1

    [[ "$message" ]] || return 1
    message=$(_cloudy_message "$message")
    CLOUDY_EXIT_STATUS=0
    [[ "$message" ]] && CLOUDY_SUCCESSES=("${CLOUDY_SUCCESSES[@]}" "$message")
}

# Test a global config variable to see if it points to an existing path.
#
# $1 - The config path, used by get_config
#
# Returns 0 if the variable exists and points to a file; exits otherwise with 1.
function exit_with_failure_if_config_is_not_path() {
    local config_path="$1"

    parse_args "$@"
    if [[ "$parse_args__options__status" ]]; then
      CLOUDY_EXIT_STATUS=$parse_args__options__status
    fi
    local variable=${config_path//./_}
    if [[ "$parse_args__options__as" ]]; then
        variable="$parse_args__options__as"
    fi

    local code=$(echo_blue "eval \$(get_config_path \"$variable\")")
    local config_name=$(echo_blue "$config_path")
    local config_value="$(eval "echo \$$variable")"

    exit_with_failure_if_empty_config $@

    # Make sure it's a path.
    [ ! -e "$config_value" ] && exit_with_failure "Failed because the path \"$config_value\" , does not exist; defined in configuration as $config_name."

    return 0
}

##
 # Checks for a non-empty variable in memory or exist with failure.
 #
 # Asks the user to add to their configuration filepath.
 #
 # @param string
 #   This should be the same as passed to get_config, using dot separation.
 # @option as=name
 #   If the configuration has been renamed, send the memory var name --as=varname.
 #
function exit_with_failure_if_empty_config() {
    parse_args "$@"
    if [[ "$parse_args__options__status" ]]; then
      CLOUDY_EXIT_STATUS=$parse_args__options__status
    fi
    local variable=${1//./_}
    if [[ "$parse_args__options__as" ]]; then
        variable="$parse_args__options__as"
    fi

    local code=$(echo_blue "eval \$(get_config_path \"$variable\")")
    local config_name=$(echo_blue "$variable")

    [[ ! "$(eval "echo \$$variable")" ]] && exit_with_failure "Failed due to missing configuration; please add $config_name $(echo_red "to your configuration in $CONFIG.  Also, make sure it is being read into memory with") $code"
    return 0
}

##
 # @option --status=N Optional, set the exit status, a number > 0
 #
function exit_with_failure() {
    parse_args "$@"

    [ $CLOUDY_EXIT_STATUS -lt 2 ] && CLOUDY_EXIT_STATUS=1
    CLOUDY_EXIT_STATUS=${parse_args__options__status:-$CLOUDY_EXIT_STATUS}

    echo && echo_error "🔥  $(_cloudy_message "${parse_args__args[@]}" "$CLOUDY_FAILED")"

    ## Write out the failure messages if any.
    if [ ${#CLOUDY_FAILURES[@]} -gt 0 ]; then
        echo_list__array=("${CLOUDY_FAILURES[@]}")
        echo_red_list
        for i in "${CLOUDY_FAILURES[@]}"; do
           write_log_error "Failed because: $i"
        done
    fi

    echo

    _cloudy_exit
}

# Test if a program is installed on the system.
#
# $1 - The name of the program to check for.
#
# Returns 0 if installed; 1 otherwise.
function is_installed() {
    local command=$1

    get_installed $command > /dev/null
    return $?
}

# Echo the path to an installed program.
#
# $1 - The name of the program you need.
#
# Returns 0 if .
function get_installed() {
    local command=$1

    command -v $command 2>/dev/null
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
    parse_args "$@"
    if [[ "$parse_args__options__status" ]]; then
      CLOUDY_EXIT_STATUS=$parse_args__options__status && return 0
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

# Determine if any failure reasons have been defined yet.
#
# Returns 0 if one or more failure messages are present; 1 if not.
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

##
 # Add a cache-busting timestamp to an URL and echo the new url.
 #
function url_add_cache_buster() {
    local url="$1"

    if [[ $url == *"?"* ]]; then
        url="$url&$(date +%s)"
    else
        url="$url?$(date +%s)"
    fi
    echo $url
}

##
 # Dispatch that an event has occurred to all listeners.
 #
 # Additional arguments beyond $1 are passed on to the listeners.
 #
function event_dispatch() {
    local event_id=$1

    # Protect us from recursion.
    if [[ "$event_dispatch__event" ]] && [[ "$event_dispatch__event" == "$event_id" ]]; then
        write_log_error "Tried to dispatch $event_id while currently dispatching $event_id."
        return
    fi
    event_dispatch__event=$event_id

    shift
    local args
    local varname="_cloudy_event_listen__${event_id}__array"
    local listeners=$(eval "echo "\$$varname"")
    local has_on_event=false

    for value in "${listeners[@]}"; do
       [[ "$value" == "on_${event_id}" ]] && has_on_event=true && break
    done
    [[ "$has_on_event" == false ]] && listeners=("${listeners[@]}" "on_${event_id}")

    for listener in ${listeners[@]}; do
        _cloudy_trigger_event "$event_id" "$listener" "$@"
    done
    unset event_dispatch__event
}

##
 # Register an event listener.
 #
function event_listen() {
    local event_id="$1"
    local callback="${2:-on_$1}"

    local varname="_cloudy_event_listen__${event_id}__array"
    local listeners=$(eval "echo "\$$varname"")

    # Prevent multiple listeners of the same name.
    for value in "${listeners[@]}"; do
       [[ "$value" == "$callback" ]] && throw "Listener $callback has already been added; you must provide a different function name;$0;$FUNCNAME;$LINENO"
    done

    eval "$varname=(\"\${$varname[@]}\" $callback)"
}

#
# Filepaths
#

##
 # Echo a path relative to config_path_base.
 #
 # If the path begins with / it is unchanged.
 #
function path_relative_to_config_base() {
    local path=$1

    local config_path_base=${cloudy_config___config_path_base}
    [[ "${config_path_base:0:1}" != '/' ]] && config_path_base="${ROOT}/$config_path_base"
    config_path_base=${config_path_base%/}
    [[ "${path:0:1}" != '/' ]] && path="$config_path_base/$path"
    echo $path
}

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

##
 # Define realpath if it's not defined.
 #
type realpath >/dev/null 2>&1
if [ $? -gt 0 ]; then
    function realpath() {
         readlink -f -- "$@"
    }
fi

##
 # Create and echo a new temp directory.
 #
function tempdir() {
    mktemp -d 2>/dev/null || mktemp -d -t 'temp'
}

# Echo the uppercase version of a string.
#
# $1 - The string to convert to uppercase.
#
# Returns nothing.
function string_upper() {
    local string="$1"

    echo "$string" | tr [a-z] [A-Z]
}

# Echo the lowercase version of a string.
#
# $1 - The string to convert to lowercase.
#
# Returns nothing.
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

# $DESCRIPTION
#
# $1 - $PARAM$
#
# Returns 0 if $END$.
function echo_key_value() {
    local key=$1
    local value=$2
    echo "$(tput setaf 0)$(tput setab 7) $key $(tput smso) "$value" $(tput sgr0)"
}

# Echo an exception message and exit.
#
# Returns 3.
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

# Writes a log message using the alert level.
#
# $@ - Any number of strings to write to the log.
#
# Returns 0 on success or 1 if the log cannot be written to.
function write_log_alert() {
    local args=("alert" "$@")
    _cloudy_write_log ${args[@]}
}

# Write to the log with level critical.
#
# $1 - The message to write.
#
# Returns 0 on success.
function write_log_critical() {
    local args=("critical" "$@")
    _cloudy_write_log ${args[@]}
}

# Write to the log with level error.
#
# $1 - The message to write.
#
# Returns 0 on success.
function write_log_error() {
    local args=("error" "$@")
    _cloudy_write_log ${args[@]}
}

# Write to the log with level warning.
#
# $1 - The message to write.
#
# Returns 0 on success.
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

# Write to the log with level notice.
#
# $1 - The message to write.
#
# Returns 0 on success.
function write_log_notice() {
    local args=("notice" "$@")
    _cloudy_write_log ${args[@]}
}

# Write to the log with level info.
#
# $1 - The message to write.
#
# Returns 0 on success.
function write_log_info() {
    local args=("info" "$@")
    _cloudy_write_log ${args[@]}
}

# Write to the log with level debug.
#
# $1 - The message to write.
#
# Returns 0 on success.
function write_log_debug() {
    local args=("debug" "$@")
    _cloudy_write_log ${args[@]}
}

# Set the column headers for a table.
#
# $@ - Each argument is the column header value.
#
# Returns nothing.
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

# Clear all rows from the table definition.
#
# Returns nothing.
function table_clear() {
    _cloudy_table_rows=()
}

# Determine if the table definition has any rows.
#
# Returns 0 if one or more rows in the definition; 1 if table is empty.
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

# Repeat a string N times.
#
# $1 - The string to repeat.
# $2 - The number of repetitions.
#
# Returns nothing.
function string_repeat() {
    local string="$1"
    local repetitions=$2
    for ((i=0; i < $repetitions; i++)){ echo -n "$string"; }
}

# Echo a slim version of the table as it's been defined.
#
# Returns nothing.
function echo_slim_table() {
    _cloudy_echo_aligned_columns --lpad=1 --top="" --lborder="" --mborder=":" --rborder=""
}

# Echo the table as it's been defined.
#
# Returns nothing.
function echo_table() {
    _cloudy_echo_aligned_columns --lpad=1 --top="-" --lborder="|" --mborder="|" --rborder="|"
}

#
# End Public API
#

# Begin Cloudy Core Bootstrap
SCRIPT="$s";ROOT="$r";WDIR="$PWD";s="${BASH_SOURCE[0]}";while [ -h "$s" ];do dir="$(cd -P "$(dirname "$s")" && pwd)";s="$(readlink "$s")";[[ $s != /* ]] && s="$dir/$s";done;CLOUDY_ROOT="$(cd -P "$(dirname "$s")" && pwd)";source "$CLOUDY_ROOT/inc/cloudy.core.sh" || exit_with_failure "Missing cloudy/inc/cloudy.core.sh"
