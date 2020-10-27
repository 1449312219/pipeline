# projectName purpose:envs:promotionType:args ...

. _help.sh


projectName=$1
fullRepoName=$(kubectl get configmap owner-config -o jsonpath={.data.owner})/${projectName}
shift


# namespace
namespace=$(formatToNamespace ${fullRepoName})-pipeline
echo "apiVersion: v1
kind: Namespace
metadata:
  name: ${namespace}
"
printSplit


manifestSuffix="-manifest"


# promotions
declare -A allEnvs
for config in $@; do
  # purpose:envs:promotionType:args
  parseArg $config

  # purpose promotionType args(branchType=...) env1 env2 env3 (流水线内的环境)
  ./promotion-build.sh $purpose $promotionType \
  "namespace=${namespace};manifestSuffix=$manifestSuffix;$args" ${envs[@]} \
  | addNamespace ${namespace}

  for env in ${envs[@]}; do
    allEnvs[$env]=$env
  done
done

# envs
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
PV_SUFFIX=${namespace} parsePlaceHolder templates/pv.yaml
printSplit


# conditions
cat ./test-cond.yaml | addNamespace ${namespace} 
