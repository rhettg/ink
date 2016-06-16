#!/bin/bash
set -e

export PATH=$( pwd ):$( pwd )/tests/:$PATH
repo="test_repo"

. $(dirname $0)/util.sh

destroy_local () {
  enter_repo ${repo}

  name=$(ink init .)
  ink destroy ${name}

  if git branch | grep ink-${name}; then
    err "Branch ${name} wasn't cleaned up"
    exit 1
  fi

  exit_repo ${repo}
}

destroy_remote () {
  enter_remote

  build_repo "A"
  name=$(ink init ./A)

  ink destroy ${name}

  if [ -d ${name} ]; then
    err "stack not cleaned up"
    exit 1
  fi

  if [ ! -d A ]; then
    err "Original is gone?"
    exit 1
  fi

  exit_remote
}

destroy_local
destroy_remote
