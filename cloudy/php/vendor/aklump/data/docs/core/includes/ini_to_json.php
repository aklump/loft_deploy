<?php
/**
 * @file
 * Converts the old .ini format to the new .json format
 *
 */
$file = __FILE__;
require_once dirname($file) . '/../vendor/autoload.php';

if (count($argv) < 4
    || ((list(, $ini_file, $source_dir, $json_file) = $argv)
        && (empty($ini_file) || empty($json_file)))
) {
    echo "Missing parameters to $file" . PHP_EOL;

    return;
}

if (file_exists($json_file)) {
    echo "Cannot create $json_file as it already exists." . PHP_EOL;

    return;
}

// Read ini file
$info = parse_ini_file($ini_file, true);
require_once dirname(__FILE__) . '/json.inc';
