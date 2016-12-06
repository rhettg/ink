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

success_apply_merge () {
  enter_repo ${repo}

  name=$(ink init .)

  git checkout -q -b a-change
  touch change.txt
  git add change.txt
  git commit -qa -m "added a file"
  git checkout -q master

  ink apply ${name} a-change

  git checkout -q ink-${name}
  if [ ! -f state.db ]; then
    err "Create didn't run"
    exit 1
  fi

  if [ ! -f change.txt ]; then
    err "missing merge"
    exit 1
  fi

  if ! git log --oneline | head -1 | grep "ink apply" >/dev/null; then
    err "Failed to find apply commit"
    git log --oneline
    exit 1
  fi

  exit_repo ${repo}
}

success_apply_merge_sha () {
  enter_repo ${repo}

  name=$(ink init .)

  git checkout -q -b a-change
  touch change.txt
  git add change.txt
  git commit -qa -m "added a file"
  git checkout -q master

  sha=$(ink plan ${name} a-change)

  if [ -z "$sha" ]; then
    err "Missing sha"
    exit 1
  fi

  ink apply ${name} a-change $sha

  git checkout -q ink-${name}
  if [ ! -f state.db ]; then
    err "Create didn't run"
    exit 1
  fi

  if [ ! -f change.txt ]; then
    err "missing merge"
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

  mkdir -p script

  cat <<EOF > script/update
#!/bin/bash
touch \${TF_VAR_foo}.db
EOF
  chmod +x script/update

  git add script
  git commit -q -m "added setup script"

  name=$(ink init . foo=fizz)

  if ! ink apply ${name}; then
    err "apply failed"
    exit 1
  fi

  git checkout -q ink-${name}

  if [ ! -f fizz.db ]; then
    err "setup didnt' run"
    exit 1
  fi

  exit_repo ${repo}
}

success_plan_merge () {
  enter_repo ${repo}

  name=$(ink init .)

  git checkout -q -b a-change
  touch change.txt
  git add change.txt
  git commit -qa -m "added a file"
  git checkout -q master

  ink plan ${name} a-change >/dev/null

  git checkout -q a-change_${name}

  if [ ! -f change.txt ]; then
    err "missing merge"
    exit 1
  fi

  if [ ! -f ink.plan ]; then
    err "Missing plan"
    exit 1
  fi

  if ! git log --oneline | head -1 | grep "ink plan" >/dev/null; then
    err "Failed to find plan commit"
    git log --oneline
    exit 1
  fi

  exit_repo ${repo}
}

success_apply
success_apply_merge
success_apply_merge_sha
failed_apply
remote_success_script
remote_merge
success_plan_merge
env_script
