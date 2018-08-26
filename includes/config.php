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

require_once dirname(__FILE__) . '/../vendor/autoload.php';

try {
  $config_dir = $argv[1];
  $schema = $argv[2];
  $config_file = FilePath::create("$config_dir/config.yml");

  if (!$config_file->exists()) {
    exit(0);
  }

  $bash = new ConfigBash($config_dir . '/cache', 'config.yml.sh');

  $config = Yaml::parse($config_file->load()->get());
  $validator = new Validator;
  $_config = json_decode(json_encode($config));
  $validator->validate($_config, (object) ['$ref' => 'file://' . realpath($schema)]);
  if (!$validator->isValid()) {
    $error_items = array_map(function ($error) {
      return sprintf("[%s] %s", $error['property'], $error['message']);
    }, $validator->getErrors());
    throw new \RuntimeException("Schema validation problem.");
  }

  $local_path = function ($path) use ($config) {
    return substr($path, 0, 1) === '/' ? $path : rtrim($config['local']['basepath'] ?? '', '/') . '/' . rtrim($path, '/');
  };

  foreach ($config['bin'] ?? [] as $key => $item) {
    $data['ld_' . $key] = $local_path($item);
  }

  foreach ($config['local'] as $key => $item) {
    switch ($key) {
      case 'location':
      case 'basepath':
        break;

      case 'url':
        $data['title'][] = $config['local']['location'] ?? '';
        $data['title'][] = $item;
        $data['title'] = implode(' ~ ', $data['title']);
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

      default:
        $data['local_' . $key] = $item;
        break;
    }
  }

  foreach (array('production', 'staging') as $server) {

    $full_path = function ($path) use ($config, $server) {
      return substr($path, 0, 1) === '/' ? $path : rtrim($config[$server]['basepath'] ?? '', '/') . '/' . rtrim($path, '/');
    };

    foreach ($config[$server] ?? [] as $key => $item) {
      switch ($key) {
        case 'config':
          $data[$server . '_root'] = dirname($item);
          break;

        case 'user':
          $data[$server . '_server'] = $item . '@' . $config[$server]['ip'];
          break;

        case 'ip':
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
  print Color::wrap('black on red', 'Configuration Problem in: ' . $config_file->getBasename()) . PHP_EOL;
  if (!isset($error_items)) {
    $error_items = [$exception->getMessage()];
  }
  print Output::list($error_items) . PHP_EOL;
  exit(1);
}
