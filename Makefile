# include some Docker specific make functions
include ../docker-makeinc/docker.mk

# name and version for image and container
SERVICE_NAME = openldap-app
DATA_NAME = $(SERVICE_NAME)-data
BACKUP_NAME = $(SERVICE_NAME)-backup
RESTORE_NAME = $(SERVICE_NAME)-restore
VERSION = 1.0
SERVICE_IMAGE = $(SERVICE_NAME):$(VERSION)
DATA_IMAGE = $(DATA_NAME):$(VERSION)
BACKUP_IMAGE = $(BACKUP_NAME):$(VERSION)
RESTORE_IMAGE = $(RESTORE_NAME):$(VERSION)

# port numbers and IP addresses
#
# port number used by application in container
APP_PORT_CONTAINER = 389
# port number to map to on host machine
APP_PORT_HOST = 389
# address of local host. Don't use 0.0.0.0 or leave blank
# the 127 address limits container access to the local machine only
# todo test LOCALHOST = 127.0.0.1
LOCALHOST = 127.0.0.1

# container names
#
# name of data volume container
DATAVOLUME = $(DATA_NAME)

# environment variables to pass
ENVVARS = 
# links to other containers
LINKS =
# volumes exposed by the data container
VOLUMES = -v /etc/ldap -v /var/lib/ldap -v /backup -v /restore
# data container volumes are used by the application container
VOLUMES_FROM = --volumes-from $(DATAVOLUME)
# port assignments
PORTS = -p $(LOCALHOST):$(APP_PORT_HOST):$(APP_PORT_CONTAINER)
# additional run options
RUN_OPTIONS = --restart=no
#
.PHONY: build build_app build_data run run-app create-data create-backup create-restore start stop rm rmi mv-app mv-data mv-backup mv-restore


# build images
#
build: build_restore

build_app:
	# force build new application image
	# the old image will lose its tag, but will still be there
	# the application container will not be affected
	docker build -t $(SERVICE_IMAGE) -f Dockerfile-app .

build_data: build_app
	# force build new data image
	# the old image will lose its tag, but will still be there
	# the data container will not be affected
	docker build --build-arg SERVICE_IMAGE=$(SERVICE_IMAGE) -t $(DATA_IMAGE) -f Dockerfile-data .

build_backup: build_data
	# force build new backup image
	# the old image will lose its tag, but will still be there
	# the data container will not be affected
	docker build --build-arg SERVICE_IMAGE=$(SERVICE_IMAGE) -t $(BACKUP_IMAGE) -f Dockerfile-backup .

build_restore: build_backup
	# force build new restore image
	# the old image will lose its tag, but will still be there
	# the data container will not be affected
	docker build --build-arg SERVICE_IMAGE=$(SERVICE_IMAGE) -t $(RESTORE_IMAGE) -f Dockerfile-restore .

# create and run containers
#
run: run-app

run-app: create-data create-backup create-restore mv-app
	# create and run the container
	docker run $(RUN_OPTIONS) $(ENVVARS) $(LINKS) $(VOLUMES_FROM) $(PORTS) --name $(SERVICE_NAME) -d $(SERVICE_IMAGE)

create-data: mv-data
	# create the data container
	docker create $(VOLUMES) --name $(DATA_NAME) $(DATA_IMAGE) /bin/true

create-backup: create-data mv-backup
	# create the backup container
	docker create $(RUN_OPTIONS) $(VOLUMES_FROM) --name $(BACKUP_NAME) $(BACKUP_IMAGE)

create-restore: create-data mv-restore
	# create the restore container
	docker create $(RUN_OPTIONS) $(VOLUMES_FROM) --name $(RESTORE_NAME) $(RESTORE_IMAGE)

# starting and stopping application container
#
start:
	docker start $(SERVICE_NAME)

stop:
	# stop container if it is running
	if [ "$(call docker-does-container-run,$(SERVICE_NAME))" = "yes" ] ; \
		then docker stop $(SERVICE_NAME); fi

# remove application container
#
rm: stop
	# remove old container if one exists
	if [ "$(call docker-does-container-exist,$(SERVICE_NAME))" = "yes" ] ; \
		then docker rm $(SERVICE_NAME); fi

# remove application image
#
rmi: rm
	# remove old image if one exists
	if [ "$(call docker-does-image-version-exist,$(SERVICE_IMAGE),"")" = "yes" ] ; \
		then docker rmi $(SERVICE_IMAGE); fi

mv-app: stop
	# rename old application container(s)
	if docker inspect $(SERVICE_NAME) >/dev/null 2>&1; then \
		$(eval CONTAINERS = $(shell docker container ls --all --format "{{.Names}}" --filter name=^/${SERVICE_NAME}$$ --filter name=^/${SERVICE_NAME}.old$$|sort -r)) \
		echo application containers found $(CONTAINERS) ; \
		$(foreach C,$(CONTAINERS),$(shell bash -c "echo rename $(C); docker rm $(C).old; docker container rename $(C) $(C).old; echo done;")) ; \
	fi

mv-data: stop
	# rename old data container(s)
	if docker inspect $(DATA_NAME) >/dev/null 2>&1; then \
		$(eval CONTAINERS = $(shell docker container ls --all --format "{{.Names}}" --filter name=^/${DATA_NAME}$$ --filter name=^/${DATA_NAME}.old$$|sort -r)) \
		echo data containers found $(CONTAINERS) ; \
		$(foreach C,$(CONTAINERS),$(shell bash -c "echo rename $(C); docker rm $(C).old; docker container rename $(C) $(C).old; echo done;")) ; \
	fi

mv-backup: stop
	# rename old backup container(s)
	if docker inspect $(BACKUP_NAME) >/dev/null 2>&1; then \
		$(eval CONTAINERS = $(shell docker container ls --all --format "{{.Names}}" --filter name=^/${BACKUP_NAME}$$ --filter name=^/${BACKUP_NAME}.old$$|sort -r)) \
		echo backup containers found $(CONTAINERS) ; \
		$(foreach C,$(CONTAINERS),$(shell bash -c "echo rename $(C); docker rm $(C).old; docker container rename $(C) $(C).old; echo done;")) ; \
	fi

mv-restore: stop
	# rename old restore container(s)
	if docker inspect $(RESTORE_NAME) >/dev/null 2>&1; then \
		$(eval CONTAINERS = $(shell docker container ls --all --format "{{.Names}}" --filter name=^/${RESTORE_NAME}$$ --filter name=^/${RESTORE_NAME}.old$$|sort -r)) \
		echo restore containers found $(CONTAINERS) ; \
		$(foreach C,$(CONTAINERS),$(shell bash -c "echo rename $(C); docker rm $(C).old; docker container rename $(C) $(C).old; echo done;")) ; \
	fi


