#!/usr/bin/env bash

function run_cmd {
    "$@"
    RESULT=$?
    if (( $RESULT != 0 )); then
        echo "Error while running '$@'"
        kill -INT $$
    fi
}

install_cmssw() {
  local this_file="$( [ ! -z "$ZSH_VERSION" ] && echo "${(%):-%x}" || echo "${BASH_SOURCE[0]}" )"
  local this_dir="$( cd "$( dirname "$this_file" )" && pwd )"

  export SCRAM_ARCH=$1
  local CMSSW_VER=$2
  local os_version=$3
  if ! [ -f "$this_dir/soft/CentOS$os_version/$CMSSW_VER/.installed" ]; then
    run_cmd mkdir -p "$this_dir/soft/CentOS$os_version"
    run_cmd cd "$this_dir/soft/CentOS$os_version"
    if [ -d $CMSSW_VER ]; then
      echo "Removing incomplete $CMSSW_VER installation..."
      run_cmd rm -rf $CMSSW_VER
    fi
    echo "Creating $CMSSW_VER area for CentOS$os_version in $PWD ..."
    run_cmd scramv1 project CMSSW $CMSSW_VER
    run_cmd cd $CMSSW_VER/src
    run_cmd eval `scramv1 runtime -sh`
    run_cmd scram b -j8
    run_cmd cd "$this_dir"
    touch "$this_dir/soft/CentOS$os_version/$CMSSW_VER/.installed"
  fi
}

action() {
  # determine the directory of this file
  local this_file="$( [ ! -z "$ZSH_VERSION" ] && echo "${(%):-%x}" || echo "${BASH_SOURCE[0]}" )"
  local this_dir="$( cd "$( dirname "$this_file" )" && pwd )"

  export PYTHONPATH="$this_dir:$PYTHONPATH"
  export LAW_HOME="$this_dir/.law"
  export LAW_CONFIG_FILE="$this_dir/config/law.cfg"

  export ANALYSIS_PATH="$this_dir"
  export ANALYSIS_DATA_PATH="$ANALYSIS_PATH/data"
  export X509_USER_PROXY="$ANALYSIS_DATA_PATH/voms.proxy"
  export PRODCARD_STORAGE="/eos/home-k/kandroso/cms-hnl/prodcards"
  export GRIDPACK_STORAGE="/eos/home-k/kandroso/cms-hnl/gridpacks"

  export PATH=$PATH:$HOME/.local/bin:$ANALYSIS_PATH/scripts

  local os_version=$(cat /etc/os-release | grep VERSION_ID | sed -E 's/VERSION_ID="([0-9]+)"/\1/')
  if [ $os_version = "7" ]; then
    /usr/bin/env bash "$this_file" install_cmssw slc7_amd64_gcc700 CMSSW_10_6_29 7
    /usr/bin/env bash "$this_file" install_cmssw slc7_amd64_gcc10 CMSSW_12_4_8 7
  elif [ $os_version = "8" ]; then
    /usr/bin/env bash "$this_file" install_cmssw el8_amd64_gcc10 CMSSW_12_4_8 8
  else
    echo "Unsupported OS version $os_version"
    kill -INT $$
  fi

  source /cvmfs/sft.cern.ch/lcg/views/setupViews.sh LCG_101 x86_64-centos7-gcc8-opt
  source /afs/cern.ch/user/m/mrieger/public/law_sw/setup.sh

  source "$( law completion )" ""
}

if [ "X$1" = "Xinstall_cmssw" ]; then
  install_cmssw "${@:2}"
else
  action
fi
