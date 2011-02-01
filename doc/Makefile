all:
	rm -f INSTALL/*.html
	makeinfo --html      --document-language=de_DE.UTF-8                INSTALL.texi
	makeinfo --plaintext --document-language=de_DE.UTF-8 -o INSTALL.txt INSTALL.texi
