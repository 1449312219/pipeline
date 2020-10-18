. _help.sh

export REPO_FULL_NAME=$1
shift

namespace=$1
export WEBHOOKS=$(getWebHooks $namespace)
shift

export GIT_SERVER=$(kubectl get configmap owner-config -o jsonpath={.data.git-server-http})

export PIPELINERUN_ID=$(mktemp -u XXXXXX)

TEMP_DIR=templates

parsePlaceHolder $TEMP_DIR/gitea-settings.yaml
printSplit
