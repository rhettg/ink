#!/bin/bash

test_path=$(dirname $0)
ret=0
for tf in $( ls ${test_path}/test_*.sh ); do
  test_name=$(basename $tf)
  echo -n "${test_name} - "
  if ${tf}; then
    echo "Ok"
  else
    echo "Failed"
  fi
done

exit $ret
