. _help.sh

export REPO_FULL_NAME=$1
shift

namespace=$1
export WEBHOOKS=$(getWebHooks $namespace)
shift

export GIT_SERVER=$(kubectl get configmap owner-config -o jsonpath={.data.git-server-http})

export PIPELINERUN_ID=$(formatToNamespace $(mktemp -u XXXXXX))


TEMP_DIR=templates/gitea-settings

for file in $(findManifestPaths $TEMP_DIR); do
  parsePlaceHolder $file
  printSplit
done
