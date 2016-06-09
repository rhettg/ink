#!/bin/bash
set -e

PATH=$( pwd ):$PATH
repo="test_repo"

. $(dirname $0)/util.sh

init_local () {
  enter_repo ${repo}

  name=$(ink init .)
  if [ -z "$name" ]; then
    err "No name"
    exit 1
  fi

  branch=$(git rev-parse --abbrev-ref HEAD)
  if [[ "${branch}" != "master" ]]; then
    err "Current branch should be master"
    exit 1
  fi

  git checkout -q "ink-${name}"

  if [ ! -f .ink ]; then
    err "Failed to find ink file"
    exit 1
  fi

  exit_repo ${repo}
}

init_remote () {
  enter_remote

  build_repo "A"

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

  git checkout -q "ink-${name}"

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

  git checkout -q ink-${name}
  if [ ! -f .ink ]; then
    err "Failed to find ink file"
    exit 1
  fi
  cd ..

  exit_remote
}

init_with_args () {
  enter_repo ${repo}

  name=$(ink init . FOO=fizz BAR=buzz)
  if [ -z "$name" ]; then
    err "No name"
    exit 1
  fi

  git checkout -q "ink-${name}"

  if [ ! -f .ink-env ]; then
    err "Failed to find ink file"
    exit 1
  fi

  if ! grep -q "INK_NAME=" .ink-env; then
    err "Failed to find INK_NAME"
    exit 1
  fi

  if ! grep -q "FOO=fizz" .ink-env; then
    err "Failed to find FOO"
    exit 1
  fi

  if ! grep -q BAR=buzz .ink-env; then
    err "Failed to find FOO"
    exit 1
  fi

  exit_repo ${repo}
}

init_with_id () {
  enter_repo ${repo}

  name=$(ink init . ID=fizz)
  if [ -z "$name" ]; then
    err "No name"
    exit 1
  fi

  if [ ! "$name" = "test_repo-fizz" ]; then
    err "Incorrect name ${name}"
    exit 1
  fi

  exit_repo ${repo}
}

init_with_name () {
  enter_repo ${repo}

  name=$(ink init . INK_NAME=fizz)
  if [ -z "$name" ]; then
    err "No name"
    exit 1
  fi

  if [ ! "$name" = "fizz" ]; then
    err "Incorrect name ${name}"
    exit 1
  fi

  exit_repo ${repo}
}

init_local
init_remote
init_with_args
init_with_name
init_with_id
