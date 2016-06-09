#!/bin/bash
set -e

PATH=$( pwd ):$PATH
repo="test_repo"

. $(dirname $0)/util.sh

enter_repo ${repo}

mkdir -p script
cat <<EOF > script/ink-show
#!/bin/bash
echo "hello world"
EOF
chmod +x script/ink-show

git add script
git commit -q -m "added show script"

name=$(ink init .)
output=$(ink show ${name})
if [[ "$output" != "hello world" ]]; then
  err "Bad output: ${output}"
  exit 1
fi

branch=$(git rev-parse --abbrev-ref HEAD)
if [[ "${branch}" != "master" ]]; then
  err "Current branch should be master"
  exit 1
fi

if ! git log --oneline ink-${name} | head -1 | grep "ink init" >/dev/null; then
  err "Should not have added commit"
  git log --oneline ${name}
  exit 1
fi

exit_repo ${repo}
