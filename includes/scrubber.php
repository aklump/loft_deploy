<?php
/**
 * @file
 *
 * Helper to scrub secrets from files.
 *
 * exit with 0 on success, >0 on failure.
 */

$filepath = $argv[1];
$var_names = explode(',', $argv[2]);
$method = $argv[3];

try {
  $obj = new Scrubber($filepath);
  foreach ($var_names as $var_name) {
    if (!$obj->{$method}($var_name)) {
      exit(1);
    }
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

    return !empty($this->contents);
  }

  /**
   * Save the contents of the buffer over the original file.
   *
   * @return bool
   *   This will return false if the processed contents are the same as the
   *   unprocessed contents.
   */
  public function save() {
    if ($this->unprocessed === $this->contents) {
      return FALSE;
    }

    return file_put_contents($this->filepath, $this->contents);
  }

}
