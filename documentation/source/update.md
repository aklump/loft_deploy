# Update

## Manual Update to 0.14

This update converts the old config style into YAML:

1. Copy one of _install/config/*.yml_ files to _.loft_deploy/config.yml_; based on the role of the local.
1. Hand copy/paste config values from _.loft_deploy/config_ into _.loft_deploy/config.yml_.
1. Delete _.loft_deploy/config_.
1. Run `ldp clearcache`.
1. Run `ldp configtest` and adjust as necessary.

