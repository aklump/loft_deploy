#!/usr/bin/php
<?php

/**
 * @file
 * Load actual configuration file and echo a json string.
 *
 * File arguments:
 *   - path_to_config_schema,
 *   - path_to_master_source_config_file,
 *   - validate[true/false],
 *   - paths_to_additional_config_files separated by "\n"
 *
 * This is the first step in the configuration compiling.
 *
 * @group configuration
 * @see json_to_bash.php
 */

use JsonSchema\Constraints\Constraint;
use JsonSchema\Validator;

require_once __DIR__ . '/bootstrap.php';

$path_to_config_schema = $argv[1];
$path_to_master_config = $argv[2];
$skip_config_validation = $g->get($argv, 3, FALSE) === 'true';
$additional_config_paths = array_filter(explode("\n", trim($g->get($argv, 4, ''))));
try {
  $data = [
    '__cloudy' => [
      'CLOUDY_NAME' => getenv('CLOUDY_NAME'),
      'ROOT' => ROOT,
      'SCRIPT' => realpath(getenv('SCRIPT')),
      'CONFIG' => $path_to_master_config,
      'WDIR' => getenv('WDIR'),
      'LOGFILE' => getenv('LOGFILE'),
    ],
  ];
  $data += load_configuration_data($path_to_master_config);
  $_config_path_base = isset($data['config_path_base']) ? $data['config_path_base'] : '';
  $merge_config = $additional_config_paths;
  if ($additional_config = $g->get($data, 'additional_config', [])) {
    $merge_config = array_merge($additional_config, $additional_config_paths);
  }
  foreach ($merge_config as $path_or_glob) {
    $paths = _cloudy_realpath($path_or_glob);
    foreach ($paths as $path) {
      try {
        $additional_data = load_configuration_data($path);
        $data = merge_config($data, $additional_data);
      }
      catch (\Exception $exception) {
        // Purposefully left blank because we will allow missing additional
        // configuration files.  This will happen if the app allows for a home
        // directory config file, this should be optional and not throw an
        // error.
      }
    }
  }

  // Validate against cloudy_config.schema.json.
  $validator = new Validator();
  $validate_data = json_decode(json_encode($data));
  try {
    if (!($schema = json_decode(file_get_contents($path_to_config_schema)))) {
      throw new \RuntimeException("Invalid JSON in $path_to_config_schema");
    }
    if (!$skip_config_validation) {
      $validator->validate($validate_data, $schema, Constraint::CHECK_MODE_EXCEPTIONS);
    }
  }
  catch (\Exception $exception) {
    $class = get_class($exception);
    throw new $class("Configuration syntax error in \"" . basename($path_to_master_config) . '": ' . $exception->getMessage());
  }

  echo json_encode($data, JSON_UNESCAPED_SLASHES);
  exit(0);
}
catch (\Exception $exception) {
  echo $exception->getMessage();
}
exit(1);
