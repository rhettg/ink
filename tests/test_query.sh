#!/bin/bash
set -e

export PATH=$( pwd ):$( pwd )/tests/:$PATH
repo="test_repo"

. $(dirname $0)/util.sh

enter_repo ${repo}

name=$(ink_add .)

ink apply ${name} &>/dev/null

output=$(ink output ${name})
if [[ "$output" != "apply -no-color -refresh=false" ]]; then
  err "Bad output: ${output}"
  exit 1
fi

branch=$(git rev-parse --abbrev-ref HEAD)
if [[ "${branch}" != "master" ]]; then
  err "Current branch should be master"
  exit 1
fi

if ! git log --oneline | head -1 | grep "ink apply" >/dev/null; then
  err "Should not have added commit"
  git log --oneline
  exit 1
fi

exit_repo ${repo}
