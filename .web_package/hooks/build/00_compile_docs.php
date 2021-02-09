<?php

/**
 * @file
 * Generates documentation, adjusts paths and adds to SCM.
 */

namespace AKlump\WebPackage;

$build
  ->setDocumentationSource('documentation')

  // Set this to false if you do not want to generate to an html directory.
  ->generateDocumentationTo('docs')

  // This will adjust the path to the image, pulling it from docs.
  ->loadFile('README.md')
  ->replaceTokens([
    'images/loft-deploy.jpg' => 'docs/images/loft-deploy.jpg',
  ])
  ->saveReplacingSourceFile()
  // Add some additional files to SCM that were generated and outside of the docs directory.
  ->addFilesToScm([
    'README.md',
    'CHANGELOG.md',
  ])
  ->displayMessages();
