# Makefile.in for building crosstool-NG
# This file serves as source for the ./configure operation

# This series of test is here because GNU make 3.81 will *not* use MAKEFLAGS
# to set additional flags in the current Makfile ( see:
# http://savannah.gnu.org/bugs/?20501 ), although the make manual says it
# should ( see: http://www.gnu.org/software/make/manual/make.html#Options_002fRecursion )
# so we have to work it around by calling ourselves back if needed

# So why do we need not to use the built rules and variables? Because we
# need to generate scripts/crosstool-NG.sh from scripts/crosstool-NG.sh.in
# and there is a built-in implicit rule '%.sh:' that has neither a pre-requisite
# nor a command associated, and that built-in implicit rule takes precedence
# over our non-built-in implicit rule '%: %.in', below.

# CT_MAKEFLAGS will be used later, below...

# Do not print directories as we descend into them
ifeq ($(filter --no-print-directory,$(MAKEFLAGS)),)
CT_MAKEFLAGS += --no-print-directory
endif

# Use neither builtin rules, nor builtin variables
# Note: dual test, because if -R and -r are given on the command line
# (who knows?), MAKEFLAGS contains 'Rr' instead of '-Rr', while adding
# '-Rr' to MAKEFLAGS adds it literaly ( and does not add 'Rr' )
ifeq ($(filter Rr,$(MAKEFLAGS)),)
ifeq ($(filter -Rr,$(MAKEFLAGS)),)
CT_MAKEFLAGS += -Rr
endif # No -Rr
endif # No Rr

# Remove any suffix rules
.SUFFIXES:

all: Makefile build

###############################################################################
# Configuration variables

# Stuff found by ./configure
export DATE            := 20121025
export LOCAL           := no
export PROG_SED        := s,x,x,
export PACKAGE_TARNAME := crosstool-ng
export VERSION         := 1.16.0
export prefix          := /usr/local
export exec_prefix     := ${prefix}
export bindir          := ${exec_prefix}/bin
export libdir          := ${exec_prefix}/lib/ct-ng.${VERSION}
export docdir          := ${datarootdir}/doc/${PACKAGE_TARNAME}/ct-ng.${VERSION}
export mandir          := ${datarootdir}/man
export datarootdir     := ${prefix}/share
export install         := /usr/bin/install -c
export bash            := /usr/bin/bash
export awk             := /usr/bin/awk
export grep            := /usr/bin/grep
export make            := /usr/bin/make
export sed             := /usr/bin/sed
export libtool         := /usr/bin/libtool
export libtoolize      := /usr/bin/libtoolize
export objcopy         := /usr/bin/objcopy
export objdump         := /usr/bin/objdump
export readelf         := /usr/bin/readelf
export patch           := /usr/bin/patch
export CC              := gcc
export CPP             := gcc -E
export CPPFLAGS        := 
export CFLAGS          := -g -O2
export LDFLAGS         := 
export LIBS            := -lncursesw 
export curses_hdr      := ncurses/ncurses.h
export gettext         := y

# config options to push down to kconfig
KCONFIG:=  has_xz=y has_lzma has_cvs=y has_svn=y

###############################################################################
# Non-configure variables
MAN_SECTION := 1
MAN_SUBDIR := /man$(MAN_SECTION)

PROG_NAME := $(shell echo 'ct-ng' |$(sed) -r -e '$(PROG_SED)' )

###############################################################################
# Sanity checks

# Check if Makefile is up to date:
Makefile: Makefile.in
	@echo "$< did changed: you must re-run './configure'"
	@false

# If installing with DESTDIR, check it's an absolute path
ifneq ($(strip $(DESTDIR)),)
  ifneq ($(DESTDIR),$(abspath /$(DESTDIR)))
    $(error DESTDIR is not an absolute PATH: '$(DESTDIR)')
  endif
endif

###############################################################################
# Global make rules

# If any extra MAKEFLAGS were added, re-run ourselves
# See top of file for an explanation of why this is needed...
ifneq ($(strip $(CT_MAKEFLAGS)),)

