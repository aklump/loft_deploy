#!/usr/bin/env bash

#
# @file
# Executes loft_deploy.sh from any directory within a project.
#
# See documentation for installation/usage.
#

function find_live_dev_porter() {
  test / == "$PWD" && return 1
  test -e "./bin/live_dev_porter" && echo "${PWD}/bin/live_dev_porter" && return 0 || cd .. && find_live_dev_porter
}
function find_loft_deploy() {
  test / == "$PWD" && return 1
  test -e "./vendor/bin/loft_deploy.sh" && echo "${PWD}/vendor/bin/loft_deploy.sh" && return 0 || cd .. && find_loft_deploy
}

# This is the successor to loft_deploy, so support it if found.
LIVE_DEV_PORTER=$(find_live_dev_porter)
if [[ "$LIVE_DEV_PORTER" ]]; then
  . "$LIVE_DEV_PORTER" "$@"
else
  LOFT_DEPLOY=$(find_loft_deploy)
  if [[ ! "$LOFT_DEPLOY" ]]; then
    echo "loft_deploy.sh not found. Have you installed it? [composer require aklump/loft-deploy]" && exit 1
  fi

  . "$LOFT_DEPLOY" "$@"
fi
