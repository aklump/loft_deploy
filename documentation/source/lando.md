---
id: lando
---
# Using Lando

If you application is inside a Lando container you will need to set it up
correctly.

1. Configure the Database

        database:
          lando: database

1. Optionally, override the default `lando` script.

        bin:
          lando: /path/to/lando

1. Be sure to update any hooks that use `drush` to `lando drush`.

## Using Lando With Drupal

This requires [special configuration](@config:lando).
