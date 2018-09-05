# Support for Pantheon Websites

This guide will show you how to connect to Pantheon websites.  **Be aware that you do not install Loft Deploy on the remote server; you will use Pantheon's [Terminus](https://github.com/pantheon-systems/terminus) instead.**

## Install Terminus

- Once your local _.loft_deploy_ exists you may install Terminus.
- Descend into that directory, e.g. `cd .loft_deploy`
- Install using composer `composer require pantheon-systems/terminus`

## Configure Terminus

You must have something like the following in _config.yml_ on your local dev machine for the `production` section:

    production:
      files:
      - files
      - files/private
      pantheon:
        uuid: UUID-GOES-HERE
        site: SITE_NAME
        machine_token: 'MACHINE_TOKEN_HERE'

### Configuration Hints

1. To obtain or get more info about [machine tokens](https://pantheon.io/docs/machine-tokens/).
1. You can determine the site name by using `ldp terminus site:list` after first authenticating.

## Test installation

1. Make sure to `clearcache`
1. Then run `configtest` to see if _Terminus_ is installed correctly.

## Usage

1. You may use the installed version of terminus with Loft Deploy credentials by doing something like this:

        ldp terminus site:list

---    
## Files

@todo This must be updated with the new YAML format:

1. (Terminus is not necessary for files support at this time.)
1. Connection info is [found in the dashboard.](https://pantheon.io/docs/sftp/#sftp-connection-information)
1. The following must appear in your `dev` config file:

        production_server='$ENV.$SITE@appserver.$ENV.$SITE.drush.in'
        production_port=2222
        production_files='files'
        pantheon_live_uuid=''

More reading: <https://pantheon.io/docs/rsync-and-sftp/>
