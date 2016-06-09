#!/bin/bash
set -e

PATH=$( pwd ):$PATH
repo="test_repo"

. $(dirname $0)/util.sh

local_show () {
  enter_repo ${repo}

  ink init . >/dev/null
  ink init . >/dev/null

  repo_count=$(ink show | wc -l)
  if [ $repo_count -ne 2 ]; then
    err "Failed to find repos (local)"
    exit 1
  fi
  exit_repo ${repo}
}

remote_show () {
  enter_remote
  build_repo "A"
  build_repo "B"

  repo_count=$(ink show | wc -l)
  if [ $repo_count -ne 2 ]; then
    err "Failed to find repos (remote)"
    ink show
    exit 1
  fi

  exit_remote
}

local_show
remote_show
