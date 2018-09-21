<?php

/**
 * @file
 * Validate a value against a schema.
 *
 * @see https://json-schema.org/latest/json-schema-validation.html
 */

use AKlump\LoftLib\Bash\Configuration;
use JsonSchema\Validator;

require_once __DIR__ . '/bootstrap.php';

$config = json_decode($g->get($argv, 1, '[]'), TRUE);
$config_key = $g->get($argv, 2);
$name = $g->get($argv, 3);
$value = $g->get($argv, 4);
$schema = $g->get($config, $config_key, []);

// Handle casting 'true' 'false' in bash to boolean in PHP.
if ($g->get($schema, 'type') === 'boolean') {
  $value = $value === 'true' ? TRUE : $value;
  $value = $value === 'false' ? FALSE : $value;
}
$value = Configuration::typecast($value);

$validator = new Validator();
$validator->validate($value, (object) $schema);
$exit_code = 0;

if (!$validator->isValid()) {
  $errors = [];
  $exit_code = 1;
  foreach ($validator->getErrors() as $error) {

    // Translate some default errors to our context.
    switch ($error['message']) {
      case 'String value found, but a boolean is required':
        $error['message'] = 'Boolean options may not be given a value.';
        break;
    }

    $errors[] = sprintf("[%s] %s", $name, $error['message']);
  }
  echo 'declare -a schema_errors=("' . implode('" "', $errors) . '")';
}

exit($exit_code);
