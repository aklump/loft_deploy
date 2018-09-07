g co <?php
/**
 * @file
 * Updates dynamic portions of loft_deploy.sh
 *
 */

$filename = $argv[7] . '/loft_deploy.sh';

if ($contents = $before = file_get_contents($filename)) {

  // Do a regex replace of the version declaration in code.
  $contents = preg_replace('/^ld_version=[\d\.]+/m', 'ld_version=' . $argv[2], $contents);
  $changed = $contents !== $before;
  if ($changed && file_put_contents($filename, $contents)) {
    echo "Version string updated to " . $argv[2] . " in $filename";
    return;
  }
}

if ($changed) {
  echo "Error updated version string in $filename.";
}
