#!/bin/bash

set -eu
set -o pipefail

# Fun Globals to keep track of
name=""

# These keep track of if we're running in local repo mode, meaning we're being
# executed from within a repo and won't be managing the remotes or cloning
# ourselves.
start_branch=""
local_repo=0

help () {
  echo "Usage: $0 <init|create|update|show|destroy|help>"
}

build_name () {
  local id=$(head /dev/urandom | md5sum | cut -c1-5)
  echo "$1-$id"
}

branch_name () {
  echo "ink-$1"
}

extract_repo_name () {
  local regex="([^\/]+)\.git$"

  if [[ "$1" =~ $regex ]]; then
    echo "${BASH_REMATCH[1]}"
  fi
}

# Handle entering and exiting our repo/branch environment
# In local mode, we need to much with the current repo, and we want to restore
# it to how we found it.
# In remote mode, we'll be cd'ing into a specific repo, and we should come back
# out when we're done.
enter_repo () {
  if [ $local_repo -eq 1 ]; then
    start_branch=$(git rev-parse --abbrev-ref HEAD)
  else
    pushd ${name} &> /dev/null
  fi
}

exit_repo () {
  if [ -n "${start_branch}" ]; then
    git checkout -q "${start_branch}"
  else
    popd &> /dev/null
  fi
}

run_script () {
  local script_name=$1

  if [ -x script/${script_name} ]; then
    if [ ! script/${script_name} ]; then
      ret=$?
      err "Failed executing ${script_name}"
      exit $ret
    fi
  fi
}

# Initialize the specified git repository for use with a new ink stack
# This will mean cutting a new branch and putting all the right stuff in it.
init () {
  # heh
  local remote=$1

  if [ "${remote}" == "." ]; then
    repo=$(basename `pwd`)
    local_repo=1
  else
    repo=$(extract_repo_name "${remote}")
    if [ -z $repo ]; then
      err "Failed to extract name from ${remote}"
    fi
  fi

  name=$(build_name "${repo}")

  if [ $local_repo -ne 1 ]; then
    # We actually keep a separate repo for each stack.
    # We could combine stacks for the saem repo, but we'd have to sort out
    # concurrency issues. Doable. But skipping for now.
    git clone -q ${remote} ${name}
  fi

  enter_repo

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

  run_script "ink-init"

  if [ $local_repo -ne 1 ]; then
    git push -q -u origin "${name}" &> /dev/null
  fi

  exit_repo

  echo "${name}"
}

create () {
  echo
}

destroy () {
  name="${1}"

  if [ -d .git ]; then
    local_repo=1
  elif [ ! -d "${name}" ]; then
    echo "Ink ${name} does not exist"
    exit 1
  fi

  enter_repo

  git fetch -q origin
  if [ $local_repo -ne 1 ]; then
    git pull -q
  fi

  run_script "ink-destroy"

  if [ $local_repo -ne 1 ]; then
    git push -q origin :"${name}"
    git fetch -q --prune
  fi

  exit_repo

  if [ $local_repo -ne 1 ]; then
    rm -rf "${name}"
  else
    git branch -q -D ${name}
  fi
}

err () {
  >&2 echo $1
}

if [ $# -eq 0 ] || [ "$1" == "help" ]; then
  help
elif [ "$1" == "init" ]; then
  if [ $# -lt 2 ]; then
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
  if [ $# -lt 2 ]; then
    err "destroy what?"
    help
  else
    destroy $2
  fi
else
    >&2 echo "Unknown command"
    help
fi
