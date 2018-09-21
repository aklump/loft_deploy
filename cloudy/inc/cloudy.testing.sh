#!/usr/bin/env bash

##
 # Perform all tests in a given file.
 #
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

function mark_test_skipped() {
    warn_because "Skipped test: $CLOUDY_ACTIVE_TEST"
    let CLOUDY_SKIPPED_TESTS_COUNT=(CLOUDY_SKIPPED_TESTS_COUNT + 1)
}

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

function assert_empty() {
    local actual="$1"

    let CLOUDY_ASSERTION_COUNT=(CLOUDY_ASSERTION_COUNT + 1)
    [ ${#actual} -eq 0 ] && return 0
    _cloudy_assert_failed "variable" "should be empty."
}

function assert_not_empty() {
    local actual="$1"
    local variable_name="$2"
    local custom_message="$3"

    let CLOUDY_ASSERTION_COUNT=(CLOUDY_ASSERTION_COUNT + 1)
    [ ${#actual} -gt 0 ] && return 0
    [[ "$variable_name" ]] || variable_name="variable"
    [[ "$custom_message" ]] || custom_message="should not be empty"
    _cloudy_assert_failed "$variable_name" "$custom_message"
}

function assert_not_equals() {
    local expected="$1"
    local actual="$2"

    let CLOUDY_ASSERTION_COUNT=(CLOUDY_ASSERTION_COUNT + 1)
    [[ "$expected" != "$actual" ]] && return 0

    _cloudy_assert_failed "$actual" "should not equal" "$expected"
}

function assert_same() {
    local expected="$1"
    local actual="$2"

    let CLOUDY_ASSERTION_COUNT=(CLOUDY_ASSERTION_COUNT + 1)
    [[ "$expected" == "$actual" ]] && return 0
     _cloudy_assert_failed "$actual" "is not the same as" "$expected"
}

function assert_equals() {
    local expected="$1"
    local actual="$2"

    let CLOUDY_ASSERTION_COUNT=(CLOUDY_ASSERTION_COUNT + 1)
    [[ "$expected" == "$actual" ]] && return 0
     _cloudy_assert_failed "$actual" "does not equal" "$expected"
}

function assert_true() {
    local actual="$1"
    let CLOUDY_ASSERTION_COUNT=(CLOUDY_ASSERTION_COUNT + 1)
    [[ true == "$actual" ]] || [[ TRUE == "$actual" ]] && return 0
     _cloudy_assert_failed "$actual" "should be true."
}

function assert_false() {
    local actual="$1"
    let CLOUDY_ASSERTION_COUNT=(CLOUDY_ASSERTION_COUNT + 1)
    [[ false == "$actual" ]] || [[ FALSE == "$actual" ]] && return 0
     _cloudy_assert_failed "$actual" "should be false."
}

function assert_file_exists() {
    local filepath="$1"

    let CLOUDY_ASSERTION_COUNT=(CLOUDY_ASSERTION_COUNT + 1)
    [ -e "$filepath" ] && return 0
     _cloudy_assert_failed "$filepath" "does not exist, but it should."
}

function assert_file_not_exists() {
    local filepath="$1"

    let CLOUDY_ASSERTION_COUNT=(CLOUDY_ASSERTION_COUNT + 1)
    [ ! -e "$filepath" ] && return 0
    _cloudy_assert_failed "$filepath" "exists, but should not."
}

function assert_array_not_has_key() {
    local key=$1
    local array_var_name=$2

    eval array_has_value__array=(\${"$array_var_name"[@]})
    let CLOUDY_ASSERTION_COUNT=(CLOUDY_ASSERTION_COUNT + 1)
    ! array_has_value "$1" && return 0
    _cloudy_assert_failed "$key" "should not exist in array \$$array_var_name, but it does."
}

function assert_count() {
    local expected="$1"
    local array_var_name="$2"

    code=$(declare -p $array_var_name)
    code=${code/$array_var_name=/value=}
    eval $code
    assert_same $expected ${#value[@]}
}

function assert_array_has_key() {
    local key=$1
    local array_var_name=$2

    eval array_has_value__array=(\${"$array_var_name"[@]})
    let CLOUDY_ASSERTION_COUNT=(CLOUDY_ASSERTION_COUNT + 1)
    array_has_value "$1" && return 0
    _cloudy_assert_failed "$key" "should exist in array \$$array_var_name"
}

##
 # Assert a function returns a given exit code.
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
