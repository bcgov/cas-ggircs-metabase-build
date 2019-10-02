SHELL := /usr/bin/env bash
PATHFINDER_PREFIX := wksv3k
PROJECT_PREFIX := cas-ggircs-

THIS_FILE := $(lastword $(MAKEFILE_LIST))
include .pipeline/*.mk

.PHONY: help
help: $(call make_help,help,Explains how to use this Makefile)
	@@exit 0

.PHONY: targets
targets: $(call make_help,targets,Lists all targets in this Makefile)
	$(call make_list_targets,$(THIS_FILE))

.PHONY: whoami
whoami: $(call make_help,whoami,Prints the name of the user currently authenticated via `oc`)
	$(call oc_whoami)

.PHONY: project
project: whoami
project: $(call make_help,project,Switches to the desired $$OC_PROJECT namespace)
	$(call oc_project)

.PHONY: lint
lint: $(call make_help,lint,Checks the configured yml template definitions against the remote schema using the tools namespace)
lint: OC_PROJECT=$(OC_TOOLS_PROJECT)
lint: whoami
	$(call oc_lint)

.PHONY: configure
configure: $(call make_help,configure,Configures the tools project namespace for a build)
configure: OC_PROJECT=$(OC_TOOLS_PROJECT)
configure: whoami
	$(call oc_configure)

INCREMENTAL_BUILD=true
OC_TEMPLATE_VARS += INCREMENTAL_BUILD=$(INCREMENTAL_BUILD)

.PHONY: build
build: $(call make_help,build,Builds the source into an image in the tools project namespace)
build: OC_PROJECT=$(OC_TOOLS_PROJECT)
build: whoami
	$(call oc_build,$(PROJECT_PREFIX)metabase-build)
	$(call oc_build,$(PROJECT_PREFIX)metabase)

METABASE_DB = "metabase"
METABASE_USER = "metabase"

.PHONY: install
install: whoami
	$(eval METABASE_PASSWORD = $(shell if [ -n "$$($(OC) -n "$(OC_PROJECT)" get secret/$(PREFIX)metabase-postgres --ignore-not-found -o name)" ]; then \
$(OC) -n "$(OC_PROJECT)" get secret/$(PREFIX)metabase-postgres -o go-template='{{index .data "database-password"}}' | base64 -d; else \
openssl rand -base64 32 | tr -d /=+ | cut -c -16; fi))
	$(eval OC_TEMPLATE_VARS += METABASE_PASSWORD="$(shell echo -n "$(METABASE_PASSWORD)" | base64)" METABASE_USER="$(shell echo -n "$(METABASE_USER)" | base64)" METABASE_DB="$(shell echo -n "$(METABASE_DB)" | base64)")
	$(eval OC_TEMPLATE_VARS += ROUTE_SUFFIX=$(ROUTE_SUFFIX))
	$(call oc_create_secrets)
	$(call oc_exec_all_pods,cas-postgres-master,create-user-db $(METABASE_USER) $(METABASE_DB) $(METABASE_PASSWORD))
	$(call oc_exec_all_pods,cas-postgres-workers,create-citus-in-db $(METABASE_DB))
	$(call oc_promote,$(PROJECT_PREFIX)metabase)
	$(call oc_wait_for_deploy_ready,cas-postgres-master)
	$(call oc_deploy)
	$(call oc_wait_for_deploy_ready,$(PROJECT_PREFIX)metabase)

.PHONY: install_dev
install_dev: OC_PROJECT=$(OC_DEV_PROJECT)
install_dev: ROUTE_SUFFIX="-dev"
install_dev: install

.PHONY: install_test
install_test: OC_PROJECT=$(OC_TEST_PROJECT)
install_test: ROUTE_SUFFIX="-test"
install_test: install

.PHONY: install_prod
install_prod: OC_PROJECT=$(OC_PROD_PROJECT)
install_prod: install
