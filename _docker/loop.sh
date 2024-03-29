#!/bin/bash

[[ -z $VERB ]] && VERB=1
[[ -z $SLEEP_TIME ]] && SLEEP_TIME=60
[[ -z $TIMEOUT ]] && TIMEOUT=600

# if VERB=0, keep super silent
[[ $VERB = 0 ]] && exec>/dev/null

DIR_REPOS=/work/git_repos
DIR_COPIES=/work/copies

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

# expect one argument "tag_name"
function checkout_and_copy_tag {
  _repo=$1
  _tag=$2

  _cp_path="${DIR_COPIES}/${_repo}.prod.${_tag}"

  # if path exists, skip
  [[ -d $_cp_path ]] && return

  # start to work on this br
  git checkout -q -f $_tag

  # check whether need to init all files at first
  mkdir -p $_cp_path && rsync -a --delete --exclude .git . $_cp_path && say "..copy files for new RELEASE [ $_tag ]"
}

# expect one argument "branch_name"
function checkout_and_copy_br {
  _repo=$1
  _br=$2

  _cp_path="${DIR_COPIES}/${_repo}.${_br}"

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

  # check whether need to init all files at first
  [[ -z `ls $_cp_path` ]] && rsync -a --delete --exclude .git . $_cp_path && say "..copy files for [ $_br ]"

  _diff=`git diff --name-only $_br origin/$_br`

  # add a debug trigger
  if [[ -f ${_cp_path}/.trigger ]]; then
    rm -f ${_cp_path}/.trigger # burn after reading

    if [[ -z $_diff ]]; then
      say "..having a debug try"
      _diff="debugging"
    fi
  fi

  if [[ -n $_diff ]]; then
      say "..UPDATING branch [ $_br ]"
      git checkout -q -B $_br origin/$_br || {
          mustsay "..failed git checkout and skip"
          return
      }
      if [[ -f ${_cp_path}/.no-cleanup ]]; then
        # if ./no-cleanup existing, do not clean up cached or built files
        rsync -a --exclude .git . $_cp_path
      else
        rsync -a --delete --exclude .git . $_cp_path
      fi

    # post scripts
    if [[ -f ${_cp_path}.post ]]; then
      say "..running post scripts for branch [ $_br ]"
      cd ${_cp_path}
      bash "${_cp_path}.post"
      cd -
    fi

    # restart docker instance
    if [[ -f ${_cp_path}.docker ]]; then
      _docker_name=`cat ${_cp_path}.docker`

      say "..restarting docker [ $_docker_name ]"
      docker restart $_docker_name > /dev/null
      unset _docker_name
    else
      verbose "..no docker configered for changed branch [ $_br ], skip restart docker"
    fi

  else
    verbose "..no change of branch [ $_br ], skip"
  fi
}

# expect one argument "branch_name"
function fetch_and_check {
  _repo=$1

  cd $_repo

  # clean up trash file from last time crash
  [[ -f .git/index.lock ]] && rm -f .git/index.lock

  say "..fetching repo ..."
  _timeout git fetch -q --all --tags

  #for _br in `ls .git/refs/remotes/origin/`; do
  for _br in `git branch -r  | grep -v HEAD | sed -e 's/.*origin\///'`; do
    [[ $_br = 'HEAD' ]] && continue
    checkout_and_copy_br $_repo $_br
  done

  for _release in `git tag -l  | grep '^v[0-9.]\+$' `; do
    checkout_and_copy_tag $_repo $_release
  done

  cd ..
}

## __main__ start here

# working dir
[[ -d $DIR_REPOS ]] || mkdir -p $DIR_REPOS
cd $DIR_REPOS

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
