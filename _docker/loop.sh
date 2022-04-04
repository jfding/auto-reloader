#!/bin/bash

[[ -z $VERB ]] && VERB=1
[[ -z $SLEEP_TIME ]] && SLEEP_TIME=60
[[ -z $TIMEOUT ]] && TIMEOUT=600

# if VERB=0, keep super silent
[[ $VERB = 0 ]] && exec>/dev/null

function _logging {
    _level=$1; shift
    _datetime=`/bin/date '+%m-%d %H:%M:%S>'`
    if [ $_level -le $VERB ]; then
        echo $_datetime $*
    fi
}
function mustsay {
    _logging 0 $*
}
function say {
    _logging 1 $*
}
function verbose {
    _logging 2 $*
}

function _timeout {
    if which timeout &>/dev/null; then
        timeout $TIMEOUT $*
    else
        $*
    fi
}

# expect one argument "branch_name"
function checkout_and_copy {
  _repo=$1
  _br=$2

  _cp_path="../../copies/${_repo}.${_br}"

  # if no copy of this br, just mkdir with a skipping flag file
  # (do not actual copying files, unless admin specify it explicitly)
  [[ ! -d $_cp_path ]] && mkdir -p $_cp_path && touch $_cp_path/.skipping && say "..init dir of [ $_br ]"

  # checking flags
  if [[ -f ${_cp_path}/.debugging ]]; then
    verbose "..skip debugging work copy of branch [ $_br ]"
    return
  fi
  if [[ -f ${_cp_path}/.skipping ]]; then
    verbose "..skip unused branch [ $_br ]"
    return
  fi

  # start to work on this br
  git checkout -q -f $_br

  # clean up trash file from last time crash
  [[ -f .git/index.lock ]] && rm -f .git/index.lock

  # check whether need to init all files at first
  [[ -z `ls $_cp_path` ]] && rsync -a --delete --exclude .git . $_cp_path && say "..copy files for [ $_br ]"

  _diff=`git diff --name-only $_br origin/$_br`
  if [[ -n $_diff ]]; then
    if [[ -f ${_cp_path}.docker ]]; then
      _docker_name=`cat ${_cp_path}.docker`

      say "..updating branch [ $_br ]"
      git checkout -q -B $_br origin/$_br || {
          mustsay "..failed git checkout and skip"
          return
      }
      rsync -a --delete --exclude .git . $_cp_path

      say "..restarting docker [ $_docker_name ]"
      docker restart $_docker_name > /dev/null
      unset _docker_name

    else
      verbose "..no docker configered for changed branch [ $_br ], skip"
    fi

  else
    verbose "..no change of branch [ $_br ], skip"
  fi
}

# expect one argument "branch_name"
function fetch_and_check {
  _repo=$1

  cd $_repo

  say "..fetching repo ..."
  _timeout git fetch -q --all

  #for _br in `ls .git/refs/remotes/origin/`; do
  for _br in `git branch -r  | grep -v HEAD | sed -e 's/.*origin\///'`; do
    [[ $_br = 'HEAD' ]] && continue
    checkout_and_copy $_repo $_br
  done

  cd ..
}

## __main__ start here

# working dir
[[ -d /work/git_repos ]] || mkdir -p /work/git_repos
cd /work/git_repos

# loop like a daemon
while true; do
  for _repo in * ; do
    if [[ -d $_repo/.git ]]; then
      mustsay "checking git status for <$_repo>"
      fetch_and_check $_repo
    fi
  done

  say "waiting for next check ..."
  sleep $SLEEP_TIME
done
