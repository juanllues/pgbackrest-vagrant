#!/bin/bash

PGBR="172.28.33.15"
POSTGRESQL_VERSION=9.6

function setup_ssh_keys() {
    cp -rp /vagrant/.ssh/* /root/.ssh
    cp -rp /root/.ssh/id_rsa.pub /root/.ssh/authorized_keys
    chmod 700 /root/.ssh
    chmod 600 /root/.ssh/id_rsa
    chmod 644 /root/.ssh/id_rsa.pub
    chmod 644 /root/.ssh/authorized_keys
    chown -R root /root/.ssh
    chgrp -R root /root/.ssh
}

function setup_pgbackrest() {
	apt-get -y install pgbackrest
	cat > /etc/pgbackrest.conf <<EOF
[main-pg01]
pg1-path=/var/lib/postgresql/9.6/main
pg1-host=pg01
pg1-host-user=postgres

[main-pg02]
pg1-path=/var/lib/postgresql/9.6/main
pg1-host=pg02
pg1-host-user=postgres

[main-pg03]
pg1-path=/var/lib/postgresql/9.6/main
pg1-host=pg03
pg1-host-user=postgres

[main-pg04]
pg1-path=/var/lib/postgresql/9.6/main
pg1-host=pg04
pg1-host-user=postgres

[global]
repo1-cipher-pass="fRL61XCRanCxLWs02W0KjHrPPc+TY94R6UyXQX0r8+28kDILd9TaYYNoxjZ1QCeH"
repo1-cipher-type=aes-256-cbc
repo1-path=/var/lib/pgbackrest
repo1-retention-full=2
repo1-retention-diff=2
start-fast=y

[global:archive-push]
compress-level=3

[recovery]
db-path=/var/lib/postgresql/9.6/main
EOF
}

function setup_fresh_postgresql() {
    su -s /bin/bash -c "/usr/lib/postgresql/${POSTGRESQL_VERSION}/bin/initdb -D /var/lib/postgresql/${POSTGRESQL_VERSION}/main -E utf-8" postgres

    # start postgresql to set things up before copying
    systemctl start postgresql
    systemctl stop postgresql
}

function setup_postgresql_repo() {
    # Setup postgresql repo
    echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list

    # Setup postgresql repo key
    apt-get -y install wget ca-certificates ntp
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -

    # Update package info
    apt-get update
}

function setup_postgresql() {
    # Install postgresql
    apt-get -y install postgresql-${POSTGRESQL_VERSION}

    systemctl stop postgresql

    cat > /etc/postgresql/${POSTGRESQL_VERSION}/main/pg_hba.conf <<EOF
local   all             postgres                                peer

# TYPE  DATABASE        USER            ADDRESS                 METHOD

# "local" is for Unix domain socket connections only
local   all             all                                     peer
# IPv4 local connections:
host    all             all             127.0.0.1/32            md5
# IPv6 local connections:
host    all             all             ::1/128                 md5
# Allow replication connections from localhost, by a user with the
# replication privilege.
#local   replication     postgres                                peer
#host    replication     postgres        127.0.0.1/32            md5
host    replication     postgres        ::1/128                 md5
hostssl    replication     postgres 172.28.33.11/32                 trust
hostssl    replication     postgres 172.28.33.12/32                 trust
hostssl    replication     postgres 172.28.33.13/32                 trust
hostssl    replication     postgres 172.28.33.14/32                 trust
# for user connections
host       all     postgres 172.28.33.1/32                 trust
hostssl    all     postgres 172.28.33.1/32                 trust
# for pgbouncer
host       all     postgres 172.28.33.10/32                 trust
hostssl    all     postgres 172.28.33.10/32                 trust
host       all     postgres 172.28.33.11/32                 trust
hostssl    all     postgres 172.28.33.11/32                 trust
host       all     postgres 172.28.33.12/32                 trust
hostssl    all     postgres 172.28.33.12/32                 trust
host       all     postgres 172.28.33.13/32                 trust
hostssl    all     postgres 172.28.33.13/32                 trust
host       all     postgres 172.28.33.14/32                 trust
hostssl    all     postgres 172.28.33.14/32                 trust
host       all     postgres 172.28.33.15/32                 trust
hostssl    all     postgres 172.28.33.15/32                 trust
EOF

    cat > /etc/postgresql/${POSTGRESQL_VERSION}/main/postgresql.conf <<EOF
archive_command = 'pgbackrest --stanza=main archive-push %p'
archive_mode = 'on'
autovacuum = 'on'
checkpoint_completion_target = 0.6
#checkpoint_segments = 10
checkpoint_warning = 300
data_directory = '/var/lib/postgresql/${POSTGRESQL_VERSION}/main'
datestyle = 'iso, mdy'
default_text_search_config = 'pg_catalog.english'
effective_cache_size = '128MB'
external_pid_file = '/var/run/postgresql/${POSTGRESQL_VERSION}-main.pid'
hba_file = '/etc/postgresql/${POSTGRESQL_VERSION}/main/pg_hba.conf'
hot_standby = 'on'
ident_file = '/etc/postgresql/${POSTGRESQL_VERSION}/main/pg_ident.conf'
include_if_exists = 'repmgr_lib.conf'
lc_messages = 'C'
listen_addresses = '*'
log_autovacuum_min_duration = 0
log_checkpoints = 'on'
logging_collector = 'on'
log_min_messages = DEBUG3
log_filename = 'postgresql.log'
log_connections = 'on'
log_directory = '/var/log/postgresql'
log_disconnections = 'on'
log_line_prefix = ''
log_lock_waits = 'on'
log_min_duration_statement = 0
log_temp_files = 0
maintenance_work_mem = '128MB'
max_connections = 100
max_wal_senders = 3
port = 5432
shared_buffers = '128MB'
shared_preload_libraries = 'pg_stat_statements'
ssl = on
ssl_cert_file = '/etc/ssl/certs/ssl-cert-snakeoil.pem'
ssl_key_file = '/etc/ssl/private/ssl-cert-snakeoil.key'
# unix_socket_directories = '/var/run/postgresql'
wal_buffers = '8MB'
wal_keep_segments = '200'
wal_level = 'replica'
work_mem = '128MB'
EOF
}

function setup_hosts() {
	cat > /etc/hosts <<EOF
127.0.0.1       localhost

# The following lines are desirable for IPv6 capable hosts
::1     ip6-localhost   ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
ff02::3 ip6-allhosts
127.0.1.1       pgbr    pgbr
172.28.33.11    pg01    pg01
172.28.33.12    pg02    pg02
172.28.33.13    pg03    pg03
172.28.33.14    pg04    pg04
EOF
}

if [ ! -f /root/.ssh/id_rsa ]; then
    setup_ssh_keys
fi

if [ ! -f /etc/apt/sources.list.d/pgdg.list ]; then
    setup_postgresql_repo
fi

if [ ! -f /etc/postgresql/${POSTGRESQL_VERSION}/main/postgresql.conf ]; then
    setup_postgresql
	setup_fresh_postgresql
	setup_hosts
fi

if [ ! -f /etc/pgbackrest.conf ]; then
    setup_pgbackrest
fi
