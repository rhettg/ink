#!/bin/bash
set -e

PATH=$(dirname $0)/../:$PATH
repo="test_repo"

. $(dirname $0)/util.sh

init_local () {
  enter_repo ${repo}

  name=$(ink init .)
  if [ -z $name ]; then
    err "No name"
    exit 1
  fi

  branch=$(git rev-parse --abbrev-ref HEAD)
  if [[ "${branch}" != "master" ]]; then
    err "Current branch should be master"
    exit 1
  fi

  git checkout -q "${name}"

  if [ ! -f .ink ]; then
    err "Failed to find ink file"
    exit 1
  fi

  exit_repo ${repo}
}

init_remote () {
  enter_remote

  mkdir A
  cd A
  git init -q .
  git commit -q --allow-empty -m "initial commit"
  cd ..

  name=$(ink init ./A)
  if [ -z $name ]; then
    err "No name"
    exit 1
  fi

  if [ ! -d ${name} ]; then
    err "Missing checkout"
    exit 1
  fi

  cd ${name}

  git checkout -q "${name}"

  if [ ! -f .ink ]; then
    err "Failed to find ink file"
    exit 1
  fi

  cd ..

  cd A
  if ! git branch | grep ${name} >/dev/null; then
    err "No branch in remote"
    exit 1
  fi

  git checkout -q ${name}
  if [ ! -f .ink ]; then
    err "Failed to find ink file"
    exit 1
  fi

  exit_remote
}

init_local
init_remote
