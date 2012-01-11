#!/bin/bash

# Usage:
#   cd /path/to/lx-office
#   ./scripts/build_doc.sh

set -e

if [[ ! -d doc ]]; then
  echo "Please run this from the installation directory."
  exit 1
fi

dobudish=$(ls -d doc/build/dobudish* 2> /dev/null)

if [[ -z $dobudish ]] || [[ ! -d ${dobudish} ]]; then
  echo "There's no dobudish directory inside doc/build."
  exit 1
fi

cd ${dobudish}

base=documents/dokumentation
if [[ ! -d $base ]]; then
  ./generator.sh dokumentation create book
fi

input=${base}/input
output=${base}/output
custom=${base}/custom-cfg

rm -f ${input}/*.xml
cp ../../dokumentation.xml ${input}/

rm -f ${custom}/*
cp -R ../custom-cfg/* ${custom}/

./generator.sh dokumentation pdf

cp ${output}/pdf/dokumentation.pdf ../../
