. _help.sh

TEMP_DIR=templates/promotion
ENV_DIR=env

function showTaskRun() {
  local beforeEnv=$before
  local env=$now
  local nextEnv=$next

  sed -e 's/${ENV}/'${env}/ \
      -e 's/${BEFORE_ENV}/'${beforeEnv:-'""'}/ \
  $TEMP_DIR/env-taskrun.yaml | awk '{print "  "$0}'

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


branchType=$1
branchTypeForNs=$(formatBranchType $branchType)
shift

# pipeline
cat $TEMP_DIR/pipeline.yaml | sed -e 's/${BRANCH_TYPE}/'${branchTypeForNs}/

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
cat $TEMP_DIR/trigger.yaml | sed -e 's/${BRANCH_TYPE}/'${branchTypeForNs}/
printSplit

addWebHook http://${branchTypeForNs}branch-push.'${NAMESPACE}':8080 ${branchType} push
