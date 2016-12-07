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
ink_name=""
ink_id=""
exit_ret=0
env_args=""
tf_opts=""
cb_name="" # Change Branch name (for dealing with changes)
cb_sha=""

# These keep track of if we're running in local repo mode, meaning we're being
# executed from within a repo and won't be managing the remotes or cloning
# ourselves.
start_branch=""
local_repo=0

export TF_INPUT=0

help () {
  echo "Usage: $(basename $0) <init|list|plan|apply|destroy|help>"
  exit 1
}

build_name () {
  if [ -n "$ink_name" ]; then
    echo "$ink_name"
  elif [ -n "$ink_id" ]; then
    echo "$1-$ink_id"
  else
    ink_id=$(head /dev/urandom | md5sum | cut -c1-5)
    echo "$1-$ink_id"
  fi
}

branch_name () {
  echo "ink-$1"
}

logger () {
  local action=$1
  local date=$( date -u "+%Y%m%d%H%M%S"  )

  mkdir -p ink-logs
  echo "ink-logs/${date}-ink-${action}.log"
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
  elif [ ! -d "${ink_name}" ]; then
    echo "Ink ${ink_name} does not exist"
    exit 1
  fi

  local branch="$(branch_name "${ink_name}")"

  if [ $local_repo -eq 1 ]; then
    start_branch=$(git rev-parse --abbrev-ref HEAD)

    # Our working branch *might* already exist
    git checkout -q ${branch} &>/dev/null || true
  else
    pushd ${ink_name} &> /dev/null
    if ! git fetch -q origin; then
      err "Failed to fetch from origin"
      exit 1
    fi

    if git checkout -q ${branch} &>/dev/null; then
      if ! git pull -q --ff-only origin; then
        err "Failed to update with origin"
        exit 1
      fi
    fi
  fi

  export_env_args
}

