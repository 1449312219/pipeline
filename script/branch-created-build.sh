. _help.sh

export BRANCH_TYPE=$(formatBranchType $1)
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
  if test "$(cat $ENV_DIR/$i/config.yaml | printYamlContent deploy)" == "true"; then
    envs+=($i)
  fi
done
export ENV="${envs[@]}"

if test ${#envs[@]} -le 0; then
  exit
fi


TEMP_DIR=templates/branch-created

# pipeline
parsePlaceHolder $TEMP_DIR/pipeline.yaml
printSplit

# trigger
parsePlaceHolder $TEMP_DIR/trigger.yaml
printSplit
