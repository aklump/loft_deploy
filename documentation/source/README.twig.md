---
title: Installation
noindex: false
---
# Loft Deploy

A bridge across website instances/environments to simplify the exchange of database and files not under SCM.

## Installation

Install in your project root using Composer.

```bash
$ cd /path/to/app
$ composer require aklump/loft-deploy
```

{% include('_ldp.md') %}

## Configuration

Once installed initiate configuration:
```bash
$ cd /path/to/app
$ ldp init {prod,dev,staging}
```

Now edit the configuration file one of two ways:

1. `$ ldp config`
1. Open _/path/to/app/.loft_deploy/config_ in your favorite editor.
1. Test your configuration until you see no warnings `$ ldp configtest`

## Documentation

After downloading, open `docs/index.html` for documentation.

## Contact

* **In the Loft Studios**
* Aaron Klump - Developer
* PO Box 29294 Bellingham, WA 98228-1294
* _aim_: theloft101
* _skype_: intheloftstudios
* _d.o_: aklump
* <http://www.InTheLoftStudios.com>
