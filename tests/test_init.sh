#!/bin/bash
set -e

PATH=$(dirname $0)/../:$PATH
repo="test_repo"

. $(dirname $0)/util.sh


enter_repo ${repo}

name=$(ink init .)
if [ -z $name ]; then
  err "No name"
  exit 1
fi

branch=$(git rev-parse --abbrev-ref HEAD)
if [[ "${branch}" != "master" ]]; then
  err "Current branch should be master"
  exit 1
fi

git checkout -q "${name}"

if [ ! -f .ink ]; then
  err "Failed to find ink file"
  exit 1
fi

exit_repo ${repo}
