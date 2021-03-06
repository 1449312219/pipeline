set -ex

scriptDir=$1
check=${2:-true}

echo 'apiVersion: tekton.dev/v1beta1
kind: ClusterTask
metadata:
  name: promotion-config-convert
spec:
  params:
  - name: url
    default: https://kubernetes.default
  - name: scan-path
    description: 扫描指定目录内配置
    default: ""
  - name: repo-branch
    description: git仓库分支
  - name: expect-branch
    description: 期望git仓库分支, 仅为期望分支时生成pipeline
    default: master
  workspaces:
  - name: resources
    description: 存储资源, 将扫描其内配置
    readOnly: true
  volumes:
  - name: pipeline-config
    configmap:
      name: config-promotion-pipeline
  steps:
  - name: build
    image: inner-docker-registry:5000/lachlanevenson/k8s-kubectl
    imagePullPolicy: IfNotPresent
    volumeMounts:
    - name: pipeline-config
      mountPath: /volumes/pipeline-config
    script: |
      url=$(params.url)
      ca=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
      token=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
      namespace=$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace)

      kubectl="kubectl -s=$url --certificate-authority=$ca --token=$token -n $namespace"
      
      
      if test "$(params.repo-branch)" != "$(params.expect-branch)"; then
        exit
      fi
      
      mkdir ~/script -p && cd ~/script'

function doPrintFile() {
  local filePath=$1
  local newFilePath=$2
  local placeholder=$(mktemp -u __XXXXXX__)
  echo "cat <<EOFEOFEOFEOF > ${newFilePath}
$(sed -e 's/\\/\\\\/g' -e "s/\\$/${placeholder}/g"  ${filePath})
EOFEOFEOFEOF"
  echo "sed -i '/${placeholder}/s/${placeholder}/\$/g' ${newFilePath}"
}
function printFile() {
  local filePath=$1
  local fileName=$(basename ${filePath})
  
  if test "${check}" == "true"; then
    local checkSh=.temp.check-sh-$(mktemp -u XXXXXX)
    local checkFile=.temp.check-${fileName}-$(mktemp -u XXXXXX)
    
    doPrintFile ${filePath} ${checkFile} > ${checkSh}
    
    sh ${checkSh}
    
    diff ${checkFile} ${filePath} >/dev/null
    rm ${checkSh} ${checkFile} -f
  fi
  
  doPrintFile ${filePath} ${fileName} | awk '{print "      "$0}'
}
function execScript() {
  local filePath=$1
  shift
  local fileName=$(basename ${filePath})
  echo "sh ${fileName}" "$@" \
  | awk '{print "      "$0}'
}

for file in ${scriptDir}/*.yaml; do
  printFile $file
done

printFile ${scriptDir}/convert.sh

scanPath='$(workspaces.resources.path)/$(params.scan-path)'
execScript ${scriptDir}/convert.sh "'${scanPath}'" '~/output' '/volumes/pipeline-config'

echo '      $kubectl apply -f ~/output'
