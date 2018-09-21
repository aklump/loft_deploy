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

$filepath_to_config_file = $argv[2];
$skip_config_validation = $argv[3] === 'true';

try {
  $data = [];
  if (!file_exists($filepath_to_config_file)) {
    throw new \RuntimeException("Missing configuration file: $filepath_to_config_file");
  }
  if (!($contents = file_get_contents($filepath_to_config_file))) {
    throw new \RuntimeException("Empty configuration files: $filepath_to_config_file");
  }
  switch (($extension = pathinfo($filepath_to_config_file, PATHINFO_EXTENSION))) {
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

  foreach ($g->get($data, 'additional_config', []) as $basename) {
    $path = ROOT . "/$basename";
    if (!file_exists($path)) {
      throw new \RuntimeException("Missing configuration file: $path");
    }
    $data = array_merge_recursive($data, Yaml::parse(file_get_contents($path)));
  }

  // Validate against cloudy_config.schema.json.
  $validator = new Validator();
  $validate_data = json_decode(json_encode($data));
  try {
    if (!($schema = json_decode(file_get_contents(CLOUDY_ROOT . '/cloudy_config.schema.json')))) {
      throw new \RuntimeException("Invalid JSON in cloudy_config.schema.json");
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
