# Update

## Manual Update to 0.14

This update converts the old config style into YAML:

1. Copy values from _.loft_deploy/config_ into a new file _.loft_deploy/config.yml_
1. Delete _.loft_deploy/config_
1. Run `ldp clearcache`
1. Run `ldp configtest` and adjust as necessary.
