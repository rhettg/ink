#!/bin/bash
set -e

PATH=$( pwd ):$PATH
repo="test_repo"

. $(dirname $0)/util.sh

success_script () {
  enter_repo ${repo}

  mkdir -p script

  cat <<EOF > script/ink-create
#!/bin/bash
touch state.db
EOF
  chmod +x script/ink-create

  git add script
  git commit -q -m "added create script"

  name=$(ink init .)
  ink create ${name}

  git checkout -q ${name}
  if [ ! -f state.db ]; then
    err "Create didn't run"
    exit 1
  fi

  if ! git log --oneline | head -1 | grep "ink create" >/dev/null; then
    err "Failed to find create commit"
    git log --oneline
    exit 1
  fi

  exit_repo ${repo}
}

failed_script () {
  enter_repo ${repo}

  mkdir -p script
  cat <<EOF > script/ink-create
#!/bin/bash
exit 1
EOF
  chmod +x script/ink-create

  git add script
  git commit -q -m "added create script"

  name=$(ink init .)
  if ink create ${name} &>/dev/null; then
    err "Create should have failed"
    exit 1
  fi

  branch=$(git rev-parse --abbrev-ref HEAD)
  if [[ "${branch}" != "master" ]]; then
    err "Current branch should be master"
    exit 1
  fi

  if git log ${name} --oneline | head -1 | grep "ink create" > /dev/null; then
    err "Found create commit after failure"
    git log --oneline
    exit 1
  fi

  exit_repo ${repo}
}

remote_success_script () {
  enter_remote
  build_repo "A"

  cd A

  mkdir -p script

  cat <<EOF > script/ink-create
#!/bin/bash
date > state.db
EOF
  chmod +x script/ink-create

  git add script
  git commit -q -m "added create script"

  cd ..

  name=$(ink init ./A)
  ink create ${name}

  cd ${name}

  git checkout -q ${name}
  if [ ! -f state.db ]; then
    err "Create didn't run"
    exit 1
  fi

  if ! git log --oneline | head -1 | grep "ink create" >/dev/null; then
    err "Failed to find create commit"
    git log --oneline
    exit 1
  fi

  if git log --oneline ${name} | grep "Ink auto-merge" >/dev/null; then
    err "Found auto-merge, should have no changes"
    git log --oneline
    exit 1
  fi

  cd ../A
  git checkout -q ${name}

  if ! git log --oneline | head -1 | grep "ink create" >/dev/null; then
    err "Failed to find create commit in origin"
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

  cd A

  mkdir -p script

  cat <<EOF > script/ink-create
#!/bin/bash
date > state.db
EOF
  chmod +x script/ink-create

  git add script
  git commit -q -m "added create script"

  cd ..

  ink create ${name}

  cd ${name}

  git checkout -q ${name}
  if [ ! -f state.db ]; then
    err "Create didn't run"
    exit 1
  fi

  if ! git log --oneline ${name} | grep "Ink auto-merge" >/dev/null; then
    err "Failed to find merge commit"
    git log --oneline
    exit 1
  fi

  cd ..

  exit_remote
}

env_script () {
  enter_repo ${repo}

  mkdir -p script

  # Don't forget to escape your '$'
  cat <<EOF > script/ink-create
#!/bin/bash
if ! [ "\${FOO}" = "fizz" ]; then
  echo "'\$FOO' isn't fizz"
  env
  exit 1
fi
EOF
  chmod +x script/ink-create

  git add script
  git commit -q -m "added create script"

  name=$(ink init . FOO=fizz)
  if ! ink create ${name}; then
    err "Create failed"
    exit 1
  fi

  exit_repo ${repo}
}

success_script
failed_script
remote_success_script
remote_merge
env_script
