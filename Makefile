## Makefile --

PACKAGE_NAME	= infix
PACKAGE_VERSION	= 1.0.0

IKARUS		= ikarus
LARCENY		= larceny
MOSH		= mosh
PETITE		= petite
PLT		= plt-r6rs
YPSILON		= ypsilon
VICARE		= vicare

srcdir		= .
testdir		= $(srcdir)/tests

.PHONY: all test itest ltest mtest ptest vtest ytest ztest

all:

test: itest ltest mtest ptest vtest ytest ztest

itest:
	IKARUS_LIBRARY_PATH=. $(IKARUS) --r6rs-script $(testdir)/test-infix.sps

ltest:
	LARCENY_LIBPATH=. $(LARCENY) -r6rs -program $(testdir)/test-infix.sps

mtest:
	MOSH_LOADPATH=. $(MOSH) $(testdir)/test-infix.sps

ptest:
	CHEZSCHEMELIBDIRS=. CHEZSCHEMELIBEXTS=.sls $(PETITE) --program $(testdir)/test-infix.sps

vtest:
	VICARE_LIBRARY_PATH=. $(VICARE) --r6rs-script $(testdir)/test-infix.sps

ytest:
	YPSILON_SITELIB=. $(YPSILON) $(testdir)/test-infix.sps

ztest:
	plt-r6rs ++path $(srcdir) $(testdir)/test-infix.sps

## --------------------------------------------------------------------

.PHONY: dist

TMPDIR		?= /tmp
TARFILE		= $(TMPDIR)/$(PACKAGE_NAME)-$(PACKAGE_VERSION).tar.gz

dist:
	-@test -d "=dist" || mkdir "=dist"
	-@test -f "=dist"/$(TARFILE) && rm -f "=dist"/$(TARFILE)
	@tar --directory=.. --verbose --create --gzip --file=$(TARFILE)		\
		--exclude=RCS                   --exclude=CVS                   \
		--exclude=.git			--exclude=.git\*		\
		--exclude=archives              --exclude=\*.ps			\
		--exclude=\*.dvi                --exclude=tmp			\
		--exclude=\*.gz                 --exclude=\*.tar                \
		--exclude=\*.so                 --exclude=\*.o			\
		--exclude=\*.a                  --exclude=\*.rpm                \
		--exclude=\*.deb                --exclude=.emacs\*		\
		--exclude=\*~                   --exclude=TAGS                  \
		--exclude=config.log            --exclude=config.status         \
		--exclude=config.cache						\
		--exclude=autom4te.cache	--exclude="{arch}"              \
		--exclude=.arch-ids		--exclude=\+\+\*                \
		--exclude=\=\*							\
		infix
	@mv --verbose --force $(TARFILE) "=dist"

### end of file
