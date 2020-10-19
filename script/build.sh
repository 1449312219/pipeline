. _help.sh

projectName=$1
fullRepoName=$(kubectl get configmap owner-config -o jsonpath={.data.owner})/${projectName}
shift

namespace=$(formatToNamespace ${fullRepoName})-pipeline
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
printSplit
webhook="http://deployed-notify.${namespace}:8080"

function branchTypeEnvs() {
  branchType=$1
  shift

  # branchType env1 env2 env3 (流水线内的环境)
  ./branch-push-build.sh $branchType $@ | addNamespace ${namespace}

  # branchType manifestSuffix webhook env1 env2 env3
  ./branch-created-build.sh $branchType $manifestSuffix $webhook $@ | addNamespace ${namespace}
}


declare -A allEnvs
_IFS=$IFS
for config in $@; do
  branchType=${config%%:*}

  IFS=,; envs=(${config#*:}); IFS=${_IFS}
  branchTypeEnvs $branchType ${envs[@]}
  
  for env in ${envs[@]}; do
    allEnvs[$env]=$env
  done
done


# env1 env2 env3
./env-build.sh ${allEnvs[@]} | addNamespace ${namespace}


# basics
for file in $(findManifestPaths basics/); do
  cat $file | addNamespace ${namespace}
  printSplit
done


# gitea
./gitea-settings-build.sh ${projectName} ${manifestSuffix} ${namespace} 


# security
./security-build.sh ${fullRepoName} ${namespace} | addNamespace ${namespace}


# configmap
./resources.sh | addNamespace ${namespace}


# pv
cat templates/pv.yaml | PV_SUFFIX=${namespace} parsePlaceHolder 
printSplit


# conditions
cat ./test-cond.yaml | addNamespace ${namespace} 
