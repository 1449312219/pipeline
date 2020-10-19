. _help.sh

export REPO_NAME=$1
shift

export REPO_MANIFEST_SUFFIX=$1
shift

namespace=$1
export WEBHOOKS=$(getWebHooks $namespace)
shift

ownerConfig=($(kubectl get configmap owner-config --no-headers -o custom-columns=http:data.git-server-http,owner:data.owner,type:data.type))

export GIT_SERVER=${ownerConfig[0]}
export REPO_OWNER=${ownerConfig[1]}
export REPO_OWNER_TYPE=${ownerConfig[2]}

export PIPELINERUN_ID=$(formatToNamespace $(mktemp -u XXXXXX))


TEMP_DIR=templates/gitea-settings

for file in $(findManifestPaths $TEMP_DIR); do
  parsePlaceHolder $file
  printSplit
done