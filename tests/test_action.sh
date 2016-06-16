#!/bin/bash
set -e

export PATH=$( pwd ):$( pwd )/tests/:$PATH
repo="test_repo"

. $(dirname $0)/util.sh

success_apply () {
  enter_repo ${repo}

  name=$(ink init .)
  ink apply ${name}

  git checkout -q ink-${name}
  if [ ! -f state.db ]; then
    err "Create didn't run"
    exit 1
  fi

  if ! git log --oneline | head -1 | grep "ink apply" >/dev/null; then
    err "Failed to find apply commit"
    git log --oneline
    exit 1
  fi

  exit_repo ${repo}
}

failed_apply () {
  enter_repo ${repo}

  name=$(ink init .)

  export INK_TEST_EXIT=1

  if ink apply ${name}; then
    err "Create should have failed"
    exit 1
  fi

  branch=$(git rev-parse --abbrev-ref HEAD)
  if [[ "${branch}" != "master" ]]; then
    err "Current branch should be master"
    exit 1
  fi

  git checkout -q ink-${name}

  if ! git log --oneline | head -1 | grep "ink apply" >/dev/null; then
    err "Failed to find apply commit"
    git log --oneline
    exit 1
  fi

  export INK_TEST_EXIT=0

  exit_repo ${repo}
}

remote_success_script () {
  enter_remote
  build_repo "A"

  name=$(ink init ./A)
  ink apply ${name}

  cd ${name}

  git checkout -q ink-${name}
  if [ ! -f state.db ]; then
    err "Create didn't run"
    exit 1
  fi

  if ! git log --oneline | head -1 | grep "ink apply" >/dev/null; then
    err "Failed to find apply commit"
    git log --oneline
    exit 1
  fi

  cd ../A
  git checkout -q ink-${name}

  if ! git log --oneline | head -1 | grep "ink apply" >/dev/null; then
    err "Failed to find apply commit in origin"
    git log --oneline
    exit 1
  fi

  cd ..

  exit_remote
}

# Verifying that our action merges in updates from origin
remote_merge () {
  enter_remote
  build_repo "A"
  name=$(ink init ./A)

  ink apply ${name}

  cd A


  git checkout -q ink-${name}
  git commit -q --allow-empty -m "test update"
  git checkout -q master

  cd ..

  ink apply ${name}

  cd ${name}

  git checkout -q ink-${name}

  if ! git log --oneline | grep "test update" >/dev/null; then
    err "Failed to find update"
    git log --oneline
    exit 1
  fi

  cd ..

  exit_remote
}

env_script () {
  enter_repo ${repo}

  export INK_TEST_EXIT=1
  name=$(ink init . TEST_EXIT=0)

  if ! ink apply ${name}; then
    err "apply failed"
    exit 1
  fi

  exit_repo ${repo}
}

success_apply
failed_apply
remote_success_script
remote_merge
env_script
