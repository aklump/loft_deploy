<?php
/**
 * @file
 *
 * Helper to scrub secrets from files.
 *
 * exit with 0 on success, >0 on failure.
 */

require_once __DIR__ . '/autoload.php';

$callback_args = $argv;
array_shift($callback_args);
$filepath = array_shift($callback_args);
$var_names = explode(',', array_shift($callback_args));
$method = array_pop($callback_args);

try {
  $obj = new Scrubber($filepath);
  foreach ($var_names as $var_name) {
    $args = $callback_args;
    array_unshift($args, $var_name);
    call_user_func_array([$obj, $method], $args);
  }
  if (!$obj->save()) {
    exit(2);
  }
}
catch (\Exception $exception) {
  exit(3);
}

exit(0);


/**
 * Remove sensitive information for a file.
 */
class Scrubber {

  /**
   * Scrubber constructor.
   *
   * @param string $filepath
   *   The path to the file to load.
   */
  public function __construct($filepath) {
    $this->filepath = $filepath;
    $this->type = pathinfo($filepath, PATHINFO_EXTENSION);
    $this->contents = file_get_contents($filepath);
    $this->unprocessed = $this->contents;
  }

  /**
   * Set the value of a variable by name to null.
   *
   * @param string $var_name
   *
   * @return boolean
   */
  public function setVariableByName($var_name) {
    $var_name = trim($var_name, '$ ');
    $regex = '(\$' . $var_name . ' +=).+$';
    $this->contents = preg_replace('/' . $regex . '/m', '$1 NULL;', $this->contents);
  }

  /**
   * Set a variable's value in a YAML file.
   *
   * @param string $var_name
   *
   * @return bool
   */
  public function yamlSetVar($var_name, $value = NULL) {
    $value = empty($value) ? 'NULL' : $value;
    $regex = '(^\s*' . preg_quote($var_name) . ') *:.+$';
    $this->contents = preg_replace('/' . $regex . '/m', '$1: ' . $value, $this->contents);
  }

  /**
   * Sets the value of a variable in .env files.
   *
   * @param string $var_name
   * @param null $value
   *
   * @return bool
   */
  public function envSetVar($var_name, $value = NULL) {
    $regex = '(' . $var_name . ').*?=.+$';
    if (!empty($value) && preg_match('/[ =\']/', $value)) {
      $value = addslashes($value);
      $value = "'$value'";
    }

    $this->contents = preg_replace('/' . $regex . '/m', '$1=' . $value, $this->contents);
  }

  /**
   * Removes the password from a standard URL.
   *
   * @param string $var_name
   *   name of the variable.
   *
   * @return bool
   */
  public function envSanitizeUrl($var_name) {
    $regex = '/(' . $var_name . ').*?=(["\']?)(.+?)["\']?$/m';
    $this->contents = preg_replace_callback($regex, function ($value) {
      $url = parse_url($value[3]);
      $url['pass'] = 'PASSWORD';
      $value[3] = http_build_url($url);

      return $value[1] . '=' . $value[2] . $value[3] . $value[2];

    }, $this->contents);
  }

  /**
   * Save the contents of the buffer over the original file.
   *
   * @return bool
   *   This will return false there has been an error.
   */
  public function save(): bool {
    if (NULL === $this->contents) {
      return FALSE;
    }

    return (bool) file_put_contents($this->filepath, $this->contents);
  }

}
