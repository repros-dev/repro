# This is the top-level Makefile for this REPRO.
# Type 'make' with no arguments to list the available targets.

# detect if running in a Windows environment
ifeq ('$(OS)', 'Windows_NT')
PWSH=powershell -noprofile -command
endif

MAKE ?= make

# by default invoke the `list` target run if no argument is provided to make
default_target: list

TARGET_NOT_SUPPORTED_IN_RUNNING_REPRO = $(error The '$@' target is not supported in a running REPRO)

# Include optional repro-config file to to override default REPRO settings.
-include repro-config

#- 
#- ============================== REPRO SETTINGS ===============================

#- 
#- --- REPRO_SERVICES_STARTUP --------------------------------------------------
#- 
#-    auto : Services start automatically when the REPRO starts (DEFAULT).
#-  manual : Services start when the start-services target is invoked manually.
#
REPRO_SERVICES_STARTUP ?= auto

#- 
#- --- REPRO_LOGGING_LEVEL -----------------------------------------------------
#- 
#-    none : The REPRO framework will perform no logging.
#-   alert : Only alerts and error messages will be logged.
#-    warn : Alerts, errors and warning messages will be logged (DEFAULT).
#-    info : Alerts, errors, warnings and informational messages will be logged.
#-   debug : Detailed messages will be included in log output along with script 
#-           and Makefile target invocation records.
#-   trace : REPRO will additionally log tracepoints placed at function entry
#-           and return points, etc.
#
REPRO_LOGGING_LEVEL ?= warn

#- 
#- --- REPRO_LOGGING_FILENAME --------------------------------------------------
#- 
#-    auto : Name log unqiuely using current time: [timestamp].log (DEFAULT)
#-  [name] : Use variable value to name the log file: [name]
# 
REPRO_LOGGING_FILENAME ?= auto

#- 
#- --- REPRO_LOGGING_OPTIONS ---------------------------------------------------
#- 
#-  NO_TIMESTAMPS : Messages will not be prepended by timestamps.
#-  NO_LOCATIONS  : Source file locations will not be included in trace messages.
#-  NO_APPEND     : Overwrite log file rather than appending to it.
#
REPRO_LOGGING_OPTIONS ?= NO_LOCATIONS

#- 
#- --- REPRO_INTERACTIVE_SESSION -----------------------------------------------
#- 
#-   true : Session is interactive (DEFAULT).
#-  false : Session is non-interactive. Prompts for input will use defaults.
#
REPRO_INTERACTIVE_SESSION ?= true

REPRO_LOGGING_DIRNAME ?= .repro-logs


#- 
#- --- DOCKER_BUILD_PROGRESS ---------------------------------------------------
#- 
#-    tty : Hide output of cached docker build steps (DEFAULT).
#-  plain : Show all docker build output.
#
DOCKER_BUILD_PROGRESS ?= tty

# Use working directory as name of REPRO if REPRO_NAME undefined.
ifndef REPRO_NAME
REPRO_NAME=$(shell basename $$(pwd))
$(warning The REPRO_NAME variable is not set. Defaulting to \
          working directory name '${REPRO_NAME}' for name of REPRO.)
endif

# Use name of user for Docker organization if REPRO_DOCKER_ORG undefined.
ifndef REPRO_DOCKER_ORG
REPRO_DOCKER_ORG=$(shell whoami)
$(warning The REPRO_DOCKER_ORG variable is not set. Defaulting to \
          user name '${REPRO_DOCKER_ORG}' for name of Docker organization.)
endif

# Use 'latest' as image tag if REPRO_IMAGE_TAG undefined
ifndef REPRO_IMAGE_TAG
REPRO_IMAGE_TAG=latest
$(warning The REPRO_IMAGE_TAG variable is not set. Defaulting to \
          '${REPRO_IMAGE_TAG}' for Docker image tag.)
endif

# Identify the Docker image associated with this REPRO
REPRO_IMAGE ?= ${REPRO_DOCKER_ORG}/${REPRO_NAME}:${REPRO_IMAGE_TAG}

# Get the Docker image ID for this image if it already exists
REPRO_IMAGE_ID ?= $(shell docker image inspect -f "{{.Id}}" ${REPRO_IMAGE})

# define mount point for REPRO directory tree in running container
REPRO_MNT ?= /mnt/${REPRO_NAME}

# define logs directory relative to REPRO mount point
REPRO_LOGS_DIR ?= ${REPRO_MNT}/${REPRO_LOGGING_DIRNAME}

#- 
#- ========================== REPRO TARGETS ====================================

## 
## --------- Targets for understanding and maintaining this Makefile -----------
## 

list:              ## List Makefile targets (default target).
ifdef PWSH
	@${PWSH} "Get-ChildItem .repro | Select-String -Pattern '#\# ' | % {$$_.Line.replace('##','')}"
else
	@sed -ne '/@sed/!s/#[#] //p' $(MAKEFILE_LIST)
endif

