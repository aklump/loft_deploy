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
  $autoload = dirname(__FILE__) . '/../vendor/autoload.php';
  if (!file_exists($autoload)) {
    echo "Missing dependencies.  Have you run composer install?" . PHP_EOL;
    exit(1);
  }
  require $autoload;
  $config_dir = $argv[1];
  $schema = $argv[2];
  $config_file = FilePath::create("$config_dir/config.yml");

  // Validate our schema file.
  if (!file_exists($schema)) {
    throw new \RuntimeException("JSON schema \"$schema\" does not exist.");
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
  $validator = new Validator;
  $_config = json_decode(json_encode($config));
  $validator->validate($_config, $schema_json);
  if (!$validator->isValid()) {
    $error_items = array_map(function ($error) {
      return sprintf("[%s] %s", $error['property'], $error['message']);
    }, $validator->getErrors());
    throw new \RuntimeException("Schema validation problem.");
  }

  $local_path = function ($path) use ($config) {
    return substr($path, 0, 1) === '/' ? $path : rtrim($config['local']['basepath'], '/') . '/' . rtrim($path, '/');
  };

  if (isset($config['bin'])) {
    foreach ($config['bin'] as $key => $item) {
      $data['ld_' . $key] = $local_path($item);
    }
  }

  foreach ($config['local'] as $key => $item) {
    switch ($key) {
      case 'location':
        break;

      case 'url':
        $title = array();
        if (isset($config['local']['location'])) {
          $title[] = $config['local']['location'];
        }
        $data['local_title'][] = preg_replace('/https?:\/\//i', '', $item);
        $data['local_title'] = implode(' ~ ', $data['local_title']);
        break;

      case 'database':
        foreach ($item as $k => $v) {
          switch ($k) {
            case 'backups':
              $data['local_db_dir'] = $local_path($v);
              break;
          }
        }
        break;

      case 'drupal':
        foreach ($item as $k => $v) {
          switch ($k) {
            case 'root':
            case 'settings':
              $data['local_drupal_' . $k] = $local_path($v);
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
          $data[$k] = $local_path($v);
        }
        break;

      case 'copy_source':
      case 'copy_local_to':
      case 'copy_production_to':
      case 'copy_staging_to':
        $data['local_' . $key] = implode(':', array_map(function ($path) use ($local_path) {
          return $local_path($path);
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
  print Color::wrap('red', 'Configuration Problem in: ' . $config_file->getBasename()) . PHP_EOL;
  $error_items = array($exception->getMessage());
  print Output::tree($error_items) . PHP_EOL;
  exit(1);
}
