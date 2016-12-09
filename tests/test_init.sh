#!/bin/bash
set -e

export PATH=$( pwd ):$( pwd )/tests/:$PATH
repo="test_repo"

. $(dirname $0)/util.sh

init_local () {
  enter_repo ${repo}

  name=$(ink init .)
  if [ -z "$name" ]; then
    err "No name"
    exit 1
  fi

  branch=$(git rev-parse --abbrev-ref HEAD)
  if [[ "${branch}" != "master" ]]; then
    err "Current branch should be master"
    exit 1
  fi

  if [ ! -f .ink-env ]; then
    err "Failed to find ink file"
    exit 1
  fi

  if ! git log --oneline | head -1 | grep "ink init" >/dev/null; then
    err "Failed to find init commit"
    git log --oneline
    exit 1
  fi

  exit_repo ${repo}
}

init_local_branch () {
  enter_repo ${repo}

  name=$(ink init . ink_id=fizz)
  if [ -z "$name" ]; then
    err "No name"
    exit 1
  fi

  if [ ! "$name" = "test_repo-fizz" ]; then
    err "Incorrect name ${name}"
    exit 1
  fi

  branch=$(git rev-parse --abbrev-ref HEAD)
  if [[ "${branch}" != "master" ]]; then
    err "Current branch should be master"
    exit 1
  fi

  git checkout -q "ink-${name}"

  if [ ! -f .ink-env ]; then
    err "Failed to find ink file"
    exit 1
  fi

  if ! git log --oneline | head -1 | grep "ink init" >/dev/null; then
    err "Failed to find init commit"
    git log --oneline
    exit 1
  fi

  exit_repo ${repo}
}

init_remote () {
  enter_remote

  build_repo ".A"

  name=$(ink init ./.A)
  if [ -z $name ]; then
    err "No name"
    exit 1
  fi

  if [ ! -d ${name} ]; then
    err "Missing checkout"
    exit 1
  fi

  cd ${name}

  if [ ! -f .ink-env ]; then
    err "Failed to find ink file"
    exit 1
  fi

  cd ..

  cd .A
  if [ ! -f .ink-env ]; then
    err "Failed to find ink file"
    exit 1
  fi
  cd ..

  exit_remote
}

init_remote_branch () {
  enter_remote

  build_repo ".A"

  name=$(ink init ./.A)
  if [ -z $name ]; then
    err "No name"
    exit 1
  fi

  if [ ! -d ${name} ]; then
    err "Missing checkout"
    exit 1
  fi

  cd ${name}

  git checkout -q "ink-${name}"

  if [ ! -f .ink ]; then
    err "Failed to find ink file"
    exit 1
  fi

  cd ..

  cd .A
  if ! git branch | grep ${name} >/dev/null; then
    err "No branch in remote"
    exit 1
  fi

  git checkout -q ink-${name}
  if [ ! -f .ink ]; then
    err "Failed to find ink file"
    exit 1
  fi
  cd ..

  exit_remote
}

init_with_args () {
  enter_repo ${repo}

  name=$(ink init . foo=fizz bar=buzz)
  if [ -z "$name" ]; then
    err "No name"
    exit 1
  fi

  git checkout -q "ink-${name}"

  if [ ! -f .ink-env ]; then
    err "Failed to find ink file"
    exit 1
  fi

  if ! grep -q "ink_name=" .ink-env; then
    err "Failed to find ink_name"
    exit 1
  fi

  if ! grep -q "TF_VAR_foo=fizz" .ink-env; then
    err "Failed to find FOO"
    exit 1
  fi

  if ! grep -q TF_VAR_bar=buzz .ink-env; then
    err "Failed to find FOO"
    exit 1
  fi

  exit_repo ${repo}
}

init_with_id () {
  enter_repo ${repo}

  name=$(ink init . ink_id=fizz)
  if [ -z "$name" ]; then
    err "No name"
    exit 1
  fi

  if [ ! "$name" = "test_repo-fizz" ]; then
    err "Incorrect name ${name}"
    exit 1
  fi

  exit_repo ${repo}
}

init_with_name () {
  enter_repo ${repo}

  name=$(ink init . ink_name=fizz)
  if [ -z "$name" ]; then
    err "No name"
    exit 1
  fi

  if [ ! "$name" = "fizz" ]; then
    err "Incorrect name ${name}"
    exit 1
  fi

  exit_repo ${repo}
}

init_with_setup () {
  enter_repo ${repo}

  mkdir -p script

  cat <<EOF > script/setup
#!/bin/bash
touch \${TF_VAR_foo}.db
EOF
  chmod +x script/setup

  git add script
  git commit -q -m "added setup script"

  name=$(ink init . foo=fizz)

  git checkout -q ink-${name}

  if [ ! -f fizz.db ]; then
    err "setup didnt' run"
    exit 1
  fi

  exit_repo ${repo}
}

init_local
#init_local_branch
#init_remote
#init_remote_branch
#init_with_args
#init_with_name
#init_with_id
#init_with_setup
