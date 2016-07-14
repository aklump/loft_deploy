# Support for Pantheon websites

Pantheon servers are supported (prod -> dev only at this time) via their CLi called Terminus.  **With this method, you should not install Loft Deploy on the remote server.**

## Databases
1. You must have [Terminus installed](https://github.com/pantheon-systems/terminus#installation), e.g. `composer global require pantheon-systems/terminus`
1. More info about [machine tokens](https://pantheon.io/docs/machine-tokens/)
1. The following must appear in your `dev` config file. You can determine the site name by using `terminus sites list` after first authenticating.

        terminus_site='$SITE_NAME'
        terminus_machine_token=''
    
## Files
1. (Terminus is not necessary for files support at this time.)
1. Connection info is [found in the dashboard.](https://pantheon.io/docs/sftp/#sftp-connection-information)
1. The following must appear in your `dev` config file:

        production_server='$ENV.$SITE@appserver.$ENV.$SITE.drush.in'
        production_port=2222
        production_files='files'
        pantheon_live_uuid=''

More reading: <https://pantheon.io/docs/rsync-and-sftp/>
