#!/bin/sh
version=$1
pip$version list 2>/dev/null | grep -e '[a-zA-Z]* [0-9]' | cut -f1 -d' ' | while read line ; do
    ymp search --file "/$line/"
done

