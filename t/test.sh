#!/bin/bash

{
  if [[ -z $1 ]]; then
    find t -type f -name '*.t'
  else
    echo -- "$@"
  fi
} | HARNESS_OPTIONS=j:c xargs perl -Imodules/override -MTest::Harness -e 'BEGIN { push @INC, "modules/fallback" } runtests(@ARGV)'
