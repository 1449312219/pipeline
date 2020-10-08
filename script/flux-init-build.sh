set -e

. _help.sh

export BRANCH_TYPE=${1,,*}
shift

export MANIFEST_SUFFIX=$1
shift

export WEBHOOK=$1
shift

export ENV="$@"


# 选取需部署的环境
ENV_DIR=env
declare -a envs
for i in $ENV; do
  if grep "^deploy: true$" 1>/dev/null 2>&1 $ENV_DIR/$i/taskrun.yaml; then
    envs+=($i)
  fi
done
export ENV="${envs[@]}"


TEMP_DIR=templates/flux-init

# init
parsePlaceHolder $TEMP_DIR/pipeline.yaml

echo ---
echo

# trigger
parsePlaceHolder $TEMP_DIR/trigger.yaml

echo ---
echo
