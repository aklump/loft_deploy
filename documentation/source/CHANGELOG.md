# Changelog

## [0.22.0] - 2022-05-02
  
### Fixed

- An issue with `mysqldump` preventing `reset -d`

## [0.21.0] - 2021-10-09

### Added

- `--skip-backup` option to _migrate, reset, pull_ operations. This will skip the local backup before overwriting; use with care!

### Changed

- `--nobu` is now `--skip-backup` for the _migrate_ route.

## [0.20.0] - 2021-10-08

### Changed

- Terminus must now be installed at the app level w/Composer; no longer in the .loft_deploy directory. See documentation for info.

## [0.19.0] - 2021-10-08

### Added

- --single-transaction and --skip-lock-tables by default; configurable with "mysqldump_flags" to reduce lock timeouts during export.

## [0.18.0] - 2021-05-08

### Added

- When using Lando with Drupal you should now configure using `database.lando: @drupal` and remove `drupal.settings`. Read [the documention](@lando) for more info.

## [0.17.0] - 2021-02-08

### Changed

- Made the project Composer installed.

## [0.16.0] - 2019-10-28

### Added

- Added support for using with Lando containers.
- Add configuration option `stage_may_pull_prod` to allow stage to pull from prod. Set this to true in your configuration.
- Improved feedback and messages.
- Added local role as argument `$8` to hooks.

## [0.14.13]

* Changes in config.yml are now detected and caches are cleared automatically.

## [0.14.10]

* Removed `scp` operation; you should now use the `copy_production_to` feature instead.

## [0.14]

* Change to YAML configuration files (see [update.html](update.html) for how to)
