<?php

class DrupalSettingsHandler {

  const VERSION_6 = 6;

  const VERSION_7 = 7;

  const VERSION_8 = 8;

  const VERSION_9 = 8;

  /**
   * DrupalSettingsHandler constructor.
   *
   * @param string $path_to_webroot
   *   The path to Drupal's webroot directory.
   * @param string $database_key
   *   Which key in the $databases array do you want to pull config from?
   * @param string $path_to_settings
   *   Absolute path to the settings file.
   */
  function __construct(string $path_to_webroot, string $database_key = 'default', string $path_to_settings = '') {
    $this->webroot = $path_to_webroot;
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
    elseif (file_exists($this->webroot . '/scripts/drupal.sh')) {
      return self::VERSION_7;
    }

    // TODO Handle Drupal 6?

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

    // TODO I think the drupal 7 code should work, just need a testcase, however this is so old may never get the chance. May 8, 2021 at 8:01:36 PM PDT, aklump.

    if (!is_readable($this->pathToSettings)) {
      throw new \RuntimeException(sprintf('%s settings file is not readable.', $this->pathToSettings));
    }
    if (!defined('DRUPAL_ROOT')) {
      define('DRUPAL_ROOT', $this->webroot);
    }
    if (!defined('CONFIG_SYNC_DIRECTORY')) {
      define('CONFIG_SYNC_DIRECTORY', 'sync');
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
    define('DRUPAL_ROOT', $this->webroot);
    require_once DRUPAL_ROOT . '/includes/bootstrap.inc';
    drupal_bootstrap(DRUPAL_BOOTSTRAP_CONFIGURATION);
    global $databases;

    return $databases[$this->databaseKey]['default'] ?? [];
  }

  private function handleDrupal8() {
    $autoloader = require_once $this->webroot . '/autoload.php';
    $request = \Symfony\Component\HttpFoundation\Request::createFromGlobals();
    $environment = \Drupal\Core\DrupalKernel::bootEnvironment($this->webroot);
    \Drupal\Core\DrupalKernel::createFromRequest($request, $autoloader, $environment);

    $databases = \Drupal\Core\Database\Database::getConnectionInfo();
    if (!$databases[$this->databaseKey]) {
      throw new \RuntimeException(sprintf("There appears to be no database defined in settings.php with the key of \"%s\"", $this->databaseKey));
    }

    return $databases[$this->databaseKey];
  }

}
