#!/bin/bash

dir="$(dirname "$0")"

perl "-I${dir}/../modules/override" "-I${dir}/.." "-I${dir}/../modules/fallback" "$@"
