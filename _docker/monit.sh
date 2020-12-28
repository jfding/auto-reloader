#!/bin/bash

[[ -z $VERB ]] && VERB=1
[[ -z $SLEEP_TIME ]] && SLEEP_TIME=60

# if VERB=0, keep super silent
[[ $VERB = 0 ]] && exec>/dev/null

# expect one argument "branch_name"
function checkout_and_copy {
  _repo=$1
  _br=$2

  _cp_path="../../copies/${_repo}.${_br}"

  # start to work on this br
  git checkout -q -f $_br

  # if no copy of this br, just mkdir with a skipping flag file
  # (do not actual copying files, unless admin specify it explicitly)
  [[ ! -d $_cp_path ]] && mkdir -p $_cp_path && touch $_cp_path/.skipping && echo "  init dir of [ $_br ]"


  if [[ -f ${_cp_path}/.debugging ]]; then
    [[ $VERB = 2 ]] && echo "  skip debugging work copy of branch [ $_br ]"
    return
  fi
  if [[ -f ${_cp_path}/.skipping ]]; then
    [[ $VERB = 2 ]] && echo "  skip unused branch [ $_br ]"
    return
  fi

  # clean up trash file from last time crash
  [[ -f .git/index.lock ]] && rm -f .git/index.lock

  # check whether need to init all files at first
  [[ -z `ls $_cp_path` ]] && rsync -a --delete --exclude .git . $_cp_path && echo "  copy files for [ $_br ]"

  _diff=`git diff --name-only $_br origin/$_br`

  if [[ -n $_diff ]]; then
    echo "  updating branch [ $_br ]"

    if [[ -f ${_cp_path}.docker ]]; then
      _docker_name=`cat ${_cp_path}.docker`
    else
      _docker_name='UNINITIALIZED'
    fi

    git checkout -q -B $_br origin/$_br
    rsync -a --delete --exclude .git . $_cp_path

    # restart docker instance
    if [[ $_docker_name != 'UNINITIALIZED' ]]; then
      docker restart $_docker_name
    fi
  else
    [[ $VERB = 2 ]] && echo "  no change of branch [ $_br ], skip"
  fi
}

# expect one argument "branch_name"
function fetch_and_check {
  _repo=$1

  cd $_repo

  [[ $VERB = 1 ]] && echo "  fetching repo ..."
  git fetch -q --all

  #for _br in `ls .git/refs/remotes/origin/`; do
  for _br in `git branch -r  | grep -v HEAD | sed -e 's/.*origin\///'`; do
    [[ $_br = 'HEAD' ]] && continue
    checkout_and_copy $_repo $_br
  done

  cd ..
}

# working dir
cd /work/git_repos

# loop like a daemon
while true; do
  for _repo in * ; do
    if [[ -d $_repo/.git ]]; then
      echo "checking git status for <$_repo>"
      fetch_and_check $_repo
    fi
  done

  sleep $SLEEP_TIME
done
