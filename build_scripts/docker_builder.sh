#!/bin/sh

shell_quote_string() {
  echo "$1" | sed -e 's,\([^a-zA-Z0-9/_.=-]\),\\\1,g'
}

usage () {
    cat <<EOF
Usage: $0 [OPTIONS]
    The following options may be given :
        --builddir=DIR      Absolute path to the dir where all actions will be performed
        --install_docker    All needed staff will be installed(works only on jessie)
        --clean_dockers     All images and containers will be deleted
        --docker_name       Should be the name of the directory in the percona-docker repo
        --build_docker      Build Docker
        --version           Product version that should be used for docker(don't needed for proxysql)
        --save_docker       Save docker as tar.gz archive
        --load_docker=PATH  Load docker from image archive. using path from paramiter
        --test_docker       Run basic tests to verify docker image
        --repo=github_repo  Default value is https://github.com/percona/percona-docker.git
        --branch=BRANCH     Default branch is main
        --help) usage ;;
Example $0 --builddir=/tmp/docker_build --build_docker=1 --save_docker=1 --docker-name=percona-server-mongodb.36 --version=3.6.1-1.0
EOF
        exit 1
}

append_arg_to_args () {
  args="$args "$(shell_quote_string "$1")
}

parse_arguments() {
    pick_args=
    if test "$1" = PICK-ARGS-FROM-ARGV
    then
        pick_args=1
        shift
    fi
  
    for arg do
        val=$(echo "$arg" | sed -e 's;^--[^=]*=;;')
        case "$arg" in
            --install_docker=*) INSTALL="$val" ;;
            --clean_docker=*) CLEAN="$val" ;;
            --docker_name=*) DOCKER_NAME="$val" ;;
            --build_docker=*) BUILD="$val" ;;
            --version=*) VERSION="$val" ;;
            --save_docker=*) SAVE="$val" ;;
            --load_docker=*) LOAD="$val" ;;
            --branch=*) BRANCH="$val" ;;
            --test_docker=*) TEST="$val" ;;
            --repo=*) REPO="$val" ;;
            --builddir=*) WORKDIR="$val" ;;
            --auto=*) AUTO="$val" ;;
            --help) usage ;;      
            *)
              if test -n "$pick_args"
              then
                  append_arg_to_args "$arg"
              fi
              ;;
        esac
    done
}


#main
red=$(tput setaf 1)
green=$(tput setaf 2)
reset=$(tput sgr0)
args=
WORKDIR=
INSTALL=0
CLEAN=0
DOCKER_NAME=
BUILD=0
VERSION=0
SAVE=0
LOAD=0
BRANCH=main
TEST=0
OS=
REPO="https://github.com/percona/percona-docker.git"
AUTO=0
TIMESTAMP=$(date -u '+%Y%m%d%H%M')
parse_arguments PICK-ARGS-FROM-ARGV "$@"

get_system(){
    if [ -f /etc/redhat-release ]; then
        OS="rpm"
    else
        OS="deb"
    fi
    return
}

check_root() {
  if [ ! "$( id -u )" -eq 0 ]
  then
    echo "It is not possible to proceed. Please run as root"
    exit 1
  fi
}

install_docker() {
  check_root
  if [ $INSTALL = 0 ]
  then
    echo "Docker will not be installed"
    return
  fi
  if [ "x$OS" = "xrpm" ]
  then
    echo "We can install Docker only on Debian Jessie."
    echo "Please install Docker manually and re-run script"
    exit 1
  elif [ "x$OS" = "xdeb" ]
  then
    DEBIAN_VERSION="$(lsb_release -sc)"
    if [ "x$DEBIAN_VERSION" != "xjessie" ]
    then
      echo "We can install Docker only on Debian Jessie."
      echo "Please install Docker manually and re-run script"
      exit 1
    fi
  else
    echo "Unsupported OS"
    exit 1
  fi


  apt-get update
  apt-get install apt-transport-https ca-certificates -y

  sh -c "echo deb https://apt.dockerproject.org/repo debian-jessie main > /etc/apt/sources.list.d/docker.list"
  apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 58118E89F3A912897C070ADBF76221572C52609D

  apt-get update
  apt-get install docker-engine coreutils git -y

  service docker start

  groupadd docker || true
  gpasswd -a "$USER" docker
  service docker restart
}

