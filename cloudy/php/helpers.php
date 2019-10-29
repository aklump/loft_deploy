#!/usr/bin/php
<?php

/**
 * @file
 * Return a configuration value by key.
 */

use AKlump\LoftLib\Bash\Configuration;

require_once __DIR__ . '/bootstrap.php';

$args = $argv;
array_shift($args);
$function = array_shift($args);

if (!function_exists($function)) {
  echo "Missing function \"$function\".";
  exit(1);
}

switch ($function) {
  case 'array_sort_by_item_length':
    $var_name = array_shift($args);
    break;
}

try {
  $result = call_user_func_array($function, $args);

  if (is_array($result)) {
    $var_service = new Configuration('cloudy_config');
    $eval_code = $var_service->getVarEvalCode($var_name, $result);
    echo $eval_code;
    exit(0);
  }
  else {
    echo $result;
    exit(0);
  }
}
catch (\Exception $exception) {
  exit(1);
}