# Somehow, the new auto-completion for make in the recent distributions
# trigger a behavior where our Makefile calls itself recursively, in a
# never-ending loop (except on lack of ressources, swap, PIDs...)
# Avoid this situation by cutting the recursion short at the first
# level.
# This has the side effect of only showing the real targets, and hiding our
# internal ones. :-)
ifneq ($(MAKELEVEL),0)
$(error Recursion detected, bailing out...)
endif

MAKEFLAGS += $(CT_MAKEFLAGS)
build install clean distclean mrproper uninstall:
	@$(MAKE) $@

else
# There were no additional MAKEFLAGS to add, do the job

TARGETS := bin lib lib-kconfig doc man

build: $(patsubst %,build-%,$(TARGETS))

install: build real-install

clean: $(patsubst %,clean-%,$(TARGETS))

distclean: clean
	@echo "  RM     'Makefile'"
	@rm -f Makefile

mrproper: distclean
	@echo "  RM     'autostuff'"
	@ rm -rf autom4te.cache config.log config.status configure

uninstall: real-uninstall

###############################################################################
# Specific make rules

#--------------------------------------
# Build rules

build-bin: $(PROG_NAME)             \
           scripts/crosstool-NG.sh  \
           scripts/saveSample.sh    \
           scripts/showTuple.sh
	@chmod 755 $^

build-lib: config/configure.in  \
           paths.mk             \
           paths.sh

build-lib-kconfig:
	@$(MAKE) -C kconfig

build-doc:

build-man: docs/$(PROG_NAME).1.gz

docs/$(PROG_NAME).1.gz: docs/$(PROG_NAME).1
	@echo "  GZIP   '$@'"
	@gzip -c9 $< >$@

define sed_it
	@echo "  SED    '$@'"
	@$(sed) -r -e 's,@@CT_BINDIR@@,$(bindir),g;'        \
	           -e 's,@@CT_LIBDIR@@,$(libdir),g;'        \
	           -e 's,@@CT_DOCDIR@@,$(docdir),g;'        \
	           -e 's,@@CT_MANDIR@@,$(mandir),g;'        \
	           -e 's,@@CT_PROG_NAME@@,$(PROG_NAME),g;'  \
	           -e 's,@@CT_VERSION@@,$(VERSION),g;'	    \
	           -e 's,@@CT_DATE@@,$(DATE),g;'            \
	           -e 's,@@CT_make@@,$(make),g;'            \
	           -e 's,@@CT_bash@@,$(bash),g;'            \
	           -e 's,@@CT_awk@@,$(awk),g;'              \
	           $< >$@
endef

docs/$(PROG_NAME).1: docs/ct-ng.1.in Makefile
	$(call sed_it)

$(PROG_NAME): ct-ng.in Makefile
	$(call sed_it)

%: %.in Makefile
	$(call sed_it)

# We create a script fragment that is parseable from inside a Makefile,
# and one from inside a shell script
paths.mk: FORCE
	@echo "  GEN    '$@'"
	@(echo 'export install=$(install)';         \
	  echo 'export bash=$(bash)';               \
	  echo 'export awk=$(awk)';                 \
	  echo 'export grep=$(grep)';               \
	  echo 'export make=$(make)';               \
	  echo 'export sed=$(sed)';                 \
	  echo 'export libtool=$(libtool)';         \
	  echo 'export libtoolize=$(libtoolize)';   \
	  echo 'export objcopy=$(objcopy)';         \
	  echo 'export objdump=$(objdump)';         \
	  echo 'export readelf=$(readelf)';         \
	  echo 'export patch=$(patch)';             \
	 ) >$@

paths.sh: FORCE
	@echo "  GEN    '$@'"
	@(echo 'export install="$(install)"';       \
	  echo 'export bash="$(bash)"';             \
	  echo 'export awk="$(awk)"';               \
	  echo 'export grep="$(grep)"';             \
	  echo 'export make="$(make)"';             \
	  echo 'export sed="$(sed)"';               \
	  echo 'export libtool="$(libtool)"';       \
	  echo 'export libtoolize="$(libtoolize)"'; \
	  echo 'export objcopy="$(objcopy)"';       \
	  echo 'export objdump="$(objdump)"';       \
	  echo 'export readelf="$(readelf)"';       \
	  echo 'export patch="$(patch)"';           \
	 ) >$@

