. _help.sh

purpose=$1
purposeForNs=$(formatToNamespace $purpose false)
export PURPOSE=$purposeForNs
shift

branchType=$1
branchTypeForNs=$(formatBranchType $branchType)
export BRANCH_TYPE=$branchTypeForNs
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


TEMP_DIR=templates/env-alloc

# pipeline
parsePlaceHolder $TEMP_DIR/pipeline.yaml
printSplit

# trigger
parsePlaceHolder $TEMP_DIR/trigger.yaml
printSplit

# webhook
addWebHook http://${PURPOSE}-branch-created.'${NAMESPACE}':8080 ${branchType} create
