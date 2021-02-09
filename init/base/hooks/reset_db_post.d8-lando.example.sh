#!/bin/bash

#
# Sanitize the database and set UID to "admin:pass", handle modules as fit for
# development and clear caches
#

cd "$4/web" || return 1

sanitize=false

list_clear

if [[ "$sanitize" == true ]]; then
  # Sanitize the database.
  lando nxdb_drush sql-sanitize --sanitize-password=pass --whitelist-fields=field_company_name,field_company_title -y || return 1

  # Keep the UID name rename after sanitize!
  loft_deploy_mysql "UPDATE users_field_data SET name = 'admin' WHERE uid = 1;" || return 1
  list_add_item "Database sanitized."
fi

# Enable development modules.
lando nxdb_drush config-split:import dev -y || return 1
lando nxdb_drush config:import -y || return 1
lando nxdb_drush cache:rebuild -y >/dev/null || return 1
list_add_item "Drupal cache cleared."

echo_green_list
echo

return 0