#!/bin/sh

for i in am dispatcher kopf login; do
	rm $i.pl 2> /dev/null
	ln -s admin.pl $i.pl
done
for i in acctranscorrections amcvar amtemplates ap ar bankaccounts bp ca common cp ct datev dn do fu gl ic ir is licenses menujs menunew menu menuv3 menuv4 menuXML oe pe projects rc rp sepa todo ustva wh vk; do 
	rm $i.pl 2> /dev/null
	ln -s am.pl $i.pl
done
rm generictranslations.pl 2> /dev/null
ln -s common.pl generictranslations.pl
rm dispatcher.fcgi 2> /dev/null
ln -s dispatcher.fpl dispatcher.fcgi
