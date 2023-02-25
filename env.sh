#!/usr/bin/env bash

function run_cmd {
    "$@"
    RESULT=$?
    if (( $RESULT != 0 )); then
        echo "Error while running '$@'"
        kill -INT $$
    fi
}

do_install_cmssw() {
  local this_file="$( [ ! -z "$ZSH_VERSION" ] && echo "${(%):-%x}" || echo "${BASH_SOURCE[0]}" )"
  local this_dir="$( cd "$( dirname "$this_file" )" && pwd )"

  export SCRAM_ARCH=$1
  local CMSSW_VER=$2
  local os_version=$3
  local inst_type=$4
  if ! [ -f "$this_dir/soft/CentOS$os_version/$CMSSW_VER/.installed" ]; then
    run_cmd mkdir -p "$this_dir/soft/CentOS$os_version"
    run_cmd cd "$this_dir/soft/CentOS$os_version"
    run_cmd source /cvmfs/cms.cern.ch/cmsset_default.sh
    if [ -d $CMSSW_VER ]; then
      echo "Removing incomplete $CMSSW_VER installation..."
      run_cmd rm -rf $CMSSW_VER
    fi
    echo "Creating $CMSSW_VER area for CentOS$os_version in $PWD ..."
    run_cmd scramv1 project CMSSW $CMSSW_VER
    run_cmd cd $CMSSW_VER/src
    run_cmd eval `scramv1 runtime -sh`
    if [ "$inst_type" = "nano_prod" ]; then
      run_cmd git cms-init
      run_cmd git cms-merge-topic cms-hnl:HNL_base_12_4_X
      # run_cmd git remote add cms-l1t-offline git@github.com:cms-l1t-offline/cmssw.git
      # run_cmd git fetch cms-l1t-offline l1t-integration-CMSSW_12_4_0
      # run_cmd git cms-merge-topic -u cms-l1t-offline:l1t-integration-v134
      # run_cmd git clone https://github.com/cms-l1t-offline/L1Trigger-L1TCalorimeter.git L1Trigger/L1TCalorimeter/data
      run_cmd git cms-checkdeps -A -a
      run_cmd mkdir -p "HNLTauPrompt/NanoProd"
      run_cmd ln -s "$this_dir/HNLTauPrompt/NanoProd" "HNLTauPrompt/NanoProd/python"
      run_cmd ln -s "$this_dir/HNL" "HNL"
    fi
    run_cmd mkdir -p "Configuration/GenProduction/python"
    run_cmd mkdir -p "$this_dir/soft/CentOS$os_version/$CMSSW_VER/bin_ext"
    run_cmd ln -s $(which python3) "$this_dir/soft/CentOS$os_version/$CMSSW_VER/bin_ext/python"
    run_cmd scram b -j8
    run_cmd cd "$this_dir"
    run_cmd touch "$this_dir/soft/CentOS$os_version/$CMSSW_VER/.installed"
  fi
}

install_cmssw() {
  local this_file="$( [ ! -z "$ZSH_VERSION" ] && echo "${(%):-%x}" || echo "${BASH_SOURCE[0]}" )"
  local this_dir="$( cd "$( dirname "$this_file" )" && pwd )"
  local scram_arch=$1
  local cmssw_version=$2
  local os_version=$3
  local inst_type=$4
  if [[ $os_version < 8 ]] ; then
    local env_cmd=cmssw-cc$os_version
  else
    local env_cmd=cmssw-el$os_version
  fi
  if ! [ -f "$this_dir/soft/CentOS$os_version/$CMSSW_VER/.installed" ]; then
    run_cmd $env_cmd --command-to-run /usr/bin/env -i HOME=$HOME bash "$this_file" install_cmssw $scram_arch $cmssw_version $os_version $inst_type
  fi
}

action() {
  # determine the directory of this file
  local mode=$1
  local this_file="$( [ ! -z "$ZSH_VERSION" ] && echo "${(%):-%x}" || echo "${BASH_SOURCE[0]}" )"
  local this_dir="$( cd "$( dirname "$this_file" )" && pwd )"

  export PYTHONPATH="$this_dir:$PYTHONPATH"
  export LAW_HOME="$this_dir/.law"
  export LAW_CONFIG_FILE="$this_dir/config/law.cfg"

  export ANALYSIS_PATH="$this_dir"
  export ANALYSIS_DATA_PATH="$ANALYSIS_PATH/data"
  export X509_USER_PROXY="$ANALYSIS_DATA_PATH/voms.proxy"
  mkdir -p "$ANALYSIS_DATA_PATH"

  export PATH=$PATH:$HOME/.local/bin:$ANALYSIS_PATH/scripts

  run_cmd install_cmssw slc7_amd64_gcc530 CMSSW_8_0_36_UL_patch1 7 hlt
  run_cmd install_cmssw slc7_amd64_gcc630 CMSSW_9_4_16_UL 7 hlt
  run_cmd install_cmssw slc7_amd64_gcc700 CMSSW_10_2_20_UL 7 hlt
  run_cmd install_cmssw slc7_amd64_gcc700 CMSSW_10_6_29 7 gen
  run_cmd install_cmssw slc7_amd64_gcc10 CMSSW_12_4_10 7 nano_prod
  run_cmd install_cmssw el8_amd64_gcc10 CMSSW_12_4_10 8 nano_prod

  local os_version=$(cat /etc/os-release | grep VERSION_ID | sed -E 's/VERSION_ID="([0-9]+)"/\1/')
  local default_cmssw_ver=CMSSW_12_4_10
  export DEFAULT_CMSSW_BASE="$ANALYSIS_PATH/soft/CentOS$os_version/$default_cmssw_ver"

  if [ ! -z $ZSH_VERSION ]; then
    autoload bashcompinit
    bashcompinit
  fi
  source /cvmfs/sft.cern.ch/lcg/views/setupViews.sh LCG_102 x86_64-centos${os_version}-gcc11-opt
  source /afs/cern.ch/user/m/mrieger/public/law_sw/setup.sh

  source "$( law completion )" ""
  alias cmsEnv="env -i HOME=$HOME ANALYSIS_PATH=$ANALYSIS_PATH X509_USER_PROXY=$X509_USER_PROXY DEFAULT_CMSSW_BASE=$DEFAULT_CMSSW_BASE $ANALYSIS_PATH/RunKit/cmsEnv.sh"
}

if [ "X$1" = "Xinstall_cmssw" ]; then
  do_install_cmssw "${@:2}"
else
  action "$@"
fi
