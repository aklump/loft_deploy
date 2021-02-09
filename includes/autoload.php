<?php
/**
 * @file
 * Find the correct Composer autoload.php file.
 */

$autoload = __DIR__ . '/../../../autoload.php';
if (!file_exists($autoload)) {
  $autoload = __DIR__ . '/../vendor/autoload.php';
}
if (!file_exists($autoload)) {
  throw new \RuntimeException("vendor/autoload.php not found.  Have you run \"composer install\"?");
}
require_once $autoload;
