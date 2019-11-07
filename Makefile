# Configuration

VERSION = 3.1.0
RAMEN_VERSION = 4.2.0

DUPS_IN = $(shell ocamlfind ocamlc -where)/compiler-libs
OCAMLOPT   = OCAMLPATH=$(OCAMLPATH) OCAMLRUNPARAM= OCAMLFIND_IGNORE_DUPS_IN="$(DUPS_IN)" ocamlfind ocamlopt
OCAMLDEP   = OCAMLPATH=$(OCAMLPATH) OCAMLRUNPARAM= OCAMLFIND_IGNORE_DUPS_IN="$(DUPS_IN)" ocamlfind ocamldep
QTEST      = qtest
WARNS      = -w -40+27
override OCAMLOPTFLAGS += -I src $(WARNS) -g -annot -O2 -S
override OCAMLFLAGS    += -I src $(WARNS) -g -annot

SOLVER = /usr/bin/z3 -t:300000 -smt2 %s

PACKAGES = \
	batteries cmdliner sqlite3 unix

RAMEN_SOURCES = \
	ramen_root/internal/monitoring/meta.ramen \
	ramen_root/sniffer/csv_files.ramen \
	ramen_root/sniffer/csv_kafka.ramen \
	ramen_root/sniffer/chb_files.ramen \
	ramen_root/sniffer/chb_kafka.ramen \
	ramen_root/sniffer/metrics.ramen \
	ramen_root/sniffer/security/scans.ramen \
	ramen_root/sniffer/security/DDoS.ramen \
	ramen_root/sniffer/top_zones.ramen \
	ramen_root/sniffer/per_zone.ramen \
	ramen_root/sniffer/top_servers.ramen \
	ramen_root/sniffer/per_application.ramen \
	ramen_root/sniffer/autodetect.ramen \
	ramen_root/sniffer/transactions.ramen \
	ramen_root/sniffer/top_errors.ramen

INSTALLED_BIN = src/ramen_configurator
CHECK_COMPILATION = $(RAMEN_SOURCES:.ramen=.x)
INSTALLED = $(INSTALLED_BIN) $(RAMEN_SOURCES)

bin_dir ?= /usr/bin/
lib_dir ?= /var/lib/
conf_dir ?= /etc/ramen/

all: $(INSTALLED) $(CHECK_COMPILATION) src/findcsv

# Generic rules

.SUFFIXES: .ml .mli .cmi .cmx .cmxs .annot .html .adoc .ramen .x .php
.PHONY: clean all dep install uninstall reinstall doc deb tarball \
        docker-latest docker-push

%.cmx %.annot: %.ml
	@echo 'Compiling $@ (native code)'
	@$(OCAMLOPT) $(OCAMLOPTFLAGS) -package "$(PACKAGES)" -c $<

%.html: %.adoc
	@echo 'Building documentation $@'
	@asciidoc -a data-uri -a icons -a toc -a max-width=55em --theme volnitsky -o $@ $<

%.x: %.ramen
	@echo 'Compiling ramen program $@'
	@ramen compile --solver='$(SOLVER)' -L ramen_root $<

# Source files templating

%.ramen: %.php
	@echo 'Expanding $@'
	@php -n $< > $@ || true
	@if grep -e Warning -e 'Parse error:' $@ ; then \
	  rm $@ ;\
	fi

ramen_root/sniffer/chb_files.ramen: ramen_root/sniffer/chb_v30.php ramen_root/sniffer/adapt_chb_types.ramen
ramen_root/sniffer/csv_files.ramen: ramen_root/sniffer/csv_v30.php
ramen_root/sniffer/chb_kafka.ramen: ramen_root/sniffer/chb_v30.php ramen_root/sniffer/adapt_chb_types.ramen
ramen_root/sniffer/csv_kafka.ramen: ramen_root/sniffer/csv_v30.php

# Dependencies

CONFIGURATOR_SOURCES = \
	src/RamenLog.ml src/RamenHelpers.ml \
	src/SqliteHelpers.ml src/Conf_of_sqlite.ml \
	src/ramen_configurator.ml

FINDCSV_SOURCES = \
	src/RamenLog.ml src/RamenHelpers.ml src/findcsv.ml

ramen_root/snigger/metrics.x: ramen_root/sniffer/csv.x ramen_root/sniffer/chb.x
ramen_root/sniffer/security/scans.x: ramen_root/sniffer/metrics.x
ramen_root/sniffer/security/DDoS.x: ramen_root/sniffer/metrics.x
ramen_root/sniffer/top_zones.x: ramen_root/sniffer/metrics.x
ramen_root/sniffer/per_zone.x: ramen_root/sniffer/metrics.x
ramen_root/sniffer/per_zone.x: ramen_root/sniffer/metrics.x
ramen_root/sniffer/top_servers.x: ramen_root/sniffer/metrics.x
ramen_root/sniffer/per_application.x: ramen_root/sniffer/metrics.x
ramen_root/sniffer/transactions.x: ramen_root/sniffer/metrics.x
ramen_root/sniffer/top_errors.x: ramen_root/sniffer/metrics.x
ramen_root/sniffer/autodetect.x: ramen_root/sniffer/per_application.x

FILES_OR_KAFKA ?= files

# That one use parents "../csv" to find out types:
ramen_root/sniffer/metrics.x: \
		ramen_root/sniffer/metrics.ramen \
		ramen_root/sniffer/csv_$(FILES_OR_KAFKA).x \
		ramen_root/sniffer/chb_$(FILES_OR_KAFKA).x
	@echo 'Compiling ramen program $@'
	@ln -sf csv_$(FILES_OR_KAFKA).x ramen_root/sniffer/csv.x
	@ln -sf chb_$(FILES_OR_KAFKA).x ramen_root/sniffer/chb.x
	@ramen compile --solver='$(SOLVER)' -L ramen_root $<

