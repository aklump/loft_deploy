#!/usr/bin/env bash

#
# @file
# Executes loft_deploy.sh from any directory within a project.
#
# See documentation for installation/usage.
#

function find_loft_deploy() {
  test / == "$PWD" && return 1
  test -e "./vendor/bin/loft_deploy.sh" && echo "${PWD}/vendor/bin/loft_deploy.sh" && return 0 || cd .. && find_loft_deploy
}

LOFT_DEPLOY=$(find_loft_deploy)
if [[ ! "$LOFT_DEPLOY" ]]; then
  echo "loft_deploy.sh not found. Have you installed it? [composer require aklump/loft-deploy]" && exit 1
fi

. "$LOFT_DEPLOY" $@
