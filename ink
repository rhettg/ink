#!/bin/bash

# OMG BASH?!? WTF
# Ok, bare with me, yes this is probably the most advanced bash script I've
# ever written, and I kinda just wanted to see if I could do it. BUT, it's also
# really pretty simple because all we're really doing is building a workflow
# around git. We have to run some git commands, checks some results and handle
# some errors.

# We purposefully do not use set -e because it causes some issues with
# capturing exit codes when we want to. Instead, we explicitly check exits.
# Unless we forget one, which would be bad. But hey, that's bash programming
# for you.
set -o pipefail
if [ -n "$DEBUG" ]; then
  set -x
fi

# Fun Globals to keep track of
name=""
exit_ret=0
env_args=""

# These keep track of if we're running in local repo mode, meaning we're being
# executed from within a repo and won't be managing the remotes or cloning
# ourselves.
start_branch=""
local_repo=0

help () {
  echo "Usage: $(basename $0) <init|create|update|show|destroy|help>"
  exit 1
}

build_name () {
  if [ -n "$INK_NAME" ]; then
    echo "$INK_NAME"
  elif [ -n "$ID" ]; then
    echo "$1-$ID"
  else
    local id=$(head /dev/urandom | md5sum | cut -c1-5)
    echo "$1-$id"
  fi
}

branch_name () {
  echo "ink-$1"
}

# Parse a repo clone argument and infer what the repo name should be
extract_repo_name () {
  local regex="([^\/]+)\.git$"

  if [[ "$1" =~ $regex ]]; then
    echo "${BASH_REMATCH[1]}"
  else
    echo $(basename $1)
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

  local branch="$(branch_name "${name}")"

  if [ $local_repo -eq 1 ]; then
    start_branch=$(git rev-parse --abbrev-ref HEAD)

    # Our working branch *might* already exist
    git checkout -q ${branch} &>/dev/null || true
  else
    pushd ${name} &> /dev/null
    if ! git fetch -q origin; then
      err "Failed to fetch from origin"
      exit 1
    fi

    if git checkout -q ${branch} &>/dev/null; then
      # We alway stay up to date with our master, auto merging if necessary
      if git diff origin/master | grep diff >/dev/null; then
        if ! git merge --no-ff -q -m "Ink auto-merge origin/master into ${branch}" origin/master; then
          git merge --abort
          err "Failed to merge with origin"
          exit 1
        fi
      fi
    else
      # We don't have an ink branch, let's just make sure master is up to do date
      git checkout -q master
      git pull -q --ff-only
    fi
  fi

  export_env_args
}

