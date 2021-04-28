<?php

/**
 * @file
 * Extract the database from the Drupal settings.
 */

define('DRUPAL_ROOT', $argv[1]);
define('CONFIG_SYNC_DIRECTORY', 'sync');

require_once __DIR__ . '/DrupalSettingsHandler.php';

$database_key = !empty($argv[3]) ? $argv[3] : 'default';
$handler = new DrupalSettingsHandler($argv[1], $database_key, $argv[2]);

try {
  $version = $handler->getDrupalVersion();
  $db = $handler->getDatabaseConfig($version);
  $return = [];
  $return[] = empty($db['host']) ? 'localhost' : $db['host'];
  $return[] = $db['database'];
  $return[] = $db['username'];
  $return[] = $db['password'];
  $return[] = $db['port'];
}
catch (Exception $e) {
  echo "? ? ? ? ?";
  exit(1);
}
echo implode(" ", $return);
exit(0);



