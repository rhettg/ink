#!/bin/bash

# We purposefully do not use set -e because it causes some issues with
# capturing exit codes when we want to. Instead, we explicitly check exits.
# Unless we forget one, which would be bad. But hey, that's bash programming
# for you.
set -u
set -o pipefail
set -x

# Fun Globals to keep track of
name=""
exit_ret=0

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
  if [ -d .git ]; then
    local_repo=1
  elif [ ! -d "${name}" ]; then
    echo "Ink ${name} does not exist"
    exit 1
  fi

  if [ $local_repo -eq 1 ]; then
    start_branch=$(git rev-parse --abbrev-ref HEAD)
  else
    pushd ${name} &> /dev/null
    if ! git fetch -q origin; then
      err "Failed to fetch from origin"
      exit 1
    fi

    if ! git pull -q; then
      err "Failed to pull changes from origin"
      exit 1
    fi
  fi

  # Our working branch *might* already exist
  git checkout -q ${name} &>/dev/null || true
}

exit_repo () {
  if git rev-parse --abbrev-ref --symbolic-full-name @{u} &>/dev/null; then
    if ! git push -q origin "${name}" &> /dev/null; then
      err "Failed to push changes to origin"
    fi
  fi

  if [ -n "${start_branch}" ]; then
    if ! git checkout -q "${start_branch}"; then
      err "Failed to restore branch ${start_branch}"
    fi
  else
    popd &> /dev/null
  fi
}

run_script () {
  local script_name=$1

  if [ -x script/${script_name} ]; then

    script/${script_name}
    exit_ret=$?
    if [ $exit_ret -ne 0 ]; then
      err "Failed executing ${script_name}"
    fi
  fi

  return $exit_ret
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
    # We could combine stacks for the same repo, but we'd have to sort out
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
  if ! git commit -q -m "ink init"; then
    err "Failed to commit ink init"
    exit 1
  fi

  if run_script "ink-init"; then
    if [ $local_repo -ne 1 ]; then
      git push -q -u origin "${name}" &> /dev/null
    fi
    echo "${name}"
  else
    err "init failed, what to do?"
  fi

  exit_repo
}

# Run create on an existing ink stack
create () {
  enter_repo

  if run_script "ink-create"; then
    git add -A .
    if ! git commit -q --allow-empty -m "ink create"; then
      err "Failed to commit ink create"
      exit 1
    fi
  fi

  exit_repo
}

# Shutdown and remove an existing ink stack
destroy () {
  enter_repo

  if run_script "ink-destroy"; then
    if [ $local_repo -ne 1 ]; then
      # We'll just log but other ignore errors in here. If our cleanup fails...
      # is that worth bailing? Maybe not.
      if ! git branch -q --unset-upstream; then
        err "Failed to unset upstream"
      fi

      if ! git push -q origin :"${name}"; then
        err "Failed to delete remote branch"
      fi
    fi

    exit_repo

    if [ $local_repo -ne 1 ]; then
      rm -rf "${name}"
    else
      git branch -q -D ${name}
    fi
  else
    err "Failed destroying"
    exit_repo
  fi
}

# Log an error
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
  if [ $# -lt 2 ]; then
    err "create what?"
    help
  else
    name=$2
    create
  fi
elif [ "$1" == "update" ]; then
    echo
elif [ "$1" == "destroy" ]; then
  if [ $# -lt 2 ]; then
    err "destroy what?"
    help
  else
    name=$2
    destroy
  fi
else
    >&2 echo "Unknown command"
    help
fi

exit $exit_ret