config/configure.in: FORCE
	@echo "  GEN    '$@'"
	@{  printf "# Generated file, do not edit\n";            \
	    printf "# Default values as found by ./configure\n"; \
	    for var in $(KCONFIG); do                            \
	        printf "\n";                                     \
	        printf "config CONFIGURE_$${var%%=*}\n";         \
	        if [ "$${var#*=}" = "y" ]; then                  \
	            printf "    def_bool y\n";                   \
	        else                                             \
	            printf "    bool\n";                         \
	        fi;                                              \
	    done;                                                \
	 } >$@

FORCE:

#--------------------------------------
# Clean rules

clean-bin:
	@echo "  RM     '$(PROG_NAME)'"
	@rm -f $(PROG_NAME)
	@echo "  RM     'scripts/crosstool-NG.sh'"
	@rm -f scripts/crosstool-NG.sh
	@echo "  RM     'scripts/saveSample.sh'"
	@rm -f scripts/saveSample.sh
	@echo "  RM     'scripts/showTuple.sh'"
	@rm -f scripts/showTuple.sh

clean-lib:
	@echo "  RM     'paths'"
	@rm -f paths.mk paths.sh
	@echo "  RM     'config/configure.in'"
	@rm -f config/configure.in

clean-lib-kconfig:
	@$(MAKE) -C kconfig clean

clean-doc:

clean-man:
	@echo "  RM     'docs/$(PROG_NAME).1'"
	@rm -f docs/$(PROG_NAME).1
	@echo "  RM     'docs/$(PROG_NAME).1.gz'"
	@rm -f docs/$(PROG_NAME).1.gz

#--------------------------------------
# Check for --local setup

ifeq ($(strip $(LOCAL)),yes)

real-install:
	@true

real-uninstall:
	@true

else

#--------------------------------------
# Install rules

real-install: $(patsubst %,install-%,$(TARGETS)) install-post

install-bin: $(DESTDIR)$(bindir)
	@echo "  INST    '$(PROG_NAME)'"
	@$(install) -m 755 $(PROG_NAME) "$(DESTDIR)$(bindir)/$(PROG_NAME)"

# If one is hacking crosstool-NG, the patch set might change between any two
# installations of the same VERSION, thus the patches must be removed prior
# to being installed. It is simpler to remove the whole lib/ directory, as it
# is the goal of the install-lib rule to install the lib/ directory...
install-lib: uninstall-lib          \
             $(DESTDIR)$(libdir)    \
             install-lib-main       \
             install-lib-samples

LIB_SUB_DIR := config contrib patches scripts
$(patsubst %,install-lib-%-copy,$(LIB_SUB_DIR)): $(DESTDIR)$(libdir)
	@echo "  INSTDIR '$(patsubst install-lib-%-copy,%,$(@))/'"
	@tar cf - --exclude='*.sh.in' $(patsubst install-lib-%-copy,%,$(@)) \
	 |(cd "$(DESTDIR)$(libdir)"; tar xf -)

# Huh? It seems we need at least one command to make this rule kick-in.
install-lib-%: install-lib-%-copy; @true

# Huh? that one does not inherit the -opy dependency, above...
install-lib-scripts: install-lib-scripts-copy
	@chmod a+x $(DESTDIR)$(libdir)/scripts/crosstool-NG.sh
	@chmod a+x $(DESTDIR)$(libdir)/scripts/saveSample.sh
	@rm -f "$(DESTDIR)$(libdir)/scripts/addToolVersion.sh"

install-lib-main: $(DESTDIR)$(libdir) $(patsubst %,install-lib-%,$(LIB_SUB_DIR))
	@echo "  INST    'steps.mk'"
	@$(install) -m 644 steps.mk "$(DESTDIR)$(libdir)/steps.mk"
	@echo "  INST    'paths'"
	@$(install) -m 644 paths.mk paths.sh "$(DESTDIR)$(libdir)"

