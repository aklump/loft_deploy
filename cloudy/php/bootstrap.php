<?php

/**
 * @file
 * Bootstrap for all php files.
 */

use AKlump\Data\Data;
use AKlump\LoftLib\Bash\Configuration;

/**
 * Root directory of the Cloudy instance script.
 */
define('ROOT', $argv[1]);

/**
 * The prefix to use for BASH vars.
 *
 * @var string
 */
define('CONFIG_PREFIX', 'cloudy_config');

/**
 * The root directory of Cloudy core.
 *
 * @var string
 */
define('CLOUDY_ROOT', realpath(__DIR__ . '/../'));

require_once __DIR__ . '/vendor/autoload.php';

$g = new Data();
$var_service = new Configuration(CONFIG_PREFIX);

/**
 * Sort an array by the length of it's values.
 *
 * @param string ...
 *   Any number of items to be taken as an array.
 *
 * @return array
 *   The sorted array
 */
function array_sort_by_item_length() {
  $stack = func_get_args();
  uasort($stack, function ($a, $b) {
    return strlen($a) - strlen($b);
  });

  return array_values($stack);
}