exit_repo () {
  local branch="$(branch_name "${ink_name}")"

  if git rev-parse --abbrev-ref --symbolic-full-name @{u} &>/dev/null; then
    if ! git push -q origin "${branch}" ; then
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

# During init, someone might have specified and override for the name. Extract it here.
load_env_args_name () {
  for arg in $env_args; do
    if [[ "$arg" =~ ink_name=(.+) ]]; then
      ink_name="${BASH_REMATCH[1]}"
    elif [[ "$arg" =~ ^ink_id=(.+) ]]; then
      ink_id="${BASH_REMATCH[1]}"
    fi
    shift
  done
}

save_env_args () {
  for arg in $env_args; do
    if [[ "$arg" =~ .=. ]]; then
      echo "TF_VAR_$arg" >> .ink-env
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
  ink_name=$(build_name "${repo}")
  local branch="$(branch_name "${ink_name}")"

  if [ $local_repo -ne 1 ]; then
    # We actually keep a separate repo for each stack.
    # We could combine stacks for the same repo, but we'd have to sort out
    # concurrency issues. Doable. But skipping for now.
    git clone -q -- ${remote} ${ink_name}
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

  echo "TF_VAR_ink_name=${ink_name}" >> .ink-env

  save_env_args
  if [ -f ./.ink-env ]; then
    git add ./.ink-env
  fi

  export_env_args

  if ! output=$(terraform get -no-color); then
    echo "Failed to retrieve dependencies"
    echo "${output}"
    exit 1
  fi

  if [ -x script/setup ]; then
    if ! script/setup; then
      err "Failed to execute setup"
      exit_ret=1
    fi
  fi

  if ! git commit -q -m "ink init"; then
    err "Failed to commit ink init"
    exit 1
  fi

  if [ $local_repo -ne 1 ]; then
    git push -q -u origin "${branch}" &> /dev/null
  fi
  echo "${ink_name}"

  exit_repo
}

# Shutdown and remove an existing ink stack
destroy () {
  local branch="$(branch_name "${ink_name}")"

  enter_repo

  if [ ! -f terraform.tfstate ] || terraform destroy -force -refresh=false; then
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
      rm -rf "${ink_name}"
    else
      git branch -q -D ${branch}
    fi

    echo "Destroyed ${ink_name}"
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

  if [ -x script/update ]; then
    if ! script/update; then
      err "Failed to execute update script"
      exit_ret=1
    fi
  fi

  if [ "$exit_ret" -eq 0 ]; then
    terraform ${cmd}
    exit_ret=$?
    if [ "$exit_ret" -eq 0 ]; then
      msg="ink ${cmd}"
    else
      msg="ink ${cmd} [failed]"
    fi
  else
    msg="ink ${cmd} [update failed]"
  fi

  # No matter what we want to save any changes

  git add -A .
  if ! git commit -q --allow-empty -m "${msg}"; then
    err "Failed to commit ink ${cmd}"
    exit 1
  fi

  exit_repo
}

plan () {
  enter_repo

  local msg
  local branch
  local restore_branch


  if [ -n "$cb_name" ]; then
    restore_branch=$(git rev-parse --abbrev-ref HEAD)

    branch="${cb_name}_${ink_name}"
    if ! git checkout -q "$branch" 2>/dev/null; then
      local track_opt
      if [ $local_repo -ne 1 ]; then
        track_opt="--track"
      fi

      if ! git checkout -q -b "$branch" $track_opt; then
        err "Failed to checkout $branch"
        exit 1
      fi
    fi

    if ! git merge -q -m "Auto-merge via ink apply $cb_name" origin/$cb_name; then
      err "Failed to auto-merge $cb_name"
      git merge --abort
      git checkout -q $restore_branch
      exit 1
    fi
  fi

  if [ -x script/update ]; then
    if ! script/update &>$log; then
      err "Failed to execute update script"
      msg="ink plan [update failed]"
      exit_ret=1
    fi
  fi

  if [ "$exit_ret" -eq 0 ]; then
    terraform plan -refresh=false -no-color -out=ink.plan &>$log
    exit_ret=$?
    if [ "$exit_ret" -eq 0 ]; then
      msg="ink plan"
    else
      msg="ink plan [failed]"
    fi
  fi

  # No matter what we want to save any changes

  git add -A .
  if ! git commit -q --allow-empty -m "${msg}"; then
    err "Failed to commit ink plan"
    exit 1
  fi

  if [ $exit_ret -eq 0 ]; then
    git log -n 1 --pretty=format:"%h"
  else
    err "Plan failed"
    cat $log >&2
  fi

  if [ -n "$branch" ] && [ $local_repo -ne 1 ]; then
    if ! git push origin $branch; then
      err "Failed to push $branch to origin"
      exit_ret=1
    fi
  fi

  if [ -n "$restore_branch" ]; then
    git checkout -q $restore_branch
  fi

  exit_repo
}

apply () {
  local plan_file
  if [ -f ink.plan ]; then
    plan_file="ink.plan"
  fi

  enter_repo

  if [ -n "$cb_sha" ]; then
    if ! git merge -q --ff-only $cb_sha; then
      err "Failed to merge $cb_sha"
      exit 1
    fi
  elif [ -n "$cb_name" ]; then
    if ! git merge -q -m "Auto-merge via ink apply $cb_name" origin/$cb_name; then
      git merge --abort
      err "Failed to auto-merge $cb_name"
      exit 1
    fi
  fi

  if [ -x script/update ]; then
    if ! script/update &>$log; then
      err "Failed to execute update script"
      msg="ink ${cmd} [update failed]"
      exit_ret=1
    fi
  fi

  if [ "$exit_ret" -eq 0 ]; then
    terraform apply -no-color -refresh=false ${plan_file} &>$log
    exit_ret=$?
    if [ "$exit_ret" -eq 0 ]; then
      msg="ink apply"

      if [ -f ink.plan ]; then
        git rm -q ink.plan
      fi
    else
      msg="ink ${cmd} [failed]"
    fi
  fi

  # No matter what we want to save any changes

  git add -A .
  if ! git commit -q --allow-empty -m "${msg}"; then
    err "Failed to commit ink ${cmd}"
    exit 1
  fi

  if [ $exit_ret -eq 0 ]; then
    echo "Apply success!"
  else
    err "Apply failed"
    cat $log >&2
  fi

  sha=$(git log -n 1 --pretty=format:"%h")
  if [ $is_github -eq 1 ]; then
    echo "See ${github_url}/commit/${sha} for logs"
  else
    echo "See commit $sha"
  fi

  exit_repo
}

output () {
  enter_repo

  terraform output -no-color
  exit_ret=$?

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
  # Our only single arg command
  if [[ $1 == "list" ]]; then
    show_stacks
    exit $exit_ret
  else
    err "$1 what?"
    help
  fi
fi

cmd="$1"
shift

log=$(logger "$cmd")

case $cmd in
init)
  repo=$1
  shift
  env_args="$*"
  init "$repo"
  ;;
destroy)
  ink_name=$1
  destroy
  ;;
apply)
  ink_name=$1
  cb_name=$2
  apply
  ;;
plan)
  ink_name=$1
  cb_name=$2
  cb_sha=$3
  plan
  ;;
refresh|get)
  ink_name=$1
  action "$cmd"
  ;;
output)
  ink_name=$1
  output
  ;;
*)
  err "Unknown command"
  help
  ;;
esac

exit $exit_ret
