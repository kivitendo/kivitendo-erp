#!/bin/bash

webuser='www-data'

setfacl -R -m u:$webuser:rwx users templates spool webdav
setfacl -R -d -m u:$webuser:rwx users templates spool webdav
