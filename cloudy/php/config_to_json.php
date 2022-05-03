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
  $config = [
    '__cloudy' => [
      'CLOUDY_NAME' => getenv('CLOUDY_NAME'),
      'ROOT' => ROOT,
      'SCRIPT' => realpath(getenv('SCRIPT')),
      'CONFIG' => $path_to_master_config,
      'WDIR' => getenv('WDIR'),
      'LOGFILE' => getenv('LOGFILE'),
    ],
  ];
  $config = merge_config($config, load_configuration_data($path_to_master_config));

  // This is a global so don't erase it. @see _cloudy_realpath().
  $_config_path_base = isset($config['config_path_base']) ? $config['config_path_base'] : '';

  $extra_config_paths = array_filter(array_merge($config['additional_config'] ?? [], $additional_config_paths ?? []));
  foreach ($extra_config_paths as $path_or_glob) {
    $paths = _cloudy_realpath($path_or_glob);
    foreach ($paths as $path) {
      $new_data = load_configuration_data($path, FALSE);
      if ($new_data) {
        $config = merge_config($config, $new_data);
      }
    }
  }

  // Validate against cloudy_config.schema.json.
  $validator = new Validator();
  $validate_data = json_decode(json_encode($config));
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

  echo json_encode($config, JSON_UNESCAPED_SLASHES);
  exit(0);
}
catch (\Exception $exception) {
  echo $exception->getMessage();
}
exit(1);
