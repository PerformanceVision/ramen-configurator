# Configuration

VERSION = 1.4.0
RAMEN_VERSION = 2.4.0

DUPS_IN = $(shell ocamlfind ocamlc -where)/compiler-libs
OCAMLOPT   = OCAMLPATH=$(OCAMLPATH) OCAMLRUNPARAM= OCAMLFIND_IGNORE_DUPS_IN="$(DUPS_IN)" ocamlfind ocamlopt
OCAMLDEP   = OCAMLPATH=$(OCAMLPATH) OCAMLRUNPARAM= OCAMLFIND_IGNORE_DUPS_IN="$(DUPS_IN)" ocamlfind ocamldep
QTEST      = qtest
WARNS      = -w -40
override OCAMLOPTFLAGS += -I src $(WARNS) -g -annot -O2 -S
override OCAMLFLAGS    += -I src $(WARNS) -g -annot

PACKAGES = \
	batteries cmdliner stdint sqlite3 unix uri

INSTALLED_BIN = src/ramen_configurator
INSTALLED = $(INSTALLED_BIN) alert_sqlite.conf

bin_dir ?= /usr/bin/

all: $(INSTALLED)

# Generic rules

.SUFFIXES: .ml .mli .cmi .cmx .cmxs .annot .html .adoc
.PHONY: clean all dep install uninstall reinstall doc deb tarball \
        docker-latest docker-push

%.cmx %.annot: %.ml
	@echo "Compiling $@ (native code)"
	@$(OCAMLOPT) $(OCAMLOPTFLAGS) -package "$(PACKAGES)" -c $<

%.html: %.adoc
	@echo "Building documentation $@"
	@asciidoc -a data-uri -a icons -a toc -a max-width=55em --theme volnitsky -o $@ $<

# Dependencies

CONFIGURATOR_SOURCES = \
	src/RamenLog.ml src/RamenHelpers.ml \
	src/SqliteHelpers.ml src/Conf_of_sqlite.ml \
	src/ramen_configurator.ml

INSERT_ALERT_SOURCES = \
	src/RamenLog.ml src/RamenHelpers.ml

SOURCES = $(CONFIGURATOR_SOURCES) $(INSERT_ALERT_SOURCES)

dep:
	@$(RM) .depend
	@$(MAKE) .depend

.depend: $(SOURCES)
	@echo "Generating dependencies"
	@$(OCAMLDEP) -I src -package "$(PACKAGES)" $(filter %.ml, $(SOURCES)) $(filter %.mli, $(SOURCES)) > $@

include .depend

# Compiling

src/SqliteHelpers.cmx: src/SqliteHelpers.ml
	@echo "Compiling $@ (native code)"
	@$(OCAMLOPT) $(OCAMLOPTFLAGS) -package "$(PACKAGES)" -c $<

src/Conf_of_sqlite.cmx: src/Conf_of_sqlite.ml
	@echo "Compiling $@ (native code)"
	@$(OCAMLOPT) $(OCAMLOPTFLAGS) -package "$(PACKAGES)" -c $<

src/ramen_configurator: $(CONFIGURATOR_SOURCES:.ml=.cmx)
	@echo "Linking $@"
	@$(OCAMLOPT) $(OCAMLOPTFLAGS) -linkpkg -package "$(PACKAGES)" $(filter %.cmx, $^) -o $@

# Installation

install: $(INSTALLED)
	@echo "Installing binaries into $(prefix)$(bin_dir)"
	@install -d $(prefix)$(bin_dir)
	@install $(INSTALLED_BIN) $(prefix)$(bin_dir)/

uninstall:
	@echo "Uninstalling binaries"
	@$(RM) $(prefix)$(bin_dir)/ramen_configurator

reinstall: uninstall install

# Debian package

deb: ramen_configurator.$(VERSION).deb

tarball: ramen_configurator.$(VERSION).tgz

ramen_configurator.$(VERSION).deb: $(INSTALLED) debian.control
	@echo "Building debian package $@"
	@sudo rm -rf debtmp
	@install -d debtmp/usr/bin debtmp/ramen
	@install $(INSTALLED_BIN) debtmp/usr/bin
	@cp -r ramen_root debtmp/ramen
	@mkdir -p debtmp/DEBIAN
	@cp debian.control debtmp/DEBIAN/control
	@chmod a+x -R debtmp/usr
	@sudo chown root: -R debtmp/usr
	@dpkg --build debtmp
	@mv debtmp.deb $@

ramen_configurator.$(VERSION).tgz: $(INSTALLED) clean-comp
	@echo 'Building tarball $@'
	@$(RM) -r tmp/ramen
	@install -d tmp/ramen
	@install $(INSTALLED) tmp/ramen/
	@for f in $(INSTALLED_BIN) ; do chmod a+x tmp/ramen/$$(basename $$f) ; done
	@cp -r ramen_root tmp/ramen/ramen_root
	@tar c -C tmp ramen | gzip > $@

# Docker images

docker/alert.conf: alert_sqlite.conf
	@ln $< $@

docker/ramen_configurator.$(VERSION).deb: ramen_configurator.$(VERSION).deb
	@ln $< $@

docker-latest: docker/Dockerfile docker/alert.conf docker/protocols docker/services docker/start \
               docker/ramen_configurator.$(VERSION).deb docker/ramen.$(RAMEN_VERSION).deb
	@echo 'Building docker image for nevrax v5.0.x'
	@docker build -t rixed/ramen:pv-5.0.x --squash -f $< docker/

docker-push:
	@echo 'Uploading docker images'
	@docker push rixed/ramen:pv-5.0.x


# Cleaning

clean-comp:
	@find ramen_root/ -\( -name '*.x' -o -name '*.ml' -o -name '*.cmx' -o -name '*.annot' -o -name '*.s' -o -name '*.cmi' -o -name '*.o' -\) -delete

clean: clean-comp
	@echo "Cleaning all build files"
	@$(RM) src/*.cmo src/*.s src/*.annot src/*.o
	@$(RM) src/*.cma src/*.cmx src/*.cmxa src/*.cmxs src/*.cmi
	@$(RM) *.opt src/all_tests.* perf.data* gmon.out
	@$(RM) oUnit-anon.cache qtest.targets.log
	@$(RM) .depend src/*.opt src/*.byte src/*.top
	@$(RM) src/ramen_configurator
	@sudo rm -rf debtmp
	@$(RM) -r tmp
	@$(RM) ramen_configurator.*.deb ramen_configurator.*.tgz
