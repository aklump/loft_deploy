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
