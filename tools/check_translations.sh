#!/bin/sh

[ -d 'tools' ] || (echo "You must run this utility from the root of TWiki sources directory"; exit 1)

for each in `ls locale/*.po`; do
  echo -n "$each: "
  msgfmt --output=/dev/null --statistics $each
done

