#!/bin/bash

eval '"$1"' "$2" '"$3"' -o '"$3".out'

if [ $? -eq 0 ]; then
  "$3".out;
fi
