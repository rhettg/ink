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
