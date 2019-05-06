#!/usr/bin/env bash

#
# Handles composer update, optimize, and git add .lock
#
composer dumpautoload --optimize && git add composer.lock || build_fail_exception

