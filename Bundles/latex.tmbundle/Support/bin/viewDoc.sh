#!/bin/bash

cd /tmp
fullbase=`basename $1`
filebase=`basename -s .dvi $1`
if [ $filebase.dvi = $fullbase ]; then
    dvipdfm $1
    open $filebase.pdf
    sleep 1
    rm $filebase.pdf
else
    open $1
fi
