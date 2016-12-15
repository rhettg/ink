#!/bin/bash
set -e

export PATH=$( pwd ):$( pwd )/tests/:$PATH
repo="test_repo"

. $(dirname $0)/util.sh

destroy_local () {
  enter_repo ${repo}

  name=$(ink_init .)
  ink destroy ${name} &>/dev/null

  if git branch | grep ink-${name}; then
    err "Branch ${name} wasn't cleaned up"
    exit 1
  fi

  exit_repo ${repo}
}

destroy_remote () {
  local remote=$(build_remote)
  build_remote_repo $remote "A"

  name=$(ink_init ./$remote/A)

  ink destroy ${name} &>/dev/null

  if [ -d ${name} ]; then
    err "stack not cleaned up"
    exit 1
  fi

  if [ ! -d ./$remote/A ]; then
    err "Original is gone?"
    exit 1
  fi

  rm -rf ./$remote
  rm -rf ./A
}

setup

destroy_local
destroy_remote

teardown