help:              ## Show detailed Makefile help.
ifdef PWSH
	@${PWSH} "Get-ChildItem .repro | Select-String -Pattern '#\# ' | % {$$_.Line.replace('##','')}"
else
	@sed -ne '/@sed/!s/#[#-] //p' $(MAKEFILE_LIST)
endif

## 
upgrade-makefile:  ## Replace local REPRO Makefile with latest version 
                   ## of Makefile on repros-dev/repro master branch.
	curl -L https://raw.githubusercontent.com/repros-dev/repro/master/Makefile -o Makefile

upgrade-makefile-tests:  
	curl -L https://raw.githubusercontent.com/repros-dev/repro/master/Makefile-tests -o Makefile-tests


ifndef IN_RUNNING_REPRO

## 
## ---------- Targets for managing the Docker image for this REPRO -------------
## 
build-image:       ## Build this REPRO's Docker image.
	docker build --build-arg PARENT_IMAGE=${PARENT_IMAGE} --progress=${DOCKER_BUILD_PROGRESS} -t ${REPRO_IMAGE} .

rebuild-image:     ## Force rebuild of this REPRO's Docker image.
	docker build --build-arg PARENT_IMAGE=${PARENT_IMAGE} --progress=${DOCKER_BUILD_PROGRESS} --no-cache -t ${REPRO_IMAGE} .

pull-image:        ## Pull this REPRO's Docker image from Docker Hub.
	docker pull ${REPRO_IMAGE}

push-image:        ## Push this REPRO's Docker image to Docker Hub.
	docker push ${REPRO_IMAGE}

##  
## ---------- Targets for building a custom parent image  ----------------------
## 
ifdef PARENT_IMAGE

build-parent:      ## Build the custom parent Docker image.
	docker build --build-arg PARENT_BUILD_ARG_1=${PARENT_BUILD_ARG_1} --progress=${DOCKER_BUILD_PROGRESS} -f Dockerfile-parent -t ${PARENT_IMAGE} .

rebuild-parent:    ## Force rebuild of the custom Docker image.
	docker build --build-arg PARENT_BUILD_ARG_1=${PARENT_BUILD_ARG_1} --progress=${DOCKER_BUILD_PROGRESS} --no-cache -f Dockerfile-parent -t ${PARENT_IMAGE} .

pull-parent:       ## Pull the custom parent image from Docker Hub.
	docker pull ${PARENT_IMAGE}

push-parent:       ## Push the custom parent image to Docker Hub.
	docker push ${PARENT_IMAGE}

endif # ifdef PARENT_IMAGE

endif # ifndef IN_RUNNING_REPRO

ifeq ($(REPRO_LOGGING_LEVEL), debug)
QUIET=
else ifeq ($(REPRO_LOGGING_LEVEL), trace)
QUIET=
else 
QUIET=@
endif

SESSION_DIR=.repro-sessions/active
SESSION_ENV_FILE=${SESSION_DIR}/session.env

OS_APPEND_ENV=echo >> $(SESSION_ENV_FILE)
OS_CREATE_DIR=mkdir -p
OS_TRUNCATE_FILE=echo >

PHONY: session repro-logs
repro-logs:
ifndef IN_RUNNING_REPRO
	$(shell $(OS_CREATE_DIR) ${REPRO_LOGGING_DIRNAME})
endif

session: repro-logs
ifndef IN_RUNNING_REPRO
	$(shell $(OS_CREATE_DIR) ${SESSION_DIR})
	$(shell $(OS_TRUNCATE_FILE) $(SESSION_ENV_FILE))
	$(shell $(OS_APPEND_ENV) REPRO_NAME=$(REPRO_NAME))
	$(shell $(OS_APPEND_ENV) REPRO_MNT=$(REPRO_MNT))
	$(shell $(OS_APPEND_ENV) REPRO_TAG=$(REPRO_IMAGE))
	$(shell $(OS_APPEND_ENV) REPRO_IMAGE_ID=$(REPRO_IMAGE_ID))
	$(shell $(OS_APPEND_ENV) REPRO_SERVICES_STARTUP=$(REPRO_SERVICES_STARTUP))
	$(shell $(OS_APPEND_ENV) REPRO_LOGS_DIR=$(REPRO_LOGS_DIR))
	$(shell $(OS_APPEND_ENV) REPRO_LOGGING_LEVEL=$(REPRO_LOGGING_LEVEL))
	$(shell $(OS_APPEND_ENV) REPRO_LOGGING_FILENAME=$(REPRO_LOGGING_FILENAME))
	$(shell $(OS_APPEND_ENV) REPRO_LOGGING_OPTIONS=$(REPRO_LOGGING_OPTIONS))
	$(shell $(OS_APPEND_ENV) REPRO_INTERACTIVE_SESSION=$(REPRO_INTERACTIVE_SESSION))
	$(shell docker version > ${SESSION_DIR}/docker.yaml)
	$(shell docker inspect ${REPRO_IMAGE_ID} > ${SESSION_DIR}/image.json)
else
	@:
endif

