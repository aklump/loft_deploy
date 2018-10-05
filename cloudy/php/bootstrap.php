<?php

/**
 * @file
 * Bootstrap for all php files.
 */

use AKlump\Data\Data;
use Symfony\Component\Yaml\Yaml;

/**
 * Root directory of the Cloudy instance script.
 */
define('ROOT', $argv[1]);

/**
 * The root directory of Cloudy core.
 *
 * @var string
 */
define('CLOUDY_ROOT', realpath(__DIR__ . '/../'));

require_once __DIR__ . '/vendor/autoload.php';

$g = new Data();

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

/**
 * Load a configuration file into memory.
 *
 * @param $filepath
 *   The absolute filepath to a configuration file.
 *
 * @return array|mixed
 */
function load_configuration_data($filepath) {
  $data = [];
  if (!file_exists($filepath)) {
    throw new \RuntimeException("Missing configuration file: " . $filepath);
  }
  if (!($contents = file_get_contents($filepath))) {
    // TODO Need a php method to write a log file, and then log this.
//    throw new \RuntimeException("Empty configuration file: " . realpath($filepath));
  }
  if ($contents) {
    switch (($extension = pathinfo($filepath, PATHINFO_EXTENSION))) {
      case 'yml':
      case 'yaml':
        if ($yaml = Yaml::parse($contents)) {
          $data += $yaml;
        }
        break;

      case 'json':
        if ($json = json_decode($contents, TRUE)) {
          $data += $json;
        }
        break;

      default:
        throw new \RuntimeException("Configuration files of type \"$extension\" are not supported.");

    }
  }

  return $data;
}

/**
 * Merge an array of configuration arrays.
 *
 * @param... two or more arrays to merge.
 *
 * @return array|mixed
 *   The merged array.
 */
function merge_config($arrays) {
  $arrays = func_get_args();
  $master = array_shift($arrays);
  foreach ($arrays as $merge) {
    if (is_numeric(key($merge))) {
      $master = array_merge($master, $merge);
    }
    else {
      foreach ($merge as $key => $value) {
        $type = NULL;
        if (isset($master[$key])) {
          $type = gettype($master[$key]);
        }
        if ($type && $type !== gettype($value)) {
          throw new \RuntimeException("Cannot merge key $key; values are not the same type.");
        }

        if (is_scalar($value) || empty($master[$key])) {
          $master[$key] = $value;
        }
        else {
          $master[$key] = merge_config($master[$key], $value);
        }
      }
    }
  }

  return $master;
}
