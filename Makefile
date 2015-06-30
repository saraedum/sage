# Main Makefile for Sage.

# The default target ("all") builds Sage and the whole (HTML) documentation.
#
# Target "build" just builds Sage.
#
# See below for targets to build the documentation in other formats,
# to run various types of test suites, and to remove parts of the build etc.

PIPE = build/pipestatus


all: start doc  # indirectly depends on build

logs:
	mkdir -p $@

build: logs configure
	+cd build && \
	"../$(PIPE)" \
		"./install all 2>&1" \
		"tee -a ../logs/install.log"
	+./sage -b

# Preemptively download all standard upstream source tarballs.
download:
	export SAGE_ROOT=$$(pwd) && \
	export PATH=$$SAGE_ROOT/src/bin:$$PATH && \
	./src/bin/sage-download-upstream

# ssl: build Sage, and also install pyOpenSSL. This is necessary for
# running the secure notebook. This make target requires internet
# access. Note that this requires that your system have OpenSSL
# libraries and headers installed. See README.txt for more
# information.
ssl: all
	./sage -i pyopenssl

# Start Sage if the file local/etc/sage-started.txt does not exist
# (i.e. when we just installed Sage for the first time).
start: build
	[ -f local/etc/sage-started.txt ] || local/bin/sage-starts

# You can choose to have the built HTML version of the documentation link to
# the PDF version. To do so, you need to build both the HTML and PDF versions.
# To have the HTML version link to the PDF version, do
#
# $ ./sage --docbuild all html
# $ ./sage --docbuild all pdf
#
# For more information on the docbuild utility, do
#
# $ ./sage --docbuild -H
doc: doc-html

doc-html: build
	$(PIPE) "./sage --docbuild --no-pdf-links all html $(SAGE_DOCBUILD_OPTS) 2>&1" "tee -a logs/dochtml.log"

# 'doc-html-no-plot': build docs without building the graphics coming
# from the '.. plot' directive, in case you want to save a few
# megabytes of disk space. 'doc-clean' is a prerequisite because the
# presence of graphics is cached in src/doc/output.
doc-html-no-plot: build doc-clean
	$(PIPE) "./sage --docbuild --no-pdf-links --no-plot all html $(SAGE_DOCBUILD_OPTS) 2>&1" "tee -a logs/dochtml.log"

doc-html-mathjax: build
	$(PIPE) "./sage --docbuild --no-pdf-links all html -j $(SAGE_DOCBUILD_OPTS) 2>&1" "tee -a logs/dochtml.log"

# Keep target 'doc-html-jsmath' for backwards compatibility.
doc-html-jsmath: doc-html-mathjax

doc-pdf: build
	$(PIPE) "./sage --docbuild all pdf $(SAGE_DOCBUILD_OPTS) 2>&1" "tee -a logs/docpdf.log"

doc-clean:
	cd src/doc && $(MAKE) clean

clean:
	@echo "Deleting package build directories..."
	rm -rf local/var/tmp/sage/build

lib-clean:
	cd src && $(MAKE) clean

bdist-clean: clean
	@echo "Deleting miscellaneous artifacts generated by build system ..."
	rm -rf logs
	rm -rf dist
	rm -rf tmp
	rm -f aclocal.m4 config.log config.status confcache
	rm -rf autom4te.cache
	rm -f build/Makefile build/Makefile-auto
	rm -f .BUILDSTART

distclean: clean doc-clean lib-clean bdist-clean
	@echo "Deleting all remaining output from build system ..."
	rm -rf local

# Delete all auto-generated files which are distributed as part of the
# source tarball
bootstrap-clean:
	rm -rf config configure build/Makefile-auto.in

# Remove absolutely everything which isn't part of the git repo
maintainer-clean: distclean bootstrap-clean
	rm -rf upstream

micro_release: bdist-clean lib-clean
	@echo "Stripping binaries ..."
	LC_ALL=C find local/lib local/bin -type f -exec strip '{}' ';' 2>&1 | grep -v "File format not recognized" |  grep -v "File truncated" || true

TESTALL = ./sage -t --all
PTESTALL = ./sage -t -p --all

test: all
	$(TESTALL) --logfile=logs/test.log

check: test

testall: all
	$(TESTALL) --optional=all --logfile=logs/testall.log

testlong: all
	$(TESTALL) --long --logfile=logs/testlong.log

testalllong: all
	$(TESTALL) --long --optional=all --logfile=logs/testalllong.log

ptest: all
	$(PTESTALL) --logfile=logs/ptest.log

ptestall: all
	$(PTESTALL) --optional=all --logfile=logs/ptestall.log

ptestlong: all
	$(PTESTALL) --long --logfile=logs/ptestlong.log

ptestalllong: all
	$(PTESTALL) --long --optional=all --logfile=logs/ptestalllong.log


testoptional: testall # just an alias

testoptionallong: testalllong # just an alias

ptestoptional: ptestall # just an alias

ptestoptionallong: ptestalllong # just an alias

configure: configure.ac src/bin/sage-version.sh \
        m4/ax_c_check_flag.m4 m4/ax_gcc_option.m4 m4/ax_gcc_version.m4 m4/ax_gxx_option.m4 m4/ax_gxx_version.m4 m4/ax_prog_perl_version.m4
	./bootstrap -d

install:
	echo "Experimental use only!"
	if [ "$(DESTDIR)" = "" ]; then \
		echo >&2 "Set the environment variable DESTDIR to the install path."; \
		exit 1; \
	fi
	# Make sure we remove only an existing directory. If $(DESTDIR)/sage is
	# a file instead of a directory then the mkdir statement later will fail
	if [ -d "$(DESTDIR)"/sage ]; then \
		rm -rf "$(DESTDIR)"/sage; \
	fi
	mkdir -p "$(DESTDIR)"/sage
	mkdir -p "$(DESTDIR)"/bin
	cp -Rp * "$(DESTDIR)"/sage
	rm -f "$(DESTDIR)"/bin/sage
	ln -s ../sage/sage "$(DESTDIR)"/bin/sage
	"$(DESTDIR)"/bin/sage -c # Run sage-location


.PHONY: all build start install micro_release \
	doc doc-html doc-html-jsmath doc-html-mathjax doc-pdf \
	doc-clean clean lib-clean bdist-clean distclean bootstrap-clean maintainer-clean \
	test check testoptional testall testlong testoptionallong testallong \
	ptest ptestoptional ptestall ptestlong ptestoptionallong ptestallong
