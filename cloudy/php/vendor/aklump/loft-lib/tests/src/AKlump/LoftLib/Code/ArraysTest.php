<?php

namespace AKlump\LoftLib\Code;

/**
 * Test the class Arrays.
 */
class ArraysTest extends \PHPUnit_Framework_TestCase {

  /**
   * Assert replaceKey works as it should.
   */
  public function testReplaceKeyDoesWhatItShould() {
    $array = [
      'do' => 'one',
      're' => 'two',
      'mi' => 'three',
    ];
    $control = [
      'do' => 'one',
      'ra' => 'two',
      'mi' => 'three',
    ];
    $this->assertSame($control, Arrays::replaceKey($array, 're', 'ra'));
  }

}

