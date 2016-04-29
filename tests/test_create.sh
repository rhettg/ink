#!/bin/bash
set -e

PATH=$(dirname $0)/../:$PATH

err () {
  echo $1 >&2
}

if [ -d test_create ]; then
  rm -rf test_create
fi

mkdir test_create
cd test_create
git init -q .
git commit -q --allow-empty -m "initial commit"

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

cd ..
rm -rf test_create
