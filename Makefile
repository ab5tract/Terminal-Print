.PHONY: all build test install clean distclean purge

PERL6  = perl6
DESTDIR= 
PREFIX = /home/ab5tract/.rakudobrew/moar-HEAD/install/languages/perl6/site
BLIB   = blib
P6LIB  = $(PWD)/$(BLIB)/lib,$(PWD)/lib,$(PERL6LIB)
CP     = cp -p
MKDIR  = mkdir -p


BLIB_COMPILED = $(BLIB)/lib/Terminal/Print/Commands.pm6.moarvm $(BLIB)/lib/Terminal/Print.pm6.moarvm

all build: $(BLIB_COMPILED)

$(BLIB)/lib/Terminal/Print/Commands.pm6.moarvm : lib/Terminal/Print/Commands.pm6
	$(MKDIR) $(BLIB)/lib/Terminal/Print/
	$(CP) lib/Terminal/Print/Commands.pm6 $(BLIB)/lib/Terminal/Print/Commands.pm6
	PERL6LIB=$(P6LIB) $(PERL6) --target=mbc --output=$(BLIB)/lib/Terminal/Print/Commands.pm6.moarvm lib/Terminal/Print/Commands.pm6

$(BLIB)/lib/Terminal/Print.pm6.moarvm : lib/Terminal/Print.pm6
	$(MKDIR) $(BLIB)/lib/Terminal/
	$(CP) lib/Terminal/Print.pm6 $(BLIB)/lib/Terminal/Print.pm6
	PERL6LIB=$(P6LIB) $(PERL6) --target=mbc --output=$(BLIB)/lib/Terminal/Print.pm6.moarvm lib/Terminal/Print.pm6


test: build
	env PERL6LIB=$(P6LIB) prove -e '$(PERL6)' -r t/

loudtest: build
	env PERL6LIB=$(P6LIB) prove -ve '$(PERL6)' -r t/

timetest: build
	env PERL6LIB=$(P6LIB) PERL6_TEST_TIMES=1 prove -ve '$(PERL6)' -r t/

install: $(BLIB_COMPILED)
	$(MKDIR) $(DESTDIR)$(PREFIX)/lib/Terminal/Print/
	$(CP) $(BLIB)/lib/Terminal/Print/Commands.pm6 $(DESTDIR)$(PREFIX)/lib/Terminal/Print/Commands.pm6
	$(CP) $(BLIB)/lib/Terminal/Print/Commands.pm6.moarvm $(DESTDIR)$(PREFIX)/lib/Terminal/Print/Commands.pm6.moarvm
	$(MKDIR) $(DESTDIR)$(PREFIX)/lib/Terminal/
	$(CP) $(BLIB)/lib/Terminal/Print.pm6 $(DESTDIR)$(PREFIX)/lib/Terminal/Print.pm6
	$(CP) $(BLIB)/lib/Terminal/Print.pm6.moarvm $(DESTDIR)$(PREFIX)/lib/Terminal/Print.pm6.moarvm


clean:
	rm -fr $(BLIB)

distclean purge: clean
	rm -r Makefile
