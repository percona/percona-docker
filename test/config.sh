#!/bin/bash
set -e

globalTests+=(
	utc
	cve-2014--shellshock
	no-hard-coded-passwords
	override-cmd
)

# for "explicit" images, only run tests that are explicitly specified for that image/variant
explicitTests+=(
	[:onbuild]=1
)
imageTests[:onbuild]+='
	override-cmd
'

testAlias+=(
	[iojs]='node'
	[jruby]='ruby'
	[pypy]='python'

	[ubuntu]='debian'
	[ubuntu-debootstrap]='debian'

	[mariadb]='mysql'
	[percona]='mysql'
	[percona/percona-server]='mysql'
	[perconalab/percona-server]='mysql'
	[percona/percona-xtradb-cluster]='mysql'
	[perconalab/percona-xtradb-cluster]='mysql'

	[percona/percona-server-mongodb]='mongo'
	[perconalab/percona-server-mongodb]='mongo'
	[perconalab/percona-server-mongodb-operator]='mongo'

	[percona/percona-distribution-postgresql]='postgres'
	[perconalab/percona-distribution-postgresql]='postgres'

	[hola-mundo]='hello-world'
	[hello-seattle]='hello-world'
)

imageTests+=(
	[aerospike]='
	'
	[busybox]='
	'
	[cassandra]='
		cassandra-basics
	'
	[celery]='
	'
	[clojure]='
	'
	[crate]='
	'
	[composer]='
		composer
	'
	[convertigo]='
		convertigo-hello-world
	'
	[debian]='
		debian-apt-get
	'
	[docker:dind]='
		docker-dind
		docker-registry-push-pull
	'
	[django]='
	'
	[elasticsearch]='
		elasticsearch-basics
	'
	[elixir]='
		elixir-hello-world
	'
	[erlang]='
		erlang-hello-world
	'
	[fsharp]='
		fsharp-hello-world
	'
	[gcc]='
		gcc-c-hello-world
		gcc-cpp-hello-world
		golang-hello-world
	'
	[ghost]='
		ghost-basics
	'
	[golang]='
		golang-hello-world
	'
	[haskell]='
		haskell-cabal
		haskell-ghci
		haskell-runhaskell
	'
	[haxe]='
		haxe-hello-world
		haxe-haxelib-install
	'
	[hylang]='
		hylang-sh
		hylang-hello-world
	'
	[jetty]='
		jetty-hello-web
	'
	[julia]='
		julia-hello-world
		julia-downloads
	'
	[logstash]='
		logstash-basics
	'
	[memcached]='
		memcached-basics
	'
	[mongo]='
		mongo-basics
		mongo-auth-basics
		mongo-tls-basics
		mongo-tls-auth
	'
	[mono]='
	'
	[mysql]='
		mysql-basics
		mysql-initdb
		mysql-log-bin
		mysql-onetime-password
		mysql-random-password
		mysql-root-host
		mysql-skip-tzinfo
		mysql-want-help
		mysql-datadir
		mysql-check-config
		mysql-file-env
	'
	[node]='
		node-hello-world
	'
	[nuxeo]='
		nuxeo-conf
		nuxeo-basics
	'
	[openjdk]='
		java-hello-world
		java-uimanager-font
	'
	[open-liberty]='
		open-liberty-hello-world
	'
	[percona]='
		percona-tokudb
		percona-rocksdb
	'
	[percona/percona-server]='
		percona-rocksdb
	'
	[perconalab/percona-server]='
		percona-tokudb
		percona-rocksdb
	'
	[perl]='
		perl-hello-world
	'
	[php]='
		php-ext-install
		php-hello-world
		php-argon2
	'
	[php:apache]='
		php-apache-hello-web
	'
	[php:fpm]='
		php-fpm-hello-web
	'
	[plone]='
		plone-basics
		plone-addons
		plone-zeoclient
	'
	[postgres]='
		postgres-basics
		postgres-initdb
	'
	[python]='
		python-hy
		python-imports
		python-pip-requests-ssl
		python-sqlite3
		python-stack-size
	'
	[rabbitmq]='
		rabbitmq-basics
	'
	[r-base]='
	'
	[rails]='
	'
	[rapidoid]='
		rapidoid-hello-world
		rapidoid-load-balancer
	'
	[redis]='
		redis-basics
		redis-basics-config
		redis-basics-persistent
	'
	[redmine]='
		redmine-basics
	'
	[registry]='
		docker-registry-push-pull
	'
	[rethinkdb]='
	'
	[ruby]='
		ruby-hello-world
		ruby-standard-libs
		ruby-gems
		ruby-bundler
		ruby-nonroot
	'
	[rust]='
		rust-hello-world
	'
	[silverpeas]='
		silverpeas-basics
	'
	[swipl]='
		swipl-modules
	'
	[swift]='
		swift-hello-world
	'
	[tomcat]='
		tomcat-hello-world
	'
	[wordpress:apache]='
		wordpress-apache-run
	'
	[wordpress:fpm]='
		wordpress-fpm-run
	'
	[znc]='
		znc-basics
	'
	[zookeeper]='
		zookeeper-basics
	'
# example onbuild
#	[python:onbuild]='
#		py-onbuild
#	'
)

globalExcludeTests+=(
	# single-binary images
	[hello-world_utc]=1
	[nats_utc]=1
	[nats-streaming_utc]=1
	[swarm_utc]=1
	[traefik_utc]=1

	[hello-world_no-hard-coded-passwords]=1
	[nats_no-hard-coded-passwords]=1
	[nats-streaming_no-hard-coded-passwords]=1
	[swarm_no-hard-coded-passwords]=1
	[traefik_no-hard-coded-passwords]=1

	# clearlinux has no /etc/password
	# https://github.com/docker-library/official-images/pull/1721#issuecomment-234128477
	[clearlinux_no-hard-coded-passwords]=1

	# alpine/slim openjdk images are headless and so can't do font stuff
	[openjdk:alpine_java-uimanager-font]=1
	[openjdk:slim_java-uimanager-font]=1

	# no "native" dependencies
	[ruby:alpine_ruby-bundler]=1
	[ruby:alpine_ruby-gems]=1
	[ruby:slim_ruby-bundler]=1
	[ruby:slim_ruby-gems]=1
)
