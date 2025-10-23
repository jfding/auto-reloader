#!/bin/bash

# script to switch the source code symlink in prod service dir to latest version's path

function _version_less_than {
  if [[ -z $1 ]] || [[ -z $2 ]]; then
    return 100
  fi
  if [[ $1 == $2 ]]; then
    return 2
  fi

  python3 -c "
import sys
v1, v2 = sys.argv[1].lstrip('v'), sys.argv[2].lstrip('v')
n1 = [int(x) for x in v1.split('.')]
n2 = [int(x) for x in v2.split('.')]
max_len = max(len(n1), len(n2))
n1.extend([0] * (max_len - len(n1)))
n2.extend([0] * (max_len - len(n2)))
sys.exit(0 if n1 < n2 else (1 if n1 > n2 else 2))
" $1 $2
}

function _get_cur_version {
    CODE_SYMLINK="${1}/code"

    if [[ ! -L $CODE_SYMLINK ]]; then
        echo "Error: CODE_SYMLINK does not exist" >/dev/stderr
        return 1
    fi

    readlink $CODE_SYMLINK | sed 's/.*.prod.//'
}

function _get_latest_version {
    CODE_SYMLINK="${1}/code"

    CUR_VERSION_FULLPATH=$(readlink $CODE_SYMLINK)
    CUR_VERSION=$(_get_cur_version $1)
    LATEST_VER_PATH=$(echo $CUR_VERSION_FULLPATH | sed "s/$CUR_VERSION$/latest/")
    
    if [[ ! -L $LATEST_VER_PATH ]]; then
        echo "Error: latest symlink does not exist for this project" >/dev/stderr
        return 1
    fi

    readlink $LATEST_VER_PATH | sed 's/.*.prod.//'
}

function _update_latest_version {
    SERVICE_DIR=$1
    CUR_VERSION=$2
    LATEST_VERSION=$3

    CUR_VERSION_FULLPATH=$(readlink $SERVICE_DIR/code)
    LATEST_VERSION_FULLPATH=$(echo $CUR_VERSION_FULLPATH | sed "s/$CUR_VERSION/$LATEST_VERSION/")

    echo "Switching $CUR_VERSION_FULLPATH to $LATEST_VERSION_FULLPATH"

    cd $SERVICE_DIR
    rm -f ./code
    ln -sf $LATEST_VERSION_FULLPATH ./code
    cd - >/dev/null
}

function _restart_service {
    SERVICE_DIR=$1
    
    # detect docker-compose command or docker comopse subcomand
    which docker 2>/dev/null || {
        echo "Error: docker command not found" >/dev/stderr
        return 1
    }
    (docker compose >/dev/null 2>&1) && {
        _DC_CMD='docker compose'
    } || {
        _DC_CMD='docker-compose'
    }
    
    echo "Restarting service: $(basename $SERVICE_DIR)"
    cd $SERVICE_DIR
    $_DC_CMD restart
}

## __main__ start here
if [[ -z $1 ]]; then
  echo "Usage: $0 <service-workdir> [update]"
  exit 1
fi

SERVICE_DIR=$1
if [[ ! -d $SERVICE_DIR ]]; then
    echo "Error: $SERVICE_DIR does not exist" >/dev/stderr
    exit 1
fi

CUR_VERSION=$(_get_cur_version $SERVICE_DIR) || exit 1
if [[ -z $CUR_VERSION ]]; then
    echo "Error: get not parse out CUR_VERSION" >/dev/stderr
    exit 1
fi
if [[ $CUR_VERSION == "latest" ]]; then
    echo "Warning: CUR_VERSION is latest, skipping..." >/dev/stderr
    exit 0
fi

LATEST_VERSION=$(_get_latest_version $SERVICE_DIR) || exit 1

if [[ $2 == "update" ]]; then
    if ! _version_less_than $CUR_VERSION $LATEST_VERSION; then
        echo "Warning: LATEST_VERSION:$LATEST_VERSION is not greater than CUR_VERSION:$CUR_VERSION"
        echo "Skipping..."
        exit 0
    fi

    _update_latest_version $SERVICE_DIR $CUR_VERSION $LATEST_VERSION
    _restart_service $SERVICE_DIR
else
    echo "Current version: $CUR_VERSION"
    echo "Latest version: $LATEST_VERSION"
fi