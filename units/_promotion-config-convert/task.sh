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
  - name: repo-branch
    description: git仓库分支
  - name: expect-branch
    description: 期望git仓库分支, 仅为期望分支时生成pipeline
    default: master
  - name: deploy-success-webhook
    description: 部署成功通知地址, 用于需部署后测试的任务
    default: ""
  workspaces:
  - name: project
    description: 存储项目根目录, 将扫描其内配置
    readOnly: true
  steps:
  - name: build
    image: lachlanevenson/k8s-kubectl
    imagePullPolicy: IfNotPresent 
    script: |
      url=$(params.url)
      ca=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
      token=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
      namespace=$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace)

      kubectl="kubectl -s=$url --certificate-authority=$ca --token=$token"
      
      
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

execScript ${scriptDir}/convert.sh \''$(workspaces.project.path)'\' '~/output' \''$(params.deploy-success-webhook)'\'

echo '      $kubectl apply -f ~/output'
