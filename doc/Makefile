# The Installation Documentation is being written in 'INSTALL.texi' using
# the texinfo syntax. Visit http://www.gnu.org/software/texinfo/ and
# http://cvs.savannah.gnu.org/viewvc/*checkout*/texinfo/doc/refcard/txirefcard-a4.pdf?root=texinfo
#
# In order to generate the files INSTALL.txt and the HTML files under
# INSTALL/ you have to install the 'make' and 'textinfo' packages of
# your operating system.
# Possibly a 'Lx-Office_Installation_DE.pdf' will generated too.
#
# Usage:
# cd doc/
# make

all:
	rm -f INSTALL/*.html
	makeinfo --html      --document-language=de_DE.UTF-8                                  INSTALL.texi
	makeinfo --plaintext --document-language=de_DE.UTF-8 -o INSTALL.txt                   INSTALL.texi
	texi2pdf -p -c -q                                    -o Lx-Office_Installation_DE.pdf INSTALL.texi
