<?php
/**
 * Read a drupal settings file dynamically pulling out the db credentials
 */


// TODO Possibly a better way to do all this? 2016-06-05T09:03, aklump
define('DRUPAL_ROOT', '/');

function t($a) {
  return $a;
}
function conf_path() {
  return $a;
}

$path_to_settings = $argv[1];
$db_key = isset($argv[2]) ? $argv[2] : 'default';
$fallback = 'default';

try {
  if (!is_readable($path_to_settings)) {
    throw new \RuntimeException("$path_to_settings settings file is not readable.");
  }

  @require $path_to_settings;

  if (!isset($databases[$db_key][$fallback])) {
    throw new \RuntimeException("Missing $database variable.");
  }
  $db = $databases[$db_key][$fallback];

  if ($db['driver'] !== 'mysql') {
    throw new \RuntimeException("Drivers other than mysql are not yet supported by loft_deploy");
  }

  $return[] = empty($db['host']) ? 'localhost' : $db['host'];
  $return[] = $db['database'];
  $return[] = $db['username'];
  $return[] = $db['password'];

} catch (Exception $e) {
  $return = array_fill(0, 4, '?');
}
echo implode(' ', $return);
