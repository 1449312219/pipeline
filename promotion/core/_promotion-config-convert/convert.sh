PROMOTION_PIPELINE_HEADER_TEMPLATE="promotion-pipeline-header-template.yaml"
IMAGE_BUILD_TASK_TEMPLATE="image-build-task-template.yaml"
ENV_DEPLOY_TASK_TEMPLATE="env-deploy-task-template.yaml"
ENV_RELEASE_TASK_TEMPLATE="env-release-task-template.yaml"
MANUAL_TEST_TASK_TEMPLATE="manual-test-task-template.yaml"

manifestConfigDir=$1  #存储项目中资源配置
shift

pipelineDir=$1  #pipeline输出目录
shift
output="" #存储生成的pipeline文件

tmpDir="./"  #存储临时文件

#-----------------------------------------------------

function validateConfig() {
  local configFile=$1
  if egrep "^ +taskSpec:" ${configFile}; then
    echo '[taskSpec] cannot exist !' >&2
    return 1
  fi
}

#-----------------------------------------------------

function pipelineHeader() {
  local configFile=$1
  
  local pipelineName=$(basename $configFile) \
     && pipelineName=${configFile#*pipeline.promotion-} \
     && pipelineName=${pipelineName%.yaml*}
  
  local branchPattern=$(sed -nr '/^branchPattern: .+$/ {s/^branchPattern: (.+)$/\1/p;q}' ${configFile})
  if test -z "${branchPattern}"; then
    echo '[branchPattern] not specified !' >&2
    return 1
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
  
  splitTasks ${configFile} ${TEMP_PREFIX} tasks
  
  local file=""
  for file in ${TEMP_PREFIX}*; do
    local task=$(getTaskType $file)
    case $task in
      image-build ) imageBuildTask $file;;
      env-deploy ) envDeployTask $file;;
      manual-test ) manualTestTask $file;;
      env-release ) envReleaseTask $file;;
      * ) commonTask $file;;
    esac
  done
  
  rm ${TEMP_PREFIX}* -f
}

function pipelineFinally() {
  local configFile=$1
  
  if grep "^finally:" 2>&1 >/dev/null ${configFile}; then
    echo "  finally:" >> ${output}
  else
    return 0
  fi
  
  local TEMP_PREFIX="${tmpDir}/.tmp.pipeline-finally-task-"
  
  splitTasks ${configFile} ${TEMP_PREFIX} finally
  
  local file=""
  for file in ${TEMP_PREFIX}*; do
    local task=$(getTaskType $file)
    case $task in
      image-build ) return 1;;
      env-deploy ) return 1;;
      manual-test ) return 1;;
      env-release ) envReleaseTask $file;;
      * ) commonTask $file;;
    esac
  done
  
  rm ${TEMP_PREFIX}* -f
}

#-----------------------------------------------------

#拆分tasks到独立文件
function splitTasks() {
  local configFile=$1
  local tempPreifx=$2
  local section=$3
  
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
$(sed -nr "/^${section}:/,/^[a-zA-Z0-9]/ {/^[- ]/p}" ${configFile})
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
function addValue() {
  local taskFile=$1
  local prefix=$2
  local name=$3
  local value=$4
  sed -i "/^${prefix}params:/a\\${prefix}- name: ${name}\n${prefix}  value: ${value}" ${taskFile}
}

function commonTask() {
  local taskFile=$1
  if getContent ${taskFile} taskRef | grep kind: 2>&1 >/dev/null; then
    echo '[kind] cannot be specified in [taskRef] !' >&2
    return 1
  fi
  sed -r '/^  taskRef:/a\    kind: ClusterTask' ${taskFile} \
  | awk '{print "  "$0}' >> ${output}
}

function imageBuildTask() {
  deployedTaskByTemplate $1 ${IMAGE_BUILD_TASK_TEMPLATE}
}
function envReleaseTask() {
  deployedTaskByTemplate $1 ${ENV_RELEASE_TASK_TEMPLATE}
}
function envDeployTask() {
  deployedTaskByTemplate $1 ${ENV_DEPLOY_TASK_TEMPLATE}
}
function manualTestTask() {
  deployedTaskByTemplate $1 ${MANUAL_TEST_TASK_TEMPLATE}
}

function deployedTaskByTemplate() {
  local taskFile=$1
  local templateFile=$2
  
  local name=$(getContent ${taskFile} name true)
  local innerPipelineRunName=${name#*: }
  
  echo "${name}" |  sed -r 's/^ (.*)/  -\1/' >> ${output}
  getContent ${taskFile} runAfter true | awk '{print "  "$0}' >> ${output}
  
  local env=$(getValue ${taskFile} env "  ")
  local deployImageNames=$(getValue ${taskFile} deploy-image-names "  ")
  local deployImageTagPattern='$(params.repo-ref)'
  sed -e "s/\${INNER_PIPELINE_RUN_NAME}/${innerPipelineRunName}/" \
      -e "s/\${ENV}/${env}/" \
      -e "s/\${DEPLOY_IMAGE_NAMES}/${deployImageNames}/" \
      -e "s/\${DEPLOY_IMAGE_TAG_PATTERN}/${deployImageTagPattern}/" \
      ${templateFile} \
  | awk '{print "    "$0}' >> ${output}
}

#-----------------------------------------------------
set -ex

mkdir ${pipelineDir} -p

for file in $(find ${manifestConfigDir} -maxdepth 1 -name 'pipeline.promotion-*.yaml'); do
  output=${pipelineDir}/$(basename $file)
  
  validateConfig $file

  pipelineHeader $file

  pipelineTasks $file
  
  pipelineFinally $file
done
