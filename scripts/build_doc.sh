#!/bin/bash

# Usage:
#   cd /path/to/lx-office
#   ./scripts/build_doc.sh

set -e

if [[ ! -d doc ]]; then
  echo "Please run this from the installation directory."
  exit 1
fi

html=1
pdf=1

if [[ ! -z $1 ]] ; then
  html=0
  pdf=0
  while [[ ! -z $1 ]] ; do
    case $1 in
      html) html=1 ;;
      pdf)  pdf=1  ;;
      *)
        echo "Unknown parameter $1"
        exit 1
        ;;
    esac

    shift
  done
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

rm -rf ${input} ${custom}
mkdir ${input} ${input}/copy_to_output ${custom}

cp ../../dokumentation.xml ${input}/
cp -R ../../images ${input}/copy_to_output/
cp -R ../custom-cfg/* ${custom}/

if [[ $pdf = 1 ]] ; then
  ./generator.sh dokumentation pdf
  cp ${output}/pdf/dokumentation.pdf ../../Lx-Office-Dokumentation.pdf
fi

if [[ $html = 1 ]]; then
  ./generator.sh dokumentation html
  rm -rf ../../html
  mkdir ../../html
  cp -R ${output}/html ../../
fi
