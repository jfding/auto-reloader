#!/bin/bash

## global settings
[[ -z $VERB ]] && VERB=1
[[ -z $TIMEOUT ]] && TIMEOUT=600

# if VERB=0, keep super silent
[[ $VERB = 0 ]] && exec>/dev/null

BR_WHITELIST="main master dev test alpha"

[[ -z $DIR_REPOS ]] && DIR_REPOS=/work/git_repos
[[ -z $DIR_COPIES ]] && DIR_COPIES=/work/copies
[[ -z $CI_LOCK ]] && CI_LOCK=/tmp/.ci-lock

function _logging {
    local _level=$1; shift
    local _datetime=`/bin/date '+%m-%d %H:%M:%S>'`
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

function _handle_post {
    # post scripts
    local _post_path=$1
    local _cp_path=$2

    if [[ -f ${_post_path} ]]; then
      say "..running post scripts [ $_post_path ]"
      cd ${_cp_path}
      bash "${_post_path}"
      cd - > /dev/null
    fi
}

function _handle_docker {
    # restart docker instance
    local _docker_path=$1

    if [[ -f ${_docker_path} ]]; then
      _docker_name=`cat ${_docker_path}`

      say "..restarting docker [ $_docker_name ]"
      docker restart $_docker_name > /dev/null
      unset _docker_name
    fi
}

# expect one argument "tag_name"
function checkout_and_copy_tag {
  local _repo=$1
  local _tag=$2

  _cp_path="${DIR_COPIES}/${_repo}.prod.${_tag}"
  _post_path="${DIR_COPIES}/${_repo}.prod.post"
  _docker_path="${DIR_COPIES}/${_repo}.prod.docker"

  # if path exists, skip
  [[ -d $_cp_path ]] && return

  # start to work on this br
  git checkout -q -f $_tag

  # check whether need to init all files at first
  mkdir -p $_cp_path && rsync -a --delete --exclude .git . $_cp_path && say "..copy files for new RELEASE [ $_tag ]"

  # post scripts
  _handle_post ${_post_path} ${_cp_path}

  # restart docker instance
  _handle_docker ${_docker_path}
}

# expect one argument "branch_name"
function checkout_and_copy_br {
  local _repo=$1
  local _br=$2

  local _cp_path="${DIR_COPIES}/${_repo}.${_br}"
  local _post_path="${_cp_path}.post"
  local _docker_path="${_cp_path}.docker"

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
  [[ -z `/bin/ls $_cp_path` ]] && rsync -a --delete --exclude .git . $_cp_path && say "..copy files for [ $_br ]"

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
      _handle_post ${_post_path} ${_cp_path}

      # restart docker instance
      _handle_docker ${_docker_path}

      else
    verbose "..no change of branch [ $_br ], skip"
  fi
}

# expect one argument "branch_name"
function fetch_and_check {
  local _repo=$1
  local _br
  local _release
  local _bp

  cd $_repo

  # clean up trash file from last time crash
  [[ -f .git/index.lock ]] && rm -f .git/index.lock

  say "..fetching repo ..."
  _timeout git fetch -q --all --tags

  #for _br in `ls .git/refs/remotes/origin/`; do
  for _br in `git branch -r  | grep -v HEAD | sed -e 's/.*origin\///'`; do
    [[ $_br = 'HEAD' ]] && continue
    (echo $_br | grep -q '/') && continue

    # check branch whitelist || repo dir exists already
    if [[ $BR_WHITELIST =~ (^|[[:space:]])$_br($|[[:space:]]) ]] || [[ -d "${DIR_COPIES}/${_repo}.${_br}" ]]; then
        checkout_and_copy_br $_repo $_br

        # heart beat
        touch "${DIR_COPIES}/${_repo}.${_br}/.living"
    fi
  done

  for _release in `git tag -l  | grep '^v[0-9.]\+$' `; do
    checkout_and_copy_tag $_repo $_release

    # heart beat
    touch "${DIR_COPIES}/${_repo}.prod.${_release}/.living"
  done

  # clean up deprected dirs in "work/copies"
  for _bp in `/bin/ls -d ${DIR_COPIES}/${_repo}.*/`; do

      (echo $_bp | grep -q to-be-removed) && continue

      _bp=${_bp%/}

      if [ -f $_bp/.living ]; then
        rm -f "$_bp/.living"
      else
        say "..cleaning up deprecated dir: $_bp"
        #rm -rf $_bp
        #rm -f ${_bp}.*
        mv $_bp $_bp.to-be-removed
      fi
  done

  cd - > /dev/null
}

function main {
  # working dir
  [[ -d $DIR_REPOS ]] || mkdir -p $DIR_REPOS

  # loop like a daemon
  while true; do
    # Acquire file-lock
    while [[ -f $CI_LOCK ]]; do sleep 1; done
    touch $CI_LOCK

    cd $DIR_REPOS
    for _repo in * ; do
      if [[ -d $_repo/.git ]]; then
        mustsay "checking git status for <$_repo>"
        fetch_and_check $_repo
      fi
    done

    # Release lock
    rm -f $CI_LOCK

    [[ -z $SLEEP_TIME ]] && exit 0

    say "waiting for next check ..."
    sleep $SLEEP_TIME
  done
}

## __main__ start here
main
