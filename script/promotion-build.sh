. _help.sh

TEMP_DIR=templates/promotion
ENV_DIR=env

function showTaskRun() {
  local beforeEnv=$before
  local env=$now
  local nextEnv=$next

  export ENV=${env}
  parsePlaceHolder $TEMP_DIR/branch-push-env-taskrun.yaml | awk '{print "  "$0}'

  cat $ENV_DIR/$env/config.yaml | printYamlContent params | awk '{print "        "$0}'

  if test -n "${beforeEnv}"; then
    echo "        - name: before-env"
    echo "          value: ${beforeEnv}"

    if test -n "${nextEnv}"; then
    echo "        - name: notify"
    echo "          value: dddddddddddddddddd"
    fi

    echo "    runAfter:"
    echo "    - ${beforeEnv}"
  fi
}

function branchPushPromotion() { 
  export PURPOSE=${purposeForNs}

  # pipeline
  parsePlaceHolder $TEMP_DIR/branch-push-pipeline.yaml

  local envs=($@)
  before=
  while test $# -gt 0; do
    now=$1
    shift
    next=$1

    showTaskRun

    before=$now
  done
  printSplit

  # trigger
  parsePlaceHolder $TEMP_DIR/branch-push-trigger.yaml
  printSplit

  addWebHook http://el-${PURPOSE}-branch-push.'${NAMESPACE}':8080 ${branchType} push
  
  # purpose branchType manifestSuffix webhook env1 env2 env3
  ./env-alloc-helper.sh $purpose $branchType $manifestSuffix $webhook ${envs[@]}
}


purpose=$1
purposeForNs=$(formatToNamespace $purpose false)
shift

promotionType=$1
shift

#branchType=...;manifestSuffix=...;webhook=...;
args=$1
eval $args
shift


case $promotionType in
  branch-push) branchPushPromotion $@;
esac
