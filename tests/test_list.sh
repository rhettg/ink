#!/bin/bash
set -e

export PATH=$( pwd ):$( pwd )/tests/:$PATH
repo="test_repo"

. $(dirname $0)/util.sh

local_list () {
  enter_repo ${repo}

  ink add . ink_id=foo >/dev/null
  ink add . ink_id=bar >/dev/null

  repo_count=$(ink list | wc -l)
  if [ $repo_count -ne 2 ]; then
    err "Failed to find repos (local)"
    exit 1
  fi
  exit_repo ${repo}
}

remote_list () {
  local remote=$(build_remote)
  build_remote_repo $remote "A"
  build_remote_repo $remote "B"

  name=$(ink_add ./$remote/A)
  name=$(ink_add ./$remote/B)

  repo_count=$(ink list | wc -l)
  if [ $repo_count -ne 2 ]; then
    err "Failed to find repos (remote)"
    ink show
    exit 1
  fi

  rm -rf ./$remote
  rm -rf ./A ./B
}

setup

local_list
remote_list

teardown
