# Configuration

VERSION = 1.0.0

DUPS_IN = $(shell ocamlfind ocamlc -where)/compiler-libs
OCAMLOPT   = OCAMLPATH=$(OCAMLPATH) OCAMLRUNPARAM= OCAMLFIND_IGNORE_DUPS_IN="$(DUPS_IN)" ocamlfind ocamlopt
OCAMLDEP   = OCAMLPATH=$(OCAMLPATH) OCAMLRUNPARAM= OCAMLFIND_IGNORE_DUPS_IN="$(DUPS_IN)" ocamlfind ocamldep
QTEST      = qtest
WARNS      = -w -40
override OCAMLOPTFLAGS += -I src $(WARNS) -g -annot -O2 -S
override OCAMLFLAGS    += -I src $(WARNS) -g -annot

PACKAGES = \
	batteries cmdliner stdint sqlite3 unix uri

INSTALLED_BIN = src/ramen_configurator src/insert_alert
INSTALLED = $(INSTALLED_BIN)

bin_dir ?= /usr/bin/

all: $(INSTALLED)

# Generic rules

.SUFFIXES: .ml .mli .cmi .cmx .cmxs .annot .html .adoc
.PHONY: clean all dep install uninstall reinstall doc deb

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
	src/RamenLog.ml src/RamenHelpers.ml \
	src/SqliteHelpers.ml src/insert_alert.ml

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

src/insert_alert: $(INSERT_ALERT_SOURCES:.ml=.cmx)
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

ramen_configurator.$(VERSION).deb: $(INSTALLED) debian.control
	@echo "Building debian package $@"
	@sudo rm -rf debtmp
	@install -d debtmp/usr/bin
	@install $(INSTALLED_BIN) debtmp/usr/bin
	@mkdir -p debtmp/DEBIAN
	@cp debian.control debtmp/DEBIAN/control
	@chmod a+x -R debtmp/usr
	@sudo chown root: -R debtmp/usr
	@dpkg --build debtmp
	@mv debtmp.deb $@

# Cleaning

clean:
	@echo "Cleaning all build files"
	@$(RM) src/*.cmo src/*.s src/*.annot src/*.o
	@$(RM) src/*.cma src/*.cmx src/*.cmxa src/*.cmxs src/*.cmi
	@$(RM) *.opt src/all_tests.* perf.data* gmon.out
	@$(RM) oUnit-anon.cache qtest.targets.log
	@$(RM) .depend src/*.opt src/*.byte src/*.top
	@$(RM) src/ramen_configurator
	@sudo rm -rf debtmp
	@$(RM) ramen_configurator.*.deb
