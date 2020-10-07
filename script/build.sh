#./pipeline-build.sh $@
#./init-build.sh $@
#./pipeline-build.sh Release- ci

projectName=$1
shift

namespace=${projectName,,*}-pipeline

manifestSuffix="-manifest"

# webhook
cat templates/deployed-notify/trigger.yaml | addNamespace
webhook="http://deployed-notify.${namespace}:8080"

function addNamespace() {
  sed -e "/^metadata:/a\  namespace: ${namespace}" -e "/namespace/d"
}

function branchTypeEnvs() {
  branchType=$1
  shift

  # branchType env1 env2 env3 (流水线内的环境)
  ./branch-push-build.sh $branchType $@ | addNamespace

  # branchType manifestSuffix webhook env1 env2 env3
  ./flux-init-build.sh $branchType manifestSuffix webhook $@ | addNamespace
}


_IFS=$IFS
for config in $@; do
  branchType=${config%%:*}

  IFS=,; envs=(${config#*:}); IFS=${_IFS}
  branchTypeEnvs $branchType ${envs[@]}
done