# Samples need a little love:
#  - change every occurrence of CT_TOP_DIR to CT_LIB_DIR
install-lib-samples: $(DESTDIR)$(libdir) install-lib-main
	@echo "  INSTDIR 'samples/'"
	@for samp_dir in samples/*/; do                                         \
	     mkdir -p "$(DESTDIR)$(libdir)/$${samp_dir}";                       \
	     $(sed) -r -e 's:\$$\{CT_TOP_DIR\}:\$$\{CT_LIB_DIR\}:;'             \
	               -e 's:^(CT_WORK_DIR)=.*:\1="\$${CT_TOP_DIR}/.build":;'   \
	            $${samp_dir}/crosstool.config                               \
	            >"$(DESTDIR)$(libdir)/$${samp_dir}/crosstool.config";       \
	     $(install) -m 644 "$${samp_dir}/reported.by"                       \
	                       "$(DESTDIR)$(libdir)/$${samp_dir}";              \
	     for libc_cfg in "$${samp_dir}/"*libc*.config; do                   \
	         [ -f "$${libc_cfg}" ] || continue;                             \
	         $(install) -m 644 "$${libc_cfg}"                               \
	                           "$(DESTDIR)$(libdir)/$${samp_dir}";          \
	     done;                                                              \
	 done
	@$(install) -m 644 samples/samples.mk "$(DESTDIR)$(libdir)/samples/samples.mk"

KCONFIG_FILES := conf mconf nconf kconfig.mk
install-lib-kconfig: $(DESTDIR)$(libdir) install-lib-main
	@echo "  INST    'kconfig/'"
	@for f in $(KCONFIG_FILES); do                                      \
	    install -D "kconfig/$${f}" "$(DESTDIR)$(libdir)/kconfig/$${f}"; \
	 done

install-doc: $(DESTDIR)$(docdir)
	@echo "  INST    'docs/*.txt'"
	@for doc_file in docs/*.txt; do                              \
	     $(install) -m 644 "$${doc_file}" "$(DESTDIR)$(docdir)"; \
	 done

install-man: $(DESTDIR)$(mandir)$(MAN_SUBDIR)
	@echo "  INST    '$(PROG_NAME).1.gz'"
	@$(install) -m 644 docs/$(PROG_NAME).1.gz "$(DESTDIR)$(mandir)$(MAN_SUBDIR)"

$(sort $(DESTDIR)$(bindir) $(DESTDIR)$(libdir) $(DESTDIR)$(docdir) $(DESTDIR)$(mandir)$(MAN_SUBDIR)):
	@echo "  MKDIR   '$@/'"
	@$(install) -m 755 -d "$@"

install-post:
	@echo
	@echo "For auto-completion, do not forget to install '$(PROG_NAME).comp' into"
	@echo "your bash completion directory (usually /etc/bash_completion.d)"

#--------------------------------------
# Uninstall rules

real-uninstall: $(patsubst %,uninstall-%,$(TARGETS))

uninstall-bin:
	@echo "  RM      '$(DESTDIR)$(bindir)/$(PROG_NAME)'"
	@rm -f "$(DESTDIR)$(bindir)/$(PROG_NAME)"

uninstall-lib:
	@echo "  RMDIR   '$(DESTDIR)$(libdir)/'"
	@rm -rf "$(DESTDIR)$(libdir)"

uninstall-doc:
	@echo "  RMDIR   '$(DESTDIR)$(docdir)/'"
	@rm -rf "$(DESTDIR)$(docdir)"

uninstall-man:
	@echo "  RM      '$(DESTDIR)$(mandir)$(MAN_SUBDIR)/$(PROG_NAME).1.gz'"
	@rm -f "$(DESTDIR)$(mandir)$(MAN_SUBDIR)/$(PROG_NAME).1"{,.gz}

endif # Not --local

endif # No extra MAKEFLAGS were added

.PHONY: build $(patsubst %,build-%,$(TARGETS)) install
