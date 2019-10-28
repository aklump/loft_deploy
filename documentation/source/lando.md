# Using Lando

If you application is inside a Lando container you will need to set it up correctly.

1. Configure the Database

        database:
          lando: database
          
1. Optionally, override the default `lando` script.

        bin:
          lando: /path/to/lando
