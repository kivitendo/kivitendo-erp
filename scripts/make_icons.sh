#!/bin/bash

set -e

scripts/image_maps.pl --icon-class=icon16 --css-out=public/css/icons16.css --image-out=public/image/maps/icons16.png public/image/icons/16x16/*.png
scripts/image_maps.pl --icon-class=icon24 --css-out=public/css/icons24.css --image-out=public/image/maps/icons24.png public/image/icons/24x24/*.png
scripts/image_maps.pl --icon-class=icon32 --css-out=public/css/icons32.css --image-out=public/image/maps/icons32.png public/image/icons/32x32/*.png
