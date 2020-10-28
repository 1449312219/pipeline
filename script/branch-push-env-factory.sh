. _help.sh

function manifest() {
  purposeForNs=$1
  export PURPOSE=$purposeForNs
  shift
  
  namespace=$1
  shift
  
  branchType=$1
  shift
  
  export MANIFEST_SUFFIX=$1
  shift
  
  export WEBHOOK=$1
  shift
  
  export ENV="$@"
  
  
  ENV_DIR=env
  
  # 选取需部署的环境
  declare -a envs
  for i in $ENV; do
    if test "$(cat $ENV_DIR/$i/config.yaml | printYamlContent deploy)" == "true"; then
      envs+=($i)
    fi
  done
  export ENV="${envs[@]}"
  if test ${#envs[@]} -le 0; then
    exit
  fi
    
  # 是否需要交互
  export NEED_INTERACTION=false
  for i in $ENV; do
    if test "$(cat $ENV_DIR/$i/config.yaml | printYamlContent interaction)" == "true"; then
      export NEED_INTERACTION=true
      break
    fi
  done
  
  
  TEMP_DIR=templates/env-factory
  
  # pipeline
  parsePlaceHolder $TEMP_DIR/pipeline.yaml
  printSplit
  
  # trigger
  parsePlaceHolder $TEMP_DIR/branch-created-trigger.yaml
  printSplit
  
  # webhook
  addWebHook http://el-${PURPOSE}-branch-created.${namespace}:8080 ${branchType} create
}

function envVersionPlaceHolderValue() {
  echo "'\$(params.repo-branch)'"
}

subCmd=$1
shift

case $subCmd in
  manifest )  manifest $@ ;;
  envVersion ) envVersionPlaceHolderValue ;;
esac