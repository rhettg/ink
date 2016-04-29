#!/bin/bash

set -eu
set -o pipefail

help () {
  echo "Usage: $0 <init|create|update|show|destroy|help>"
}

build_name () {
  id=$(head /dev/urandom | md5sum | cut -c1-5)
  echo "$1-$id"
}

branch_name () {
  echo "ink-$1"
}

extract_repo_name () {
  regex="([^\/]+)\.git$"

  if [[ "$1" =~ $regex ]]; then
    echo "${BASH_REMATCH[1]}"
  fi
}

# Initialize the specified git repository for use with a new ink stack
# This will mean cutting a new branch and putting all the right stuff in it.
init () {
  remote=$1
  if [ "${remote}" == "." ]; then
    repo=$(basename `pwd`)
    local=1
  else
    repo=$(extract_repo_name "${remote}")
    if [ -z $repo ]; then
      err "Failed to extract name from ${remote}"
    fi

    local=0
  fi

  name=$(build_name "${repo}")

  if [ $local -ne 1 ]; then
    # We actually keep a separate repo for each stack.
    # We could combine stacks for the saem repo, but we'd have to sort out
    # concurrency issues. Doable. But skipping for now.
    git clone -q ${remote} ${name}
    pushd ${name} &> /dev/null
  else
    start_branch=$(git rev-parse --abbrev-ref HEAD)
  fi

  if ! _=$(git status); then
    err "Not a git repository"
    exit 1
  fi

  if ! git checkout -q -b ${name}; then
    err "Failed to create branch ${name}"
    exit 1
  fi

  if [ -f .ink ]; then
    err "Ink state file already exists"
    exit 1
  fi

  touch .ink
  git add .ink
  git commit -q -m "ink init"

  if [ -x script/ink-init ]; then
    if [ ! script/ink-init ]; then
      ret=$?
      err "Failed executing ink-init"
      exit $ret
    fi
  fi

  if [ $local -ne 1 ]; then
    git push -q -u origin "${name}" &> /dev/null
    popd &> /dev/null
  else
    git checkout -q "${start_branch}"
  fi

  echo "${name}"
}

create () {
  echo
}

err () {
  >&2 echo $1
}

if [ $# -eq 0 ] || [ "$1" == "help" ]; then
  help
elif [ "$1" == "init" ]; then
  if [ -z $2 ]; then
    err "init where?"
    help
  else
    init $2
  fi
elif [ "$1" == "create" ]; then
  repo=${2-"."}
  create $repo
elif [ "$1" == "update" ]; then
    echo
elif [ "$1" == "destroy" ]; then
    echo
else
    >&2 echo "Unknown command"
    help
fi
