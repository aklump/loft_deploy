# Loft Deploy

A bridge across website instances/environments to simplify the exchange of database and files not under SCM.

## Installation

Install in your project root using Composer.

```bash
$ cd /path/to/app
$ composer require aklump/loft-deploy
```

## Using the `ldp` command

To make working with Loft Deploy easier you should install the `ldp` command,
which allows you to execute _vendor/bin/loft_deploy.sh_ from any directory
within your project.

### Installation

1. After Composer
   installing [aklump/loft-deploy](https://github.com/aklump/loft_deploy), place
   a symlink to _./vendor/bin/ldp.sh_ somewhere $PATH can find it, e.g.,

    ```bash
    $ cd ~/bin
    $ ln -s /path/to/app/vendor/bin/ldp.sh ldp
    ```

1. Now use `ldp` as the command to execute _loft_deploy.sh_ from within any
   directory in your project, e.g.,

    ```bash
    $ cd /path/to/app/
    $ ldp info
    $ cd /path/to/app/web/modules
    $ ldp info
    ```

### Multiple Projects Using Loft Deploy?

No problem because _ldp.sh_ works across all versions of Loft Deploy, the
symlink to project A will work for project B and C. That is to say, you need
only install one symlink for many projects, even if those many projects have different versions of _Loft Deploy_ installed.

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
