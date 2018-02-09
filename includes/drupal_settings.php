<?php
/**
 * Read a drupal settings file dynamically pulling out the db credentials
 */

define('DRUPAL_ROOT', $argv[1]);

//
//
// These functions are called in settings.php and should not be removed.
//
function t($text) {
  return $text;
}

function conf_path() {}
//
//
// End "bootstrap"
//

$path_to_settings = $argv[2];
$db_key = !empty($argv[3]) ? $argv[3] : 'default';
$fallback = 'default';

try {
  if (!is_readable($path_to_settings)) {
    throw new \RuntimeException("$path_to_settings settings file is not readable.");
  }

  @require $path_to_settings;

  // Drupal 6
  if (isset($db_url)) {
    $parts = parse_url($db_url);
    $db = array(
      'driver' => $parts['scheme'],
      'host' => $parts['host'],
      'database' => trim($parts['path'], '/'),
      'username' => $parts['user'],
      'password' => $parts['pass'],
      'port' => isset($parts['port']) ? $parts['port'] : '',
    );
  }
  // Drupal 7, 8
  else if (isset($databases[$db_key][$fallback])) {
    $db = $databases[$db_key][$fallback] + array_fill_keys(array('database', 'username', 'password', 'port'), NULL);
  }
  else {
    throw new \RuntimeException("Missing \$database variable.");
  }

  if (!in_array($db['driver'], array('mysql', 'mysqli'))) {
    throw new \RuntimeException("Your driver {$db['driver']} is not yet supported by loft_deploy");
  }

  $return[] = empty($db['host']) ? 'localhost' : $db['host'];
  $return[] = $db['database'];
  $return[] = $db['username'];
  $return[] = $db['password'];
  $return[] = $db['port'];

} catch (Exception $e) {
  $return = array_fill(0, 4, '?');
}
$return = implode(" ", $return);
echo $return;
