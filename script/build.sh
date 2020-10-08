#./pipeline-build.sh $@
#./init-build.sh $@
#./pipeline-build.sh Release- ci

. _help.sh

projectName=$1
shift

namespace=${projectName,,*}-pipeline
cat <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ${namespace}
---

EOF

manifestSuffix="-manifest"

# webhook
cat templates/deployed-notify/trigger.yaml | addNamespace ${namespace}
webhook="http://deployed-notify.${namespace}:8080"

function branchTypeEnvs() {
  branchType=$1
  shift

  # branchType env1 env2 env3 (流水线内的环境)
  ./branch-push-build.sh $branchType $@ | addNamespace ${namespace}

  # branchType manifestSuffix webhook env1 env2 env3
  ./flux-init-build.sh $branchType manifestSuffix webhook $@ | addNamespace ${namespace}
}


_IFS=$IFS
for config in $@; do
  branchType=${config%%:*}

  IFS=,; envs=(${config#*:}); IFS=${_IFS}
  branchTypeEnvs $branchType ${envs[@]}
done


# security
./security-build.sh | addNamespace ${namespace}

