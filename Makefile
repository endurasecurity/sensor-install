.DEFAULT_GOAL := default
.EXPORT_ALL_VARIABLES:
.PHONY: FORCE
SHELL := /bin/bash

# metadata
NAME := sensor-install
BASEDIR := $(dir $(realpath $(lastword $(MAKEFILE_LIST))))
DIST := $(BASEDIR)dist
SRC := $(BASEDIR)src

# logging syntax
define ERROR
	"\033[1;31m[error]\033[0m \033[1;37m[$(@)]\033[0m"
endef

define INFO
	"\033[1;32m[info]\033[0m \033[1;37m[$(@)]\033[0m"
endef

define WARN
	"\033[1;33m[warning]\033[0m \033[1;37m[$(@)]\033[0m"
endef

# bootstrap
bootstrap: FORCE
	@echo -e $(INFO) $(NAME)
	@if command -v dnf &> /dev/null; then \
		sudo -E dnf install -y shellcheck; \
	elif command -v apt-get &> /dev/null; then \
		sudo -E apt-get update; \
		sudo -E apt-get install -y shellcheck; \
	else \
		@echo -e $(ERROR) unsupported system; \
	fi

# clean
clean: FORCE
	@echo -e $(INFO) $(NAME)
	rm -rf $(DIST)

# build
build: FORCE
	@echo -e $(INFO) $(NAME)
	mkdir -p $(DIST)

	cp $(SRC)/latest.sh $(DIST)/latest.sh
	cat $(SRC)/common.sh >> $(DIST)/latest.sh

	cp $(SRC)/testing.sh $(DIST)/testing.sh
	cat $(SRC)/common.sh >> $(DIST)/testing.sh

	cp $(SRC)/stable.sh $(DIST)/stable.sh
	cat $(SRC)/common.sh >> $(DIST)/stable.sh

# test
test: FORCE
	@echo -e $(INFO) $(NAME)
	shellcheck $(DIST)/*.sh

# world
world: clean build test

# default
default: world
