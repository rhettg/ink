err () {
  echo $1 >&2
}

enter_repo () {
  local repo=$1
  if [ -d ${repo} ]; then
    rm -rf ${repo}
  fi

  mkdir ${repo}
  cd ${repo}
  git init -q .
  git commit -q --allow-empty -m "initial commit"
}

exit_repo () {
  cd ..
  rm -rf $1
}

build_remote () {
  local remote_path="test_remote"
  if [ -d ${remote_path} ]; then
    rm -rf ${remote_path}
  fi

  mkdir ${remote_path}

  echo $remote_path
}

build_repo () {
  local repo=$1
  mkdir ${repo}

  cd ${repo}
  git init -q .
  git commit -q --allow-empty -m "initial commit for ${repo}"
  cd ..
}

ink_init () {
  echo "$(ink init $@ | awk '{print $2}')"
}

