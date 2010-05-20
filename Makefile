## Makefile --

IKARUS		= ikarus
LARCENY		= larceny
MOSH		= mosh
PETITE		= petite
YPSILON		= ypsilon
VICARE		= vicare

.PHONY: test itest ltest mtest ptest vtest ytest

test: itest ltest mtest ptest vtest ytest

itest:
	IKARUS_LIBRARY_PATH=. $(IKARUS) --r6rs-script test-infix.sps

ltest:
	LARCENY_LIBPATH=. $(LARCENY) -r6rs -program test-infix.sps

mtest:
	MOSH_LOADPATH=. $(MOSH) test-infix.sps

ptest:
	CHEZSCHEMELIBDIRS=. CHEZSCHEMELIBEXTS=.sls $(PETITE) test-infix.sps

vtest:
	VICARE_LIBRARY_PATH=. $(VICARE) --r6rs-script test-infix.sps

ytest:
	YPSILON_SITELIB=. $(YPSILON) test-infix.sps

### end of file
