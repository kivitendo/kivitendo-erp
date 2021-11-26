#!/bin/bash

dir="$(dirname "$0")"

for TEST in "$@"; do
  perl "-I${dir}/../modules/override" "-I${dir}/.." "-I${dir}/../modules/fallback" "$TEST"
done
