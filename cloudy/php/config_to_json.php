#!/usr/bin/php
<?php

/**
 * @file
 * Load actual configuration file and echo a json string.
 *
 * This is the first step in the configuration compiling.
 *
 * @group configuration
 * @see json_to_bash.php
 */

use JsonSchema\Constraints\Constraint;
use JsonSchema\Validator;
use Symfony\Component\Yaml\Yaml;

require_once __DIR__ . '/bootstrap.php';
$filepath_to_schema_file = $argv[2];
$filepath_to_config_file = $argv[3];
$skip_config_validation = $g->get($argv, 4, FALSE) === 'true';
$runtime = array_filter(explode("\n", trim($g->get($argv, 5, ''))));
try {
  $data = load_configuration_data($filepath_to_config_file);
  $additional_config = $g->get($data, 'additional_config', []);
  $merge_config = array_merge($additional_config, $runtime);
  foreach ($merge_config as $basename) {
    $path = strpos($basename, '/') !== 0 ? ROOT . "/$basename" : $basename;
    $additional_data = load_configuration_data($path);
    $data = merge_config($data, $additional_data);
  }

  // Validate against cloudy_config.schema.json.
  $validator = new Validator();
  $validate_data = json_decode(json_encode($data));
  try {
    if (!($schema = json_decode(file_get_contents($filepath_to_schema_file)))) {
      throw new \RuntimeException("Invalid JSON in $filepath_to_schema_file");
    }
    if (!$skip_config_validation) {
      $validator->validate($validate_data, $schema, Constraint::CHECK_MODE_EXCEPTIONS);
    }
  }
  catch (\Exception $exception) {
    $class = get_class($exception);
    throw new $class("Configuration syntax error in \"" . basename($filepath_to_config_file) . '": ' . $exception->getMessage());
  }

  echo json_encode($data);
  exit(0);
}
catch (\Exception $exception) {
  echo $exception->getMessage();
}
exit(1);
