## (Recommended) Installation

1. Loft Deploy needs to be installed in each environment: _Production, Local_ and (if used) _Staging_.
1. Connect using a terminal program to the home directory of the server.  If the _bin_ folder does not exist, create it now.

        cd /opt

1. Clone Loft Deploy and create a symlink that is user executable.

        git clone https://github.com/aklump/loft_deploy.git loft_deploy;
        cd /usr/local/bin
        ln -s /opt/loft_deploy/loft_deploy.sh loft_deploy;
        chmod u+x loft_deploy;

1. Install dependencies using [Composer](https://getcomposer.org/).

        cd /usr/local/bin/loft_deploy
        composer install
        
1. Open up and modify _~/.bash_profile_ or _~/.profile_ (whichever you use).

        alias ldp="loft_deploy"
        export PATH=$PATH:~/bin

1. Reload your profile and test, you should see the Loft Deploy help screen if installation was successful.

        $ . ~/.bash_profile
        $ ldp

## Installation

Here is a one-liner to clone this repo to a directory on your system _$HOME/opt/loft_deploy_ and create a symlink in _$HOME/bin/ldp_.  This assumes _~/bin_ is in your `$PATH` variable.

    (cd $HOME && (test -d opt || mkdir opt) && (test -d bin || mkdir bin) && cd opt && (test -d loft_deploy || git clone https://github.com/aklump/loft_deploy.git) && (test -s $HOME/bin/ldp || ln -s $HOME/opt/loft_deploy/loft_deploy.sh $HOME/bin/ldp) && cd $HOME/opt/loft_deploy && composer install)


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
