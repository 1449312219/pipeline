dir='./_promotion-pipeline-config-convert'
taskPath='./promotion-pipeline-config-convert.yaml'

sh ${dir}/task.sh "${dir}" > ${taskPath}
