#!/bin/bash
set -e

PATH=$(dirname $0)/../:$PATH
repo="test_repo"

. $(dirname $0)/util.sh

enter_repo ${repo}

name=$(ink init .)
ink destroy ${name}

if git branch | grep ${name}; then
  err "Branch ${name} wasn't cleaned up"
  exit 1
fi

exit_repo ${repo}
