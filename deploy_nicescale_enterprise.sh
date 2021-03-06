#!/bin/bash

set -e

ARCH=$(uname -m)
[ "$ARCH" != "x86_64" ] && echo "Only support 64bit Linux" && exit 1

function distrib_id() {
  if [ -x /usr/bin/lsb_release ]; then
    lsb_release --id --short
  elif [ -f /etc/debian_version ]; then
    echo Debian
  elif [ -f /etc/fedora-release ]; then
    echo Fedora
  elif [ -f /etc/arch-release ]; then
    echo Archlinux
  elif [ -f /etc/gentoo-release ]; then
    echo Gentoo
  elif [ -f /etc/redhat-release ]; then
    release=`cat /etc/redhat-release`
    if echo $release|grep -q '^Red Hat Enterprise Linux'; then
      echo RHEL
    elif echo $release|grep -q '^CentOS'; then
      echo CentOS
    elif echo $release|grep -q '^Scientific Linux'; then
      echo SLES
    else
      echo Unknown
    fi
  else
    echo Unknown
  fi
}

function get_release() {
  [ -x /usr/bin/lsb_release ] && VERSION=$(lsb_release -r -s)
  [ -z "$VERSION" ] && VERSION=$(awk '/DISTRIB_RELEASE=/' /etc/*-release | sed 's/DISTRIB_RELEASE=//')
  [ -z "$VERSION" ] && VERSION=$(awk '/VERSION_ID=/' /etc/*-release | sed 's/VERSION_ID=//')
  [ -z "$VERSION" ] && VERSION=$(cat /etc/*-release|rev|cut -f1 -d ' '|rev|grep -P '^\d')
  if echo $VERSION|grep -q -P '"\d+.*"'; then
    echo $VERSION|tr -d '"'
  else
    echo $VERSION
  fi
}

function die() {
  echo $*
  exit 1
}

function docker_installed() {
  if docker -v > /dev/null 2>&1; then
    return 0
  else
    return 1
  fi
}

function docker_running() {
  if docker ps > /dev/null 2>&1; then
    return 0
  else
    return 1
  fi
}

function run_docker() {
  DIST=`distrib_id`
  RELEASE=`get_release`

  case $DIST in
    Ubuntu)
      service docker start
      ;;
    CentOS)
      if echo $RELEASE|grep ^6; then
        service docker start
      else
        systemctl start docker.service
      fi
      ;;
    *)
      echo "not support"
  esac
}

function install_docker() {
  DIST=`distrib_id`
  RELEASE=`get_release`

  case $DIST in
    Ubuntu)
      [ $RELEASE != "14.04" ] && die "Only support Ubuntu 14.04"
      apt-get update
      apt-get -y install lxc-docker
      ps ax|grep docke[r] || service docker start
      ;;
    CentOS)
      if echo $RELEASE|grep ^6; then
        [ -f /etc/yum.repos.d/epel.repo ] ||
        rpm -i http://mirrors.hustunique.com/epel/6/x86_64/epel-release-6-8.noarch.rpm
        yum -y install docker-io
        service docker start
      elif echo $RELEASE|grep ^7; then
        yum -y install docker
        systemctl start docker.service
      else
        die "CentOS $RELEASE not support yet."
      fi
      ;;
    *)
      die "OS($DIST) not supported yet"
  esac
}

echo "> check docker installed? if no, then install docker"
docker_installed || install_docker
docker_running || run_docker

echo "> pull docker image now"
docker import http://t.cn/R7j9dMp nicescale/nsent

echo "> run nicescale enterprise"
mkdir /nicescale
docker run -d -v /nicescale:/data -p 80:80 nicescale/nsent /bin/phenix-init

echo "> congratulations! you can now open nicescale enterprise in your browser."
