set -e

scriptDir="script"
check="true"

echo 'apiVersion: tekton.dev/v1beta1
kind: ClusterTask
metadata:
  name: promotion-pipeline-factory
spec:
  params:
  - name: url
    default: https://kubernetes.default
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
      
      mkdir ~/script -p && cd ~/script'

function doPrintFile() {
  local filePath=$1
  local newFilePath=$2
  echo "cat <<EOFEOFEOFEOF > ${newFilePath}
$(sed -e 's/\\/\\\\/g' -e 's/\$/\\$/g'  ${filePath})
EOFEOFEOFEOF"
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
function canExec() {
  local filePath=$1
  local fileName=$(basename ${filePath})
  echo "chmod u+x ${fileName}" \
  | awk '{print "        "$0}'
}

for file in ${scriptDir}/*.yaml; do
  printFile $file
done

printFile ${scriptDir}/promotion.sh
canExec ${scriptDir}/promotion.sh