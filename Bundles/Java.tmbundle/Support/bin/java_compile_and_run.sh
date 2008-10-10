#!/usr/bin/env bash

if [ "$1" = "--version" ]
then
    "$TM_JAVA" -version 2>&1 | head -1
    exit 0
fi

SOURCE="$1"
shift
TMP=/tmp/tm_javamate 
mkdir -p "$TMP"
cd "$TMP"
"$TM_JAVAC" -d "$TMP" -encoding UTF8 "$SOURCE"
if (($? >= 1)); then exit; fi
	
"$TM_JAVA" -Dfile.encoding=utf-8 $(basename -s .java "$SOURCE") $@
echo -e "\nProgram exited with status $?.";