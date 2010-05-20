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

## --------------------------------------------------------------------

.PHONY: dist

TMPDIR		?= /tmp
TARFILE		= $(TMPDIR)/wak-infix.tar.gz

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
		wak-infix
	@mv --verbose --force $(TARFILE) "=dist"

### end of file
