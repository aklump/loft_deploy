<?php

/**
 * @file
 *
 * Supports YAML-based configuration
 */

use AKlump\LoftLib\Bash\Color;
use AKlump\LoftLib\Bash\Output;
use AKlump\LoftLib\Config\ConfigBash;
use AKlump\LoftLib\Storage\FilePath;
use JsonSchema\Validator;
use Symfony\Component\Yaml\Yaml;


try {
  require_once __DIR__ . '/autoload.php';

  $config_dir = $argv[1];
  $schema = $argv[2];
  $config_file = FilePath::create("$config_dir/config.yml");

  // Validate our schema file.
  if (!file_exists($schema)) {
    throw new \RuntimeException("JSON schema \"$schema\" does not exist.");
  }

  /**
   * Resolve a path relative to directory containing .loft_deploy.
   *
   * @param string $path
   *
   * @return false|string
   */
  function path_resolve($path) {
    global $config;
    if (strpos($path, '/') !== 0) {
      $path = rtrim($config['local']['basepath'], '/') . "/$path";
      if ($p = realpath($path)) {
        $path = $p;
      }
    }

    return $path;
  }

  $schema_json = json_decode(file_get_contents($schema));
  $valid_json_in_schema = !empty($schema_json);
  if (!$valid_json_in_schema) {
    throw new \RuntimeException("JSON schema \"$schema\" has malformed JSON.");
  }


  if (!$config_file->exists()) {
    exit(0);
  }

  $bash = new ConfigBash($config_dir . '/cache', 'config.yml.sh', array('install' => TRUE));

  $config = Yaml::parse($config_file->load()->get());


  // Some hand-picked tricky validation which precedes the json schema.
  isset($config['local']) && validate_drupal_lando_collision('local', $config['local']);
  isset($config['prod']) && validate_drupal_lando_collision('prod', $config['prod']);
  isset($config['staging']) && validate_drupal_lando_collision('staging', $config['staging']);

  $validator = new Validator;
  $_config = json_decode(json_encode($config));
  $validator->validate($_config, $schema_json);
  $error_items = [];
  if (!$validator->isValid()) {
    $error_items = array_map(function ($error) {
      return sprintf("[%s] %s", $error['property'], $error['message']);
    }, $validator->getErrors());
    throw new \RuntimeException("Schema validation failed.");
  }

  // Load the env_files if we have them.
  $env_vars = [];
  if (!empty($_config->local->env_file)) {
    foreach ($_config->local->env_file as $filename) {
      $filename = path_resolve($filename);
      if (file_exists($filename)) {
        if (!($parsed = parse_ini_file($filename))) {
          throw new \RuntimeException(sprintf('Problem reading from "%s".', $filename));
        }
        $env_vars += $parsed;
      }
    }
  }


  if (isset($config['bin'])) {
    foreach ($config['bin'] as $key => $item) {
      $data['ld_' . $key] = path_resolve($item);
    }
  }

  foreach ($config['local'] as $key => $item) {
    switch ($key) {

      // These do not need to print; they are probably imported using cloudy in loft_deploy.sh.
      case 'role':
      case 'url':
      case 'basepath':
      case 'location':
        break;

      case 'database':
        foreach ($item as $k => $v) {

          // Translate environment vars.
          if (substr($v, 0, 1) === '$') {
            $env_var_key = ltrim($v, '$');
            $v = $env_vars[$env_var_key];
          }

          switch ($k) {
            case 'backups':
              $data['local_db_dir'] = path_resolve($v);
              break;

            case 'password':
              $data['local_db_pass'] = $v;
              break;

            case 'lando':
              $data['local_lando_db_service'] = $v;
              break;

            case 'uri':
              if (($parts = parse_url($v)) === FALSE) {
                throw new \InvalidArgumentException(sprintf("Cannot parse configuration value for local.uri of \"%s\".", $v));
              };
              $db['local_db_host'] = $parts['host'];
              $db['local_db_port'] = $parts['port'];
              $db['local_db_user'] = $parts['user'];
              $db['local_db_pass'] = $parts['pass'];
              $db['local_db_name'] = trim($parts['path'], '/');
              $data = array_filter($db) + $data;
              break;

            default:
              $data['local_db_' . $k] = $v;
              break;
          }
        }
        break;

      case 'drupal':
        foreach ($item as $k => $v) {
          switch ($k) {
            case 'root':
            case 'settings':
              $data['local_drupal_' . $k] = path_resolve($v);
              break;

            case 'database':
              $data['local_drupal_db'] = $v;
              break;

            default:
              $data['local_drupal_' . $k] = $v;
              break;
          }
        }
        break;

      case 'files':
        foreach ($item as $i => $v) {
          $k = 'local_files';
          if ($i > 0) {
            $k .= $i + 1;
          }
          $data[$k] = path_resolve($v);
        }
        break;

      case 'copy_source':
      case 'copy_local_to':
      case 'copy_production_to':
      case 'copy_staging_to':
        $data['local_' . $key] = implode(':', array_map(function ($path) {
          return path_resolve($path);
        }, $item));
        break;

      default:
        $data['local_' . $key] = $item;
        break;
    }
  }

  foreach (array('production', 'staging') as $server) {

    if (!isset($config[$server])) {
      continue;
    }
    $full_path = function ($path) use ($config, $server) {
      $path = rtrim($path, '/');
      if (!isset($config[$server]['basepath'])) {
        return $path;
      }

      return substr($path, 0, 1) === '/' ? $path : rtrim($config[$server]['basepath'], '/') . '/' . $path;
    };

    foreach ($config[$server] as $key => $item) {
      switch ($key) {
        case 'config':
          $data[$server . '_root'] = dirname($item);
          break;

        case 'user':
          $data[$server . '_server'] = $item . '@' . $config[$server]['host'];
          break;

        case 'host':
          break;

        case 'files':
          foreach ($item as $i => $v) {
            $k = 'production_files';
            if ($i > 0) {
              $k .= $i + 1;
            }
            $data[$k] = $full_path($v);
          }
          break;

        case 'password':
          $data[$server . '_pass'] = $item;
          break;

        case 'pantheon':
          $arm = $server === 'production' ? 'live' : 'staging';
          foreach ($item as $k => $v) {
            switch ($k) {
              case 'uuid':
                $data['pantheon_' . $arm . '_uuid'] = $v;
                break;

              case 'site':
              case 'machine_token':
                $data['terminus_' . $k] = $v;
                break;
            }
          }
          break;

        case 'database':
          foreach ($item as $k => $v) {
            switch ($k) {
              case 'password':
                $data[$server . '_db_pass'] = $v;
                break;

              case 'host':
                $data[$server . '_remote_db_host'] = $v;
                break;

              default:
                $data[$server . '_db_' . $k] = $v;
                break;
            }
          }
          break;

        default:
          $data[$server . '_' . $key] = $item;
          break;
      }
    }
  }

  $bash->destroy()->writeMany($data);
  exit(0);
}
catch (\Exception $exception) {
  print Color::wrap('red', 'Configuration problem in: ' . $config_file->getPath()) . PHP_EOL;
  $error_items[] = $exception->getMessage();
  print Output::tree($error_items) . PHP_EOL;
  exit(1);
}


/**
 * Validate that there is not a clash between lando and drupal settings.
 *
 * @param string $prefix
 * @param array $config
 */
function validate_drupal_lando_collision(string $prefix, array $config) {
  if (empty($config)) {
    return;
  }
  if (!empty($config['drupal']['settings']) && !empty($config['database']['lando'])) {
    throw new \RuntimeException("You cannot use \"{$prefix}.drupal.settings\" and \"{$prefix}.database.lando\" simultaneously.  Remove one or the other.");
  }
}
