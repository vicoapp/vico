<?php
// =============
// = Functions =
// =============
function test()
function test($foo, $foo = 1, &$foo = array(), &$foo = array(1, "2", "3", 4))
function test(array $foo = array(1, "2", "3", 4), array &$foo = array(), array $foo = null, array $foo = invalid)
function test(stdClass $foo)
function test(stdClass $foo = null)
function test(stdClass $foo = invalid)

// ========================
// = String interpolation =
// ========================
'$foo'
'\''
'\\'
"1\1111"
"1\x111"
"$foo"
"$foo[bar]"
"$foo[0]"
"$foo[$bar]"
"$foo->bar"
"$foo->$foo"
"{$foo->$bar}"
"{$foo->bar}"
"{$foo->bar[0]->baz}"
"{$foo->bar(12, $foo)}"

// =======
// = SQL =
// =======
'SELECT * from foo WHERE bar = \'foo \\ ' . $foo . 'sadas';
'SELECT * from foo WHERE bar = "foo" asdas' . $foo . '" asdasd';


"SELECT * from foo WHERE bar = 'asd $foo $foo->bar {$foo->bar[12]} asda'  'unclosed string";
"SELECT * from foo WHERE bar = \"dsa$foo\" \"unclosed string"
'SELECT * from foo WHERE bar = "unclosed string';

'SELECT * from foo WHERE bar = "foo \" ' . $foo . ' bar" AND foo = 1';

// Comments

'SELECT * FROM # foo bar \' asdassdsaas';
'SELECT * FROM -- foo bar \' asdassdsaas';
"SELECT * FROM # foo bar \" asdassdsaas";
"SELECT * FROM -- foo bar \" asdassdsaas";
?>