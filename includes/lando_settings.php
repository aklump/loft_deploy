<?php

/**
 * @file
 * Pulls the configuration out of lando json so it can be ready by Loft Deploy.
 */

$lando = $argv[1];
$lando_db_service = $argv[2];
$lando_config_json = $argv[3];

try {
  $config = json_decode($lando_config_json, TRUE);
  $service = array_filter($config, function ($item) use ($lando_db_service) {
    return $item['service'] === $lando_db_service;
  });
  if (count($service) !== 1) {
    throw new \RuntimeException(sprintf("Unable to locate exactly one database service called %s using the lando configuration", $lando_db_service));
  }
  $service = reset($service);
  $return[] = $service['external_connection']['host'];
  $return[] = $service['creds']['database'];
  $return[] = $service['creds']['user'];
  $return[] = $service['creds']['password'];
  $return[] = $service['external_connection']['port'];
}
catch (Exception $e) {
  $return = array_fill(0, 5, '?');
  exit(1);
}
$return = implode(" ", $return);
echo $return;
exit(0);
