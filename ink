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
ink_branch=""
exit_ret=0
env_args=""
tf_opts=""
cb_name="" # Change Branch name (for dealing with changes)
cb_ref=""
is_github=0
github_url=""

# These keep track of if we're running in local repo mode, meaning we're being
# executed from within a repo and won't be managing the remotes or cloning
# ourselves.
start_branch=""
local_repo=0

export TF_INPUT=0

help () {
  echo "Usage: $(basename $0) <add|list|plan|apply|destroy|key|help>"
  exit 1
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

# Parse a github clone url and give the <username>/<repo> path
extract_repo_path () {
  local regex=".*:(.+)\.git$"

  if [[ "$1" =~ $regex ]]; then
    echo "${BASH_REMATCH[1]}"
  else
    echo $(basename $1)
  fi
}

clone_url () {
  if [[ $1 == *:* ]] || [ -d $1 ]; then
    echo $1
  else
    echo "git@github.com:$1.git"
  fi
}

# Show the most recent SHA
see_commit_msg () {
  local sha=$(git log -n 1 --pretty=format:"%h")
  if [ $is_github -eq 1 ] && [ $local_repo -ne 1 ]; then
    echo "${github_url}/commit/${sha}"
  else
    echo "See commit $sha"
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

  if [ $local_repo -eq 1 ]; then
    start_branch=$(git rev-parse --abbrev-ref HEAD)
  else
    pushd ${ink_name} &> /dev/null

    if ! git fetch -qp origin; then
      err "Failed to fetch from origin"
      exit 1
    fi
  fi

  # NOTE: newer git versions provide get-url, which sure would be handy
  local remote_url=$(git remote -v | grep origin | head -n 1 | awk '{print $2}')

  # We have certain functionality we only want to enable if we are using github
  # as origin. We can do fancy stuff like provide links to commits.
  if [[ $remote_url == git@github.com:* ]]; then
    is_github=1

    local path=$(extract_repo_path $remote_url)
    github_url="https://github.com/${path}"
  else
    is_github=0
  fi

  local repo
  if [ $local_repo -eq 1 ]; then
    repo=$(basename $(pwd))
  else
    repo=$(extract_repo_name $remote_url)
  fi

  if [ "$ink_name" == "$repo" ]; then
    ink_branch="master"
  else
    ink_branch="ink-$ink_name"
  fi

  if ! git checkout -q ${ink_branch} 2>/dev/null; then
    # It might just not exist yet
    local track_opt
    if [ $local_repo -eq 0 ]; then
      track_opt="--track"
    fi

    if ! git checkout -q -b ${ink_branch} $track_opt; then
      err "Failed to create branch ${branch}"
      exit 1
    fi
  else
    if [ $local_repo -eq 0 ]; then
      if ! git pull -q --ff-only origin ${ink_branch}; then
        err "Failed to update with origin"
        exit 1
      fi
    fi
  fi

  # This can only be done after we are in our repository context as it might
  # create an ink-logs directory.
  log=$(logger "$cmd")

  export_env_args
}

exit_repo () {
  if git rev-parse --abbrev-ref --symbolic-full-name @{u} &>/dev/null; then
    if ! git push -q origin "${ink_branch}" ; then
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

# During add, someone might have specified and override for the name. Extract it here.
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

# Add and initialize the specified git repository for use with a new ink stack
# This may mean cutting a new branch and putting all the right stuff in it.
add () {
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
  if [ -z "$ink_name" ]; then
    if [ -n "$ink_id" ]; then
      ink_name="$repo-$ink_id"
    else
      # Neither name or id has been specified, so we're naming everything
      # after the repo and using 'master' as our branch.
      ink_id="$repo"
      ink_name="$repo"
      ink_branch="master"
    fi
  fi

  if [ -z "$ink_branch" ]; then
    ink_branch="ink-${ink_name}"
  fi

  if [ $local_repo -ne 1 ] && [ ! -d ${ink_name} ]; then
    # We actually keep a separate repo for each stack.
    # We could combine stacks for the same repo, but we'd have to sort out
    # concurrency issues. Doable. But skipping for now.
    git clone -q -- $(clone_url $remote) ${ink_name}
  fi

  enter_repo

  if ! _=$(git status); then
    err "Not a git repository"
    exit 1
  fi

  # We allow ink to provide common variables
  if [ $local_repo -ne 1 ] && [ -f ../.ink-env ]; then
    cat ../.ink-env >> .ink-env
  fi

  # Everyone needs to know their name
  echo "TF_VAR_ink_name=${ink_name}" >> .ink-env

  save_env_args
  git add ./.ink-env

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

  if ! git commit -q -m "ink add"; then
    err "Failed to commit ink add"
    exit 1
  fi

  if [ $local_repo -ne 1 ]; then
    git push -q -u origin "${branch}" &> /dev/null
  fi

  echo "Added ${ink_name}"

  exit_repo
}

# Shutdown and remove an existing ink stack
destroy () {
  enter_repo

  if [ ! -f terraform.tfstate ] || terraform destroy -no-color -force -refresh=false &>$log; then
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
    msg="ink destroy"
    echo "Destroyed ${ink_name}"
  else
    err "Failed destroying ${ink_name}"
    msg="ink destroy [failed]"
    exit_ret=1
  fi

  # Just in case this was left over from some plan, this should avoid confusing
  # apply behavior later on.
  if [ -f ink.plan ]; then
    git rm -q ink.plan
  fi

  git add -A .
  if ! git commit -q --allow-empty -m "${msg}"; then
    err "Failed to commit"
    exit 1
  fi

  if [ $local_repo -eq 1 ]; then
    cat $log
  fi

  see_commit_msg

  exit_repo

  if [ $exit_ret -eq 0 ]; then
    if [ $local_repo -ne 1 ]; then
      # Since for now, our layout is based on the name of the stack, we'll just
      # wipe out the repo.
      rm -rf "${ink_name}"
    fi
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
  local plan_branch

  if [ -n "$cb_name" ]; then
    plan_branch="${cb_name}_${ink_name}"
    if ! git checkout -q "$plan_branch" 2>/dev/null; then
      local track_opt
      if [ $local_repo -ne 1 ]; then
        track_opt="--track"
      fi

      if ! git checkout -q -b "$plan_branch" $track_opt; then
        err "Failed to checkout $plan_branch"
        exit 1
      fi
    fi

    local cb_branch_ref="$cb_name"
    if [ $local_repo -ne 1 ] && [[ $cb_branch_ref != origin/* ]]; then
      # If we are using a remote, merge needs to know it (unlike checkout which
      # does it for free)
      cb_branch_ref="origin/${cb_name}"
    fi

    if ! git merge -q -m "Auto-merge via ink apply $cb_branch_ref" $cb_branch_ref; then
      err "Failed to auto-merge $cb_branch_ref"
      git merge --abort
      git checkout -q $ink_branch
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
    echo "Plan success!"
    if [ $local_repo -eq 1 ]; then
      cat $log
    fi
    see_commit_msg
  else
    err "Plan failed"
    cat $log >&2
  fi

  if [ -n "$plan_branch" ] && [ $local_repo -ne 1 ]; then
    if ! git push origin $plan_branch &>/dev/null; then
      err "Failed to push $plan_branch to origin"
      exit_ret=1
    fi

  fi

  # Restore to original branch
  if [ -n "$plan_branch" ]; then
    git checkout -q $ink_branch

    # Cleanup after ourselves
    if [ $local_repo -ne 1 ]; then
      if ! git branch -qD $plan_branch; then
        err "Failed to delete $plan_branch"
      fi
    fi
  fi

  exit_repo
}

apply () {
  local plan_file
  if [ -f ink.plan ]; then
    plan_file="ink.plan"
  fi

  enter_repo

  if [ -n "$cb_ref" ]; then
    if ! git merge -q --ff-only $cb_ref; then
      err "Failed to merge $cb_ref"
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

  if [ $local_repo -eq 1 ]; then
    cat $log
  fi

  see_commit_msg

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

# For remote usage, provide the SSH Identity for easy repo configuration.
display_key () {
  if [ -f "$HOME/.ssh/id_rsa.pub" ]; then
    cat "$HOME/.ssh/id_rsa.pub"
  else
    err "Failed to find SSH identity"
    exit 1
  fi
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
  elif [[ $1 == "key" ]]; then
    display_key
    exit $exit_Ret
  else
    err "$1 what?"
    help
  fi
fi

cmd="$1"
shift

case $cmd in
add)
  repo=$1
  shift
  env_args="$*"
  add "$repo"
  ;;
destroy)
  ink_name=$1
  destroy
  ;;
apply)
  ink_name=$1
  cb_ref=$2
  apply
  ;;
plan)
  ink_name=$1
  cb_name=$2
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
