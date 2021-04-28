<?php

class DrupalSettingsHandler {

  const VERSION_6 = 6;

  const VERSION_7 = 7;

  const VERSION_8 = 8;

  const VERSION_9 = 8;

  function __construct(string $app_root, string $database_key = 'default', string $path_to_settings = '') {
    $this->webroot = $app_root;
    $this->databaseKey = $database_key;
    $this->pathToSettings = $path_to_settings;
  }

  /**
   * @return int
   *   The detected Drupal version.
   */
  public function getDrupalVersion() {
    if (file_exists($this->webroot . '/core')) {
      return self::VERSION_8;

      // TODO Sniff for 9.
    }
    if (!is_readable($this->pathToSettings)) {
      throw new \RuntimeException(sprintf('%s settings file is not readable.', $this->pathToSettings));
    }

    require $this->pathToSettings;

    global $db_url;
    if (!empty($db_url)) {
      return self::VERSION_6;
    }

    global $database;
    if (!empty($database)) {
      return self::VERSION_7;
    }
  }

  public function getDatabaseConfig(int $drupal_version) {
    $method = "handleDrupal{$drupal_version}";

    return $this->{$method}();
  }

  /**
   * @return array
   *
   * @todo These have not been finished.
   */
  private function handleDrupal6() {
    if (!is_readable($this->pathToSettings)) {
      throw new \RuntimeException(sprintf('%s settings file is not readable.', $this->pathToSettings));
    }

    require $this->pathToSettings;

    global $db_url;
    $parts = parse_url($db_url);

    return [
      'driver' => $parts['scheme'],
      'host' => $parts['host'],
      'database' => trim($parts['path'], '/'),
      'username' => $parts['user'],
      'password' => $parts['pass'],
      'port' => isset($parts['port']) ? $parts['port'] : '',
    ];
  }

  /**
   * @return array
   *
   * @todo These have not been finished.
   */
  private function handleDrupal7() {
    if (!is_readable($this->pathToSettings)) {
      throw new \RuntimeException(sprintf('%s settings file is not readable.', $this->pathToSettings));
    }

    require $this->pathToSettings;

    global $databases;

    return $databases[$this->databaseKey]['default'] + array_fill_keys(array(
        'database',
        'username',
        'password',
        'port',
      ), NULL);
  }

  private function handleDrupal8() {
    $autoloader = require_once $this->webroot . '/autoload.php';
    $request = \Symfony\Component\HttpFoundation\Request::createFromGlobals();
    $environment = \Drupal\Core\DrupalKernel::bootEnvironment($this->webroot);
    \Drupal\Core\DrupalKernel::createFromRequest($request, $autoloader, $environment);

    $databases = \Drupal\Core\Database\Database::getConnectionInfo();
    $database_key = $argv[3] ?? 'default';
    if (!$databases[$database_key]) {
      throw new \RuntimeException(sprintf("There appears to be no database defined in settings.php with the key of \"%s\"", $database_key));
    }

    return $databases[$database_key];
  }
}