clean_dockers() {
  if [ $CLEAN = 0 ]
  then
    echo "Docker images/containers will not be removed"
    return
  fi
  if [ $AUTO = 1 ]; then
    docker rm -f "$(docker ps -aq)" || true
    docker rmi -f "$(docker images -q)" || true
    return
  fi
  echo "${red}Please note that ALL docker images and ALL docker containers will be REMOVED${reset}"
  read -p "Continue (y/n)?" choice
  case "$choice" in 
    y|Y )
      docker rm -f "$(docker ps -aq)" || true
      docker rmi -f "$(docker images -q)" || true
      ;;
    n|N ) return;;
    * ) echo "${green}Dockers will not be deleted${reset}";;
  esac
}

build_docker() {
  if [ $BUILD = 0 ]
  then
    echo "Docker will not be built"
    return
  fi
  cd ${WORKDIR}
  git clone ${REPO}
  cd percona-docker
  git fetch origin
  if [ ! -z ${BRANCH} ]; then
    git reset --hard
    git clean -xdf
    git checkout ${BRANCH}
  fi
  cd ${DOCKER_NAME}
    if [ ! -z ${VERSION} ]; then
      if [ ${VERSION} != proxysql ]; then
        sed -i "s/ENV PERCONA_VERSION .*$/ENV PERCONA_VERSION ${VERSION}.jessie/" Dockerfile
      fi
    fi
    docker build -t ${DOCKER_NAME} .
    if [ ${SAVE} = 1 ]; then
      docker save ${DOCKER_NAME} | gzip > ${WORKSPACE}/${DOCKER_NAME}.${TIMESTAMP}.tar.gz
    fi
  cd ${WORKDIR}    
}

save_docker() {
  if [ ${SAVE} = 0 ]
  then
    echo "Docker image will not be saved as archive"
    return
  fi
  rm -rf ${WORKDIR}/*.tar.gz
  docker save ${DOCKER_NAME} | gzip > ${WORKDIR}/${DOCKER_NAME}.${TIMESTAMP}.tar.gz
  cp ${WORKDIR}/${DOCKER_NAME}.${TIMESTAMP}.tar.gz ./
}

load_docker() {
  if [ -f ${LOAD} ]
  then
    zcat $LOAD | docker load
  else
    echo "${red}Please specify path to archive correctly${reset}"
  fi
}

test_docker() {
  if [ ${TEST} = 0 ]
  then
    echo "Basic tests will not be started"
    return
  fi
  clean_dockers
  EXISTS=$(docker images | grep ${DOCKER_NAME} | grep -c latest)
  if [ "${EXISTS}" = 0 ]; then
    load_docker
  fi
  case $DOCKER_NAME in
    percona-server|percona-server.56)
      docker run --name container-name_${DOCKER_NAME} -e MYSQL_ROOT_PASSWORD=secret -d ${DOCKER_NAME}
    ;;
    percona-server-mongodb|percona-server-mongodb.32|percona-server-mongodb.34|percona-server-mongodb.36)
      docker run --name container-name_${DOCKER_NAME} -d ${DOCKER_NAME}
    ;;
    pxc-56|pxc-57|proxysql)
      echo "${red} Not implemented"
      return
    ;;
  esac
  check_running
  sleep 120
  check_running

}

check_running() {
  RUNNING=$(docker ps --filter status=running | grep -c container-name_${DOCKER_NAME})
  if [ "${RUNNING}" = 0 ]; then
    CONTAINER=$(docker ps | grep container-name_${DOCKER_NAME} | awk '{print $1}')
    echo "${red} Docker ${DOCKER_NAME} is not running!${reset}"
    docker logs "${CONTAINER}"
    exit 1
  else
    echo "${green} Docker ${DOCKER_NAME} is running correctly!${reset}"
  fi
}


case $DOCKER_NAME in
    percona-server|percona-server.56|percona-server-mongodb|percona-server-mongodb.32|percona-server-mongodb.34|percona-server-mongodb.36|proxysql|pxc-56|pxc-57)
      echo "${green}Docker name is correct${reset}"
      ;;
    *)
      echo "${red}Docker name is not correct!${reset}"
      exit 1
      ;;
esac

get_system
install_docker
clean_dockers
build_docker
save_docker
load_docker
test_docker