SOURCES = $(CONFIGURATOR_SOURCES) $(FINDCSV_SOURCES)

dep:
	@$(RM) .depend
	@$(MAKE) .depend

.depend: $(SOURCES)
	@echo 'Generating dependencies'
	@$(OCAMLDEP) -I src -package "$(PACKAGES)" $(filter %.ml, $(SOURCES)) $(filter %.mli, $(SOURCES)) > $@

include .depend

# Compiling

src/SqliteHelpers.cmx: src/SqliteHelpers.ml
	@echo 'Compiling $@ (native code)'
	@$(OCAMLOPT) $(OCAMLOPTFLAGS) -package "$(PACKAGES)" -c $<

src/Conf_of_sqlite.cmx: src/Conf_of_sqlite.ml
	@echo 'Compiling $@ (native code)'
	@$(OCAMLOPT) $(OCAMLOPTFLAGS) -package "$(PACKAGES)" -c $<

src/ramen_configurator: $(CONFIGURATOR_SOURCES:.ml=.cmx)
	@echo 'Linking $@'
	@$(OCAMLOPT) $(OCAMLOPTFLAGS) -linkpkg -package "$(PACKAGES)" $(filter %.cmx, $^) -o $@

src/findcsv: $(FINDCSV_SOURCES:.ml=.cmx)
	@echo 'Linking $@'
	@$(OCAMLOPT) $(OCAMLOPTFLAGS) -linkpkg -package batteries $(filter %.cmx, $^) -o $@

# Installation

install-bin: $(INSTALLED_BIN)
	@echo 'Installing binaries into $(prefix)$(bin_dir)'
	@install -d '$(prefix)$(bin_dir)'
	@install $(INSTALLED_BIN) '$(prefix)$(bin_dir)'/

install-sources: $(RAMEN_SOURCES)
	@echo 'Installing Ramen sources into $(prefix)$(lib_dir)'
	@install -d '$(prefix)$(lib_dir)'
	@for f in $(RAMEN_SOURCES) ; do \
	  install -d "$(prefix)$(lib_dir)/$$(dirname $$f)" ; \
	  install "$$f" "$(prefix)$(lib_dir)/$$f" ; \
	done

install-conf: experiments.config
	@echo "Installing configuration samples into $(prefix)$(lib_dir)"
	@install -d "$(prefix)$(lib_dir)"
	@for f in $^ ; do \
	  install "$$f" "$(prefix)$(lib_dir)/$$f" ; \
	done

install: install-bin install-sources install-conf

uninstall:
	@echo Uninstalling
	@for f in $(INSTALLED_BIN); do \
	  $(RM) "$(prefix)$(bin_dir)/$$f" ;\
	done
	@$(RM) -r $(prefix)$(lib_dir)/ramen_root

reinstall: uninstall install

# Debian package

deb: ramen_configurator.$(VERSION).deb

tarball: ramen_configurator.$(VERSION).tgz

ramen_configurator.$(VERSION).deb: debian.control
	@echo 'Building debian package $@'
	@sudo $(RM) -r debtmp
	@$(MAKE) prefix=debtmp/ install
	@mkdir -p debtmp/DEBIAN
	@cp debian.control debtmp/DEBIAN/control
	@sudo chown root: -R debtmp/usr
	@dpkg --build debtmp
	@mv debtmp.deb $@

ramen_configurator.$(VERSION).tgz:
	@echo 'Building tarball $@'
	@$(RM) -r tmp
	@$(MAKE) prefix=tmp/ bin_dir=ramen lib_dir=ramen conf_dir=ramen install
	@tar c -C tmp ramen | gzip > $@

# Docker images

docker/alert.conf: alert_sqlite.conf
	@ln -f $< $@

docker/ramen_configurator.$(VERSION).deb: ramen_configurator.$(VERSION).deb
	@ln -f $< $@

docker-latest: docker/Dockerfile docker/alert.conf docker/protocols docker/services docker/start \
               docker/ramen_configurator.$(VERSION).deb docker/ramen.$(RAMEN_VERSION).deb
	@echo 'Building docker image for nevrax v5.0.x'
	@docker build -t rixed/ramen:pv-5.0.x --squash -f $< docker/

docker-push:
	@echo 'Uploading docker images'
	@docker push rixed/ramen:pv-5.0.x


# Cleaning

clean-comp:
	@find ramen_root/ -\( \
	  -name '*.x' -o -name '*.ml' -o -name '*.cmx' -o -name '*.annot' -o \
	  -name '*.s' -o -name '*.cmi' -o -name '*.o' -o -name '*.smt2' -o \
	  -name '*.smt2.no_opt' -o -name '*.cmt' -o -name '*.cc' \
	-\) -delete

clean: clean-comp
	@echo 'Cleaning all build files'
	@$(RM) src/*.cmo src/*.s src/*.annot src/*.o
	@$(RM) src/*.cma src/*.cmx src/*.cmxa src/*.cmxs src/*.cmi
	@$(RM) *.opt src/all_tests.* perf.data* gmon.out
	@$(RM) oUnit-anon.cache qtest.targets.log
	@$(RM) .depend src/*.opt src/*.byte src/*.top
	@$(RM) src/ramen_configurator
	@sudo rm -rf debtmp
	@$(RM) -r tmp
	@$(RM) ramen_configurator.*.deb ramen_configurator.*.tgz
	@$(RM) ramen_root/sniffer/csv_files.ramen
	@$(RM) ramen_root/sniffer/csv_kafka.ramen
	@$(RM) ramen_root/sniffer/chb_files.ramen
	@$(RM) ramen_root/sniffer/chb_kafka.ramen
