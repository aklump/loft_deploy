---
title: Installation
noindex: false
---
# Loft Deploy

![Loft Deploy](images/loft-deploy.jpg)

## Summary

A bridge across website instances/environments to simplify the exchange of database and files not under SCM.  This was first written having Drupal in mind, though it works for other frameworks as well.

**Visit <https://aklump.github.io/loft_deploy> for full documentation.**

## Quick Start

```bash
$ cd /path/to/app
$ composer require aklump/loft-deploy
$ ./vendor/bin/loft_deploy.sh init dev
$ ./vendor/bin/loft_deploy.sh config
$ ./vendor/bin/loft_deploy.sh configtest
$ ./vendor/bin/loft_deploy.sh help
```

## Requirements

1. [Composer](https://getcomposer.org/)
1. PHP

{% include('_ldp.md') %}

## Configuration

The configuration file may be edited in one of two ways:

1. `$ ldp config` (using `$EDITOR`)
1. Open _/path/to/app/.loft_deploy/config.yml_ in your editor of choice.

Be sure to **test your configuration** until you see no warnings  `$ ldp configtest`.

## Usage

See inner documentation for how to use.

## Contributing

If you find this project useful... please consider [making a donation](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=4E5KZHDQCEUV8&item_name=Gratitude%20for%20aklump%2Floft_deploy).

## Contact The Developer

In the Loft Studios  
Aaron Klump - Web Developer  
sourcecode@intheloftstudios.com  
360.690.6432  
PO Box 29294 Bellingham, WA 98228-1294

<http://www.intheloftstudios.com>  
<https://github.com/aklump>  
