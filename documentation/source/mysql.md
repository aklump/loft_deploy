# MYSQL

## Local
Local mysql can be entered using `ldp mysql`.

## Remote
If your production server allows remote connections you can use `ldp mysql --prod` but that requires some extra configuration.  The following needs to be added to your dev config file:

    production_remote_db_host=''

### Pantheon
If terminus is installed and your server is on Pantheon you only need to make sure this is present:

    pantheon_live_uuid=''
