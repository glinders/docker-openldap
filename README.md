# Open LDAP as a Docker service

Openldap runs as a service, using a data container.

Data can be backed up and restored using the backup and restore containers

## usage

    make build; make run

## backup

All data resides in directories /etc/ldap and /var/lib/ldap
Data is backed up to directory /backup (tar.gz file).
To back up, use command:

    docker start openldap-app-backup

Use `docker cp openldap-app:/backup <dest>` to get backups out of container.

## restore

Archive to restore must be one created above (format: 20180724.openldap.tar.gz).
Use `docker cp <archive> openldap-app:/restore` to get archive into container.
To restore, use command:

    docker start openldap-app-restore

docker-openldap
===============

The image is based on Debian stable ("stretch" at the moment). The Dockerfile is
inspired by [cnry/openldap](https://registry.hub.docker.com/u/cnry/openldap/),
but as said before, running a stable Debian and be a little less verbose, but
more complete in the configuration.

NOTE: On purpose, there is no secured channel (TLS/SSL), because I believe that
this service should never be exposed to the internet, but only be used directly
by other Docker containers using the `--link` option.

Usage
-----

The most simple form would be to start the application like so (however this is
not the recommended way - see below):

    docker run -d -p 389:389 -e SLAPD_PASSWORD=mysecretpassword -e SLAPD_DOMAIN=ldap.example.org dinkel/openldap

To get the full potential this image offers, one should first create a data-only
container or (named) volumes (see "Data persistence" below) and start the 
OpenLDAP daemon in one of these ways:

    docker run -d --volumes-from your-data-container [CONFIG] dinkel/openldap
    docker run -d --volume your-config-volume:/etc/ldap --volume your-data-volume:/var/lib/ldap [CONFIG] dinkel/openldap

An application talking to OpenLDAP should then `--link` the container:

    docker run -d --link openldap:openldap image-using-openldap

The name after the colon in the `--link` section is the hostname where the
OpenLDAP daemon is listening to (the port is the default port `389`).

Configuration (environment variables)
-------------------------------------

For the first run, one has to set at least the first two environment variables.
After the first start of the image (and the initial configuration), these
envirnonment variables are not evaluated again (see the
`SLAPD_FORCE_RECONFIGURE` option).

* `SLAPD_PASSWORD` (required) - sets the password for the `admin` user.
* `SLAPD_DOMAIN` (required) - sets the DC (Domain component) parts. E.g. if one sets
it to `ldap.example.org`, the generated base DC parts would be `...,dc=ldap,dc=example,dc=org`.
* `SLAPD_ORGANIZATION` (defaults to $SLAPD_DOMAIN) - represents the human readable
company name (e.g. `Example Inc.`).
* `SLAPD_CONFIG_PASSWORD` - allows password protected access to the `dn=config`
branch. This helps to reconfigure the server without interruption (read the
[official documentation](http://www.openldap.org/doc/admin24/guide.html#Configuring%20slapd)).
* `SLAPD_ADDITIONAL_SCHEMAS` - loads additional schemas provided in the `slapd`
package that are not installed using the environment variable with comma-separated
enties. As of writing these instructions, there are the following additional schemas
available: `collective`, `corba`, `duaconf`, `dyngroup`, `java`, `misc`, `openldap` and `pmi`.
* `SLAPD_ADDITIONAL_MODULES` - comma-separated list of modules to load. It will try
to run `.ldif` files with a corresponsing name from the `modules` directory.

* `SLAPD_FORCE_RECONFIGURE` - (defaults to false)  Used if one needs to reconfigure
the `slapd` service after the image has been initialized.  Set this value to `true`
to reconfigure the image.

Prepopulate with data
---------------------

There are some use cases where it is desired to prepopulate the database with 
some data before launching the container. In order to do that, one can mount a 
host directory as a data volume in `/etc/ldap.dist/prepopulate`. Each LDIF file 
is run through `slapadd` in alphabetical order. E.g.

    docker run -d --volume /path/to/dir/with/ldif-files:/etc/ldap.dist/prepopulate [CONFIG] dinkel/openldap

Please note that the prepopulation files are only processed on the containers 
first run (a.k.a. as long as there is no data in the database).

Data persistence
----------------

The image exposes two directories (`VOLUME ["/etc/ldap", "/var/lib/ldap"]`).
The first holds the "static" configuration while the second holds the actual
database. Please make sure that these two directories are saved (in a data-only
container or alike) in order to make sure that everything is restored after a
restart of the container.
