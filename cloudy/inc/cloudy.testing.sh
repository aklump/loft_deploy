#!/usr/bin/env bash

# Perform all tests in a file.
#
# $1 - The path to a test file.
#
# Returns 0 if all tests pass; 1 otherwise.
function do_tests_in() {
    local CLOUDY_ACTIVE_TESTFILE=$(path_relative_to_root "$1")

    CLOUDY_ASSERTION_COUNT=0
    CLOUDY_TEST_COUNT=0
    CLOUDY_FAILED_ASSERTION_COUNT=0
    CLOUDY_SKIPPED_TESTS_COUNT=0

    [ ! -f "$CLOUDY_ACTIVE_TESTFILE" ] && fail_because "Test file: \"$CLOUDY_ACTIVE_TESTFILE\" not found." && return 1

    source $CLOUDY_ACTIVE_TESTFILE

    declare -a local tests=();

    # Find all functions in a given test file.
    local data=($(grep "^\s*function test*" $CLOUDY_ACTIVE_TESTFILE))
    for i in "${data[@]}"; do
        if [[ "${i:0:4}" == "test" ]]; then
        tests=("${tests[@]}" "${i/%()/}")
        fi
    done

    local duplicates=($(printf '%s\n' "${tests[@]}"|awk '!($0 in seen){seen[$0];next} 1'))
    if [ ${#duplicates[@]} -gt 0 ]; then
        for duplicate in "${duplicates[@]}"; do
           fail_because "Duplicated test function \"$duplicate\"."
        done
        exit_with_failure "Tests failed due to code problems."
    fi

    for CLOUDY_ACTIVE_TEST in "${tests[@]}"; do
        if [[ "$(type -t $CLOUDY_ACTIVE_TEST)" != "function" ]]; then
          fail_because "Test not found: $CLOUDY_ACTIVE_TEST"
        else
            let CLOUDY_TEST_COUNT=(CLOUDY_TEST_COUNT + 1)
            [ "$(type -t 'setup_before_test')" = "function" ] && setup_before_test
            $CLOUDY_ACTIVE_TEST
            [ "$(type -t 'teardown_after_test')" = "function" ] && teardown_after_test
        fi
    done

    has_failed && return 1
    return 0
}

# Mark a single test as skipped
#
# Returns nothing.
function mark_test_skipped() {
    warn_because "Skipped test: $CLOUDY_ACTIVE_TEST"
    let CLOUDY_SKIPPED_TESTS_COUNT=(CLOUDY_SKIPPED_TESTS_COUNT + 1)
}

# Echo test results and exit.
#
# Returns 0 if all tests pass; 1 otherwise.
function exit_with_test_results() {
    _cloudy_echo_credits
    echo_title "Test Results"
    echo "Runtime: BASH $BASH_VERSION"
    echo
    echo

    [ $CLOUDY_TEST_COUNT -eq 0 ] && echo_key_value "?" "No tests found."
    [ $CLOUDY_ASSERTION_COUNT -eq 0 ] && echo_key_value "?" "No assertions found."

    [ $CLOUDY_TEST_COUNT -eq 0 ] || [ $CLOUDY_ASSERTION_COUNT -eq 0 ] && echo

    echo "Time: $SECONDS seconds" && echo

    if ! has_failed; then
        echo "OK (${CLOUDY_TEST_COUNT} tests, ${CLOUDY_ASSERTION_COUNT} assertions)"
        exit_with_success "All tests passed."
    fi

    local stats="Tests: ${CLOUDY_TEST_COUNT}, Assertions: ${CLOUDY_ASSERTION_COUNT}, Failures: ${CLOUDY_FAILED_ASSERTION_COUNT}"
    [ $CLOUDY_SKIPPED_TESTS_COUNT -gt 0 ] && stats="$stats, Skipped: $CLOUDY_SKIPPED_TESTS_COUNT"

    echo "$stats."

    exit_with_failure "Some failures occurred"
}

# Assert that variable by name is empty.
#
# $1 - The name of a global variable.
#
# Returns 0 if assertion is true; 1 otherwise.
function assert_empty() {
    local actual="$1"

    let CLOUDY_ASSERTION_COUNT=(CLOUDY_ASSERTION_COUNT + 1)
    [ ${#actual} -eq 0 ] && return 0
    _cloudy_assert_failed "variable" "should be empty."
}

# Assert that variable by name is not empty.
#
# $1 - The actual value
# $2 - A custom message on failure.
#
# Returns 0 if assertion is true; 1 otherwise.
function assert_not_empty() {
    local actual_value="$1"
    local custom_message="${3:-Value should not be empty}"

    let CLOUDY_ASSERTION_COUNT=(CLOUDY_ASSERTION_COUNT + 1)
    [ ${#actual_value} -gt 0 ] && return 0
    _cloudy_assert_failed "$actual_value" "$custom_message"
}

# Assert that two values are not the same.
#
# $1 - The expected value.
# $2 - The value to test.
#
# Returns 0 if assertion is true; 1 otherwise.
function assert_not_equals() {
    local expected="$1"
    local actual="$2"

    let CLOUDY_ASSERTION_COUNT=(CLOUDY_ASSERTION_COUNT + 1)
    [[ "$expected" != "$actual" ]] && return 0

    _cloudy_assert_failed "$actual" "should not equal" "$expected"
}

# Assert that two values are equal and of the same type.
#
# @todo is this needed, since bash is untyped?
#
# $1 - The expected value.
# $2 - The value to test.
#
# Returns 0 if assertion is true; 1 otherwise.
function assert_same() {
    local expected="$1"
    local actual="$2"

    let CLOUDY_ASSERTION_COUNT=(CLOUDY_ASSERTION_COUNT + 1)
    [[ "$expected" == "$actual" ]] && return 0
     _cloudy_assert_failed "$actual" "is not the same as" "$expected"
}

# Assert that two values are equal in value but not necessarily type.
#
# $1 - The expected value.
# $2 - The value to test.
#
# Returns 0 if assertion is true; 1 otherwise.
function assert_equals() {
    local expected="$1"
    local actual="$2"

    let CLOUDY_ASSERTION_COUNT=(CLOUDY_ASSERTION_COUNT + 1)
    [[ "$expected" == "$actual" ]] && return 0
     _cloudy_assert_failed "$actual" "does not equal" "$expected"
}

# Assert that a value equals "true" or "TRUE".
#
# $1 - The value to test.
#
# Returns 0 if assertion is true; 1 otherwise.
function assert_true() {
    local actual="$1"
    let CLOUDY_ASSERTION_COUNT=(CLOUDY_ASSERTION_COUNT + 1)
    [[ true == "$actual" ]] || [[ TRUE == "$actual" ]] && return 0
     _cloudy_assert_failed "$actual" "should be true."
}

# Assert that a value equals "false" or "FALSE".
#
# $1 - The value to test.
#
# Returns 0 if assertion is true; 1 otherwise.
function assert_false() {
    local actual="$1"
    let CLOUDY_ASSERTION_COUNT=(CLOUDY_ASSERTION_COUNT + 1)
    [[ false == "$actual" ]] || [[ FALSE == "$actual" ]] && return 0
     _cloudy_assert_failed "$actual" "should be false."
}

# Assert that a file exists by path.
#
# $1 - The filepath of the expected file.
#
# Returns 0 if assertion is true; 1 otherwise.
function assert_file_exists() {
    local filepath="$1"

    let CLOUDY_ASSERTION_COUNT=(CLOUDY_ASSERTION_COUNT + 1)
    [ -e "$filepath" ] && return 0
     _cloudy_assert_failed "$filepath" "does not exist, but it should."
}

# Assert that a file does not exist at path.
#
# $1 - The filepath to ensure does not exist.
#
# Returns 0 if assertion is true; 1 otherwise.
function assert_file_not_exists() {
    local filepath="$1"

    let CLOUDY_ASSERTION_COUNT=(CLOUDY_ASSERTION_COUNT + 1)
    [ ! -e "$filepath" ] && return 0
    _cloudy_assert_failed "$filepath" "exists, but should not."
}

# Assert that an array does not contain a value.
#
# $1 - The value to search for.
# $2 - The name of a global variable.
#
# Returns 0 if assertion is true; 1 otherwise.
function assert_not_contains() {
    local key=$1
    local array_var_name=$2

    eval array_has_value__array=(\${"$array_var_name"[@]})
    let CLOUDY_ASSERTION_COUNT=(CLOUDY_ASSERTION_COUNT + 1)
    ! array_has_value "$1" && return 0
    _cloudy_assert_failed "$key" "should not exist in array \$$array_var_name, but it does."
}

# Assert that an array has a given number of elements.
#
# $1 - The expected length.
# $2 - The name of a global array.
#
# Returns 0 if assertion is true; 1 otherwise.
function assert_count() {
    local expected="$1"
    local array_var_name="$2"

    code=$(declare -p $array_var_name)
    code=${code/$array_var_name=/value=}
    eval $code
    assert_same $expected ${#value[@]}
}

# Assert that an array contains a value.
#
# $1 - The value to search for.
# $2 - The name of a global variable.
#
# Returns 0 if assertion is true; 1 otherwise.
function assert_contains() {
    local key="$1"
    local array_var_name="$2"

    eval array_has_value__array=(\${"$array_var_name"[@]})
    let CLOUDY_ASSERTION_COUNT=(CLOUDY_ASSERTION_COUNT + 1)
    array_has_value "$1" && return 0
    _cloudy_assert_failed "$key" "should exist in array \$$array_var_name"
}

# Assert a function returns a given exit code.
#
# $1 The expected exit code of the previous command.
#
# Here are three examples of how to call...
# @code
#   array_sort; assert_exit_status 0
#   $(has_option 'name'); assert_exit_status 0
#   has_option 'name' > /dev/null; assert_exit_status 0
# @endcode
#
function assert_exit_status() {
    local actual=$?
    local expected=$1
    assert_same $expected $actual
}

# Assert that an global variable is of a given type.
#
# $1 - The expected type.
# $2 - The name of a global variable.
#
# Returns 0 if assertion is true; 1 otherwise.
function assert_internal_type() {
    local type=$1
    local var_name=$2

    case $type in
    array)
        [[ "$(declare -p $var_name)" =~ "declare -a" ]] && return 0
       ;;
    esac

    _cloudy_assert_failed "$var_name" "should be of type \"$type\"."
}

# Assert that an global variable is not of a given type.
#
# $1 - The expected type.
# $2 - The name of a global variable.
#
# Returns 0 if assertion is true; 1 otherwise.
function assert_not_internal_type() {

    local type=$1
    local var_name=$2

    case $type in
    array)
        ! [[ "$(declare -p $var_name)" =~ "declare -a" ]] && return 0
       ;;
    esac

    _cloudy_assert_failed "$var_name" "should not be of type \"$type\"."
}

# Assert that a value matches a regular expression.
#
# $1 - The regular expression.
# $2 - The value to match against the regexp.
#
# Returns 0 if assertion is true; 1 otherwise.
function assert_reg_exp() {
    local pattern="$1"
    local string="$2"

    [[ "$string" =~ $pattern ]] || _cloudy_assert_failed "$string" "Does not match regular expression \"$pattern\""
}
