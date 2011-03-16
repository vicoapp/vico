<?php

$lines = file('functions.txt');

echo "(\n";

foreach ($lines as $line) {
    list($name, $proto, $desc) = explode('%', $line);
    
    $leftPos = strpos($proto, '(');
    $args = substr($proto, $leftPos + 1, strrpos($proto, ')') - $leftPos - 1);
    
    if (false !== strpos($args, '[')) {
        $args = preg_replace('/\s*\[\s*,\s*/', ',[', $args);
    }

    $args = empty($args) ? array() : explode(',', $args);
    
    foreach ($args as $argNum => &$arg) {
        $arg = '${' . ($argNum + 1) . ':' . trim($arg) . '}';
    }

    echo "\t{display = '${name}'; insert = '(";
    echo implode(', ', $args);
    echo ")';},\n";
}

echo ")\n";