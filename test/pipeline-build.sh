set -e

function showTaskRun() {
  local beforeEnv=$before
  local env=$now
  local nextEnv=$next

  sed -e 's/${ENV}/'${env}/ \
      -e 's/${BEFORE-ENV}/'${beforeEnv:-'""'}/ \
  env/taskrun-template.yaml | awk '{print "  "$0}'

  cat env/$env/taskrun.yaml | awk 'NR!=1{print "        "$0}'

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
shift

cat env/pipeline-template.yaml | sed -e 's/${BRANCH-TYPE}/'${branchType}/

before=
while test $# -gt 0; do
  now=$1
  shift
  next=$1

  showTaskRun

  before=$now
done

echo ---


