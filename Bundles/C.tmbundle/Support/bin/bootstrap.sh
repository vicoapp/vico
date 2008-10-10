#!/bin/bash

if [ "$1" = "--version" ]; then
  if [ $2 = "c" ]; then gcc --version;
  elif [ $2 = "c++" ]; then g++ --version; fi
fi

if [ "$1" = "c" ]; then
  gcc -x "$1" -o "$2.out" "$2";
elif [ "$1" = "c++" ]; then
  g++ -x "$1" -o "$2.out" "$2";
fi

if [ $? -eq 0 ]; then
  "$2.out"
fi