# define command for running the REPRO Docker image
REPRO_RUN_COMMAND=$(QUIET)docker run -it --rm $(REPRO_DOCKER_OPTIONS)   \
                             --volume "$(CURDIR)":"$(REPRO_MNT)"       	\
							 --env-file=${SESSION_ENV_FILE}						\
							 $(REPRO_SETTINGS)							\
                             $(REPRO_MOUNT_OTHER_VOLUMES)               \
                             $(REPRO_IMAGE)
							

# define command for running a command in a running or currently-idle REPRO
ifdef IN_RUNNING_REPRO
RUN_IN_REPRO=$(QUIET)bash -ic
else
RUN_IN_REPRO=$(REPRO_RUN_COMMAND) bash -ilc
endif

## 
## ---------- Targets for starting this REPRO  ---------------------------------
## 

ifndef IN_RUNNING_REPRO
ifeq ($(REPRO_EXIT_AFTER_STARTUP), true)
## start-repro:       Start an interactive session.
start-repro: session
	$(RUN_IN_REPRO) exit
else
start-repro: session 
	$(REPRO_RUN_COMMAND)
endif
else
start-repro:
	$(TARGET_NOT_SUPPORTED_IN_RUNNING_REPRO)
endif

ifndef IN_RUNNING_REPRO
## init-repro:        Initialize REPRO modules.
init-repro: session
	$(shell $(OS_APPEND_ENV) REPRO_SERVICES_STARTUP=manual)
	$(RUN_IN_REPRO) exit
endif

reset-repro: session
	$(shell $(OS_APPEND_ENV) REPRO_DEFER_INIT=true)
	$(RUN_IN_REPRO) repro.reset_repro

REPRO_TESTS_FILE=repro-tests
## test-repro:        Run automated regression tests on this REPRO.
test-repro: repro-logs 
ifndef IN_RUNNING_REPRO
	@$(MAKE) -f Makefile-tests --quiet
else
	$(TARGET_NOT_SUPPORTED_IN_RUNNING_REPRO)
endif

clean-repro:       ## Delete logs in REPRO logs directory.
	$(MAKE) -f Makefile-tests clean-all
	rm -f $(REPRO_LOGGING_DIRNAME)/*.log

## 
## start-services:    Start the services provided by this REPRO.
start-services: session
ifdef IN_RUNNING_REPRO
	$(RUN_IN_REPRO) 'repro.start_services'
else
	$(RUN_IN_REPRO) 'repro.start_services --wait-for-key'
endif


## 
## ---------- Targets for running the examples in this REPRO --------------------
## 
## run-demo:         Run this REPRO's demonsration.
run-demo: session
	$(RUN_IN_REPRO) 'repro.run_target run-demo'

## clean-demo:       Delete artifacts created by the demonstration.
clean-demo: session
	$(RUN_IN_REPRO) 'repro.run_target clean-demo'

## 
## ---------- Targets for performing the analyses in this REPRO -----------------
## 
## run-analyses:      Run the analyses in this REPRO.
run-analyses: session
	$(RUN_IN_REPRO) 'repro.run_target run-analyses'

## clean-analyses:    Delete all artificats created by the analyses.
clean-analyses: session
	$(RUN_IN_REPRO) 'repro.run_target clean-analyses'

## 
## ---------- Targets for creating the reports in this REPRO -------------------
## 
## build-reports:     Generate this REPRO's reports.
build-reports: session
	$(RUN_IN_REPRO) 'repro.run_target build-reports'

## clean-reports:     Delete all generated reports.
clean-reports: session
	$(RUN_IN_REPRO) 'repro.run_target clean-reports'

## 
## ---------- Targets for maintaining the databases in this REPRO --------------
##  
## clean-databases:   Delete the database logs.
clean-databases: session
	$(RUN_IN_REPRO) 'repro.run_target clean-databases'
	
## drop-databases:    Delete the database storage files.
drop-databases: session
	$(RUN_IN_REPRO) 'repro.run_target drop-databases'

## purge-databases:   Delete all artifacts associated with database instances.
purge-databases: session
	$(RUN_IN_REPRO) 'repro.run_target purge-databases'

## 
## ---------- Targets for building and testing custom code in this REPRO -------
## 
## build-code:        Build the custom code in this REPRO.
build-code: session
	$(RUN_IN_REPRO) 'repro.run_target build-code'

## test-code:         Run tests on custom code in this REPRO.
test-code: session
	$(RUN_IN_REPRO) 'repro.run_target test-code'

## install-code:      Install built artifacts in REPRO.
install-code: session
	$(RUN_IN_REPRO) 'repro.run_target install-code'

## package-code:      Package custom artifacts for distribution.
package-code: session
	$(RUN_IN_REPRO) 'repro.run_target package-code'

## clean-code:        Delete artifacts generated by builds of the code.
clean-code: session
	$(RUN_IN_REPRO) 'repro.run_target clean-code'

## purge-code:        Delete all downloaded, cached, and built artifacts.
purge-code: session
	$(RUN_IN_REPRO) 'repro.run_target purge-code'\

## 
##    --- Target aliases defined in repro-config ---
## 

