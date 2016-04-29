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

enter_remote () {
  local remote_path="test_remote"
  if [ -d ${remote_path} ]; then
    rm -rf ${remote_path}
  fi

  mkdir ${remote_path}

  cd ${remote_path}
}

exit_remote () {
  local remote=$( basename `pwd` )
  cd ..

  rm -rf ./$remote
}