exit_repo () {
  local branch="$(branch_name "${name}")"

  if git rev-parse --abbrev-ref --symbolic-full-name @{u} &>/dev/null; then
    if ! git push -q origin "${branch}" &> /dev/null; then
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

# Execute the user defined run script
# If it doesn't exist, that's ok, just skip.
# We're going to collect non-0 exit status as a global which will be passed
# onto our caller
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

# During init, someone might have specified and override for the name. Extract it here.
load_env_args_name () {
  for arg in $env_args; do
    if [[ "$arg" =~ INK_NAME=(.+) ]]; then
      INK_NAME="${BASH_REMATCH[1]}"
    elif [[ "$arg" =~ ^ID=(.+) ]]; then
      ID="${BASH_REMATCH[1]}"
    fi
    shift
  done
}

save_env_args () {
  for arg in $env_args; do
    if [[ "$arg" =~ .=. ]]; then
      echo "$arg" >> .ink-env
    fi
    shift
  done
}

export_env_args () {
  local arg_names
  if [ -f ./.ink-env ]; then
    source ./.ink-env
    arg_names=$(cat ./.ink-env | cut -d "=" -f 1 | awk  '{gsub("\n"," ")};1')
    export $arg_names
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
      exit 1
    fi
  fi

  load_env_args_name
  name=$(build_name "${repo}")
  local branch="$(branch_name "${name}")"

  if [ $local_repo -ne 1 ]; then
    # We actually keep a separate repo for each stack.
    # We could combine stacks for the same repo, but we'd have to sort out
    # concurrency issues. Doable. But skipping for now.
    git clone -q -- ${remote} ${name}
  fi

  enter_repo

  if ! _=$(git status); then
    err "Not a git repository"
    exit 1
  fi

  if ! git checkout -q -b ${branch}; then
    err "Failed to create branch ${branch}"
    exit 1
  fi

  if [ -f .ink ]; then
    err "Ink state file already exists"
    exit 1
  fi

  touch .ink
  git add .ink

  echo "INK_NAME=${name}" >> .ink-env

  save_env_args
  if [ -f ./.ink-env ]; then
    git add ./.ink-env
  fi

  export_env_args

  if ! git commit -q -m "ink init"; then
    err "Failed to commit ink init"
    exit 1
  fi

  if run_script "ink-init"; then
    if [ $local_repo -ne 1 ]; then
      git push -q -u origin "${branch}" &> /dev/null
    fi
    echo "${name}"
  else
    err "init failed, what to do?"
  fi

  exit_repo
}

# Shutdown and remove an existing ink stack
destroy () {
  local branch="$(branch_name "${name}")"

  enter_repo

  if run_script "ink-destroy"; then
    #if [ $local_repo -ne 1 ]; then
      # We'll just log but otherwise ignore errors in here. If our cleanup fails...
      # is that worth bailing? Maybe not.
      # For now we're going to NOT delete this from origin.
      # Basically, if there is a mistake and we delete everything, it's a real
      # pain (or impossible) to restore it.
      #
      #if ! git branch -q --unset-upstream; then
        #err "Failed to unset upstream"
      #fi
      #
      # We should probably some how mark them and clean them up later
      #if ! git push -q origin :"${name}"; then
        #err "Failed to delete remote branch"
      #fi
    #fi

    exit_repo

    if [ $local_repo -ne 1 ]; then
      # Since for now, our layout is based on the name of the stack, we'll just
      # wipe out the repo.
      rm -rf "${name}"
    else
      git branch -q -D ${branch}
    fi
  else
    err "Failed destroying"
    exit_repo
  fi
}

# Handle all our standard actions that just call the associated user script and
# commit any changes.
action () {
  local cmd=$1

  enter_repo

  if run_script "ink-${cmd}"; then
    git add -A .
    if ! git commit -q --allow-empty -m "ink ${cmd}"; then
      err "Failed to commit ink ${cmd}"
      exit 1
    fi
  fi

  # TODO: What do we do in a failure case here if there were changes? Commit
  # them? Roll them back?

  exit_repo
}

# Handle all our standard queries that just call the associated user script and
# return the results
query () {
  local cmd=$1

  enter_repo

  run_script "ink-${cmd}"

  # For a query, we want to throw any changes.
  if ! git reset -q --hard HEAD; then
    err "Failed to reset repo"
    exit 1
  fi

  if ! git clean -qfd; then
    err "Failed to cleanup repo"
    exit 1
  fi

  exit_repo
}

# List available stacks
show_stacks () {
  if [ -d .git ]; then
    git branch --no-column --no-color --list "ink-$(basename `pwd`)*" | cut -c 7-
  else
    for is in $( find . -maxdepth 1 -type d \( ! -name ".*" \)); do
      basename ${is}
    done
  fi
}

# Log an error
err () {
  >&2 echo $1
}

## Main ##

if [ $# -eq 0 ] || [ "$1" == "help" ]; then
  help
fi

if [ $# -lt 2 ]; then
  if [[ $1 == "show" ]]; then
    show_stacks
    exit $exit_ret
  else
    err "${$1} what?"
    help
  fi
fi

cmd="$1"
shift

case $cmd in
init)
  repo=$1
  shift
  env_args="$*"
  init "$repo"
  ;;
destroy)
  name=$1
  destroy
  ;;
update|create)
  name=$1
  action "$cmd"
  ;;
show|plan)
  name=$1
  query "$cmd"
  ;;
*)
  err "Unknown command"
  help
  ;;
esac

exit $exit_ret
