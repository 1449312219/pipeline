PROMOTION_PIPELINE_HEADER_TEMPLATE="promotion-pipeline-header-template.yaml"
AUTO_TEST_TASK_TEMPLATE="auto-test-task-template.yaml"
MANUAL_TEST_TASK_TEMPLATE="manual-test-task-template.yaml"

configDir=$1  #存储项目中资源配置
shift

pipelineDir=$1  #pipeline输出目录
shift
output="" #存储生成的pipeline文件

tmpDir="./"  #存储临时文件

deploySuccessWebhook=$1

#-----------------------------------------------------

function pipelineHeader() {
  local configFile=$1
  
  local pipelineName=$(basename $configFile) \
     && pipelineName=${configFile#*pipeline.} \
     && pipelineName=${pipelineName%.yaml*}
  
  local branchPattern=$(sed -nr '/^branchPattern: .+$/ {s/^branchPattern: (.+)$/\1/p;q}' ${configFile})
  if test -z "${branchPattern}"; then
    exit 1
  fi
  
  sed -e "s/\${PROMOTION_NAME}/${pipelineName}/" \
      -e "s/\${BRANCH_PATTERN}/${branchPattern}/" \
      ${PROMOTION_PIPELINE_HEADER_TEMPLATE} >> ${output}
}

#-----------------------------------------------------

function pipelineTasks() {
  echo "  tasks:" >> ${output}
  
  local configFile=$1
  
  local TEMP_PREFIX="${tmpDir}/.tmp.pipeline-task-"
  
  splitTasks ${configFile} ${TEMP_PREFIX}
  
  local file=""
  for file in ${TEMP_PREFIX}*; do
    local task=$(getTaskType $file)
    case $task in
      auto-test ) autoTestTask $file;;
      manual-test ) manualTestTask $file;;
      * ) commonTask $file;;
    esac
  done
  
  rm ${TEMP_PREFIX}* -f
}

#拆分tasks到独立文件
function splitTasks() {
  local configFile=$1
  local tempPreifx=$2
  
  local i=0
  local file=
  while IFS=~ read line; do
    if echo "$line"|grep ^- 2>&1 >/dev/null; then
      i=$(( $i + 1 ))
      file=${tempPreifx}$i
      touch $file
    fi
    echo "$line" >> ${file}
  done <<EOF
$(sed -nr '/^tasks:/,/^[a-zA-Z0-9]/ {/^[- ]/p}' ${configFile})
EOF
}

function getTaskType() {
  local taskFile=$1
  sed -nr '/  taskRef:/,/^  [a-zA-Z0-9]/{/^    name:/s/.*name: (.*)/\1/p}' ${taskFile}
}
function getContent() {
  local file=$1
  local key=$2
  
  local hasKey=$3
  local args=
  if test "$hasKey" == "true"; then
    args="/^  $key:/{p;d} /^- $key:/{s/^-(.*)/ \1/p;d}"
  fi
  sed -nr "/^[- ] $key:/,/^  [a-zA-Z0-9]/{$args /^  [- ]/p}" $file
}
function getValue() {
  local file=$1
  local name=$2
  local prefix="$3"
  sed -nr "/^${prefix}- name: ${name}/,/^${prefix}[^ ]/ {
    /^${prefix}  value: [^|]/ {
      s/^ +value: (.*)/\1/p;
      q;
    }
    /^${prefix}  value: |/ {
      s/^ +value: (.*)/\1/p;
    }
    /^${prefix}    / {
      s/^${prefix}  (.*)/\1/p;
    }
  }" ${file}
}

function commonTask() {
  local taskFile=$1
  if getContent ${taskFile} taskRef | grep kind: 2>&1 >/dev/null; then
    return 1
  fi
  sed -r '/^  taskRef:/a\    kind: ClusterTask' ${taskFile} \
  | awk '{print "  "$0}' >> ${output}
}

function autoTestTask() {
  local taskFile=$1
  
  local name=$(getContent ${taskFile} name true)
  local innerPipelineName=${name#*: }
  
  echo "${name}" | sed -r 's/^ (.*)/  -\1/' >> ${output}
  getContent ${taskFile} runAfter true | awk '{print "  "$0}' >> ${output}
  sed "s/\${INNER_PIPELINE_NAME}/${innerPipelineName}/" ${AUTO_TEST_TASK_TEMPLATE} \
  | awk '{print "    "$0}' >> ${output}
  getContent ${taskFile} pipelineRun | awk '{print "      "$0}'>> ${output}

  
  local innerPipelinePath=${pipelineDir}/${innerPipelineName}.yaml
  echo 'apiVersion: tekton.dev/v1beta1
kind: Pipeline
metadata:
  name: '${innerPipelineName}'
spec:' >> ${innerPipelinePath}
  getContent ${taskFile} pipelineSpec \
  | sed -r 's/^  (.*)/\1/' >> ${innerPipelinePath}
}

function manualTestTask() {
  local taskFile=$1
  
  getContent ${taskFile} name true | sed -r 's/^ (.*)/  -\1/' >> ${output}
  getContent ${taskFile} runAfter true | awk '{print "  "$0}' >> ${output}
  
  local env=$(getValue ${taskFile} env)
  sed -e "s/\${INNER_PIPELINE_NAME}/${innerPipelineName}/" \
      -e "s/\${ENV}/${env}/" \
      -e "s/\${DEPLOY_SUCCESS_WEBHOOK}/${deploySuccessWebhook}/" \
      ${MANUAL_TEST_TASK_TEMPLATE} \
  | awk '{print "    "$0}' >> ${output}
}

#-----------------------------------------------------
set -ex

mkdir ${pipelineDir} -p

for file in $(find ${configDir} -name 'pipeline.promotion-*.yaml' -maxdepth 1); do
  output=${pipelineDir}/$(basename $file)

  pipelineHeader $file

  pipelineTasks $file
done