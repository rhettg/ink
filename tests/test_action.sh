#!/bin/bash
set -e

PATH=$(dirname $0)/../:$PATH
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

success_script
failed_script
