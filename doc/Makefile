# The Installation Documentation is being written in 'INSTALL.texi' using
# the texinfo syntax. Visit http://www.gnu.org/software/texinfo/ and
# http://cvs.savannah.gnu.org/viewvc/*checkout*/texinfo/doc/refcard/txirefcard-a4.pdf?root=texinfo
#
# In order to generate the text, HTML and PDF versions of this
# documentation you have to install the 'make' and 'textinfo' packages
# of your operating system.
#
# Usage:
# cd doc/
# make

all: INSTALL.txt Lx-Office_Installation_DE.pdf

%.txt: %.texi
	makeinfo --html      --document-language=de_DE.UTF-8 -o $(patsubst %.txt,%.html,$@) --no-split $^
	makeinfo --plaintext --document-language=de_DE.UTF-8 -o $@                                     $^

Lx-Office_Installation_DE.pdf: INSTALL.texi
	texi2pdf -p -c -q -o $@ $^
