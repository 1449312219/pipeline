set -ex

path=$(basename $1)
name=${path:1}

kubectl create configmap ${name} --from-file=${path} \
--dry-run=client -o yaml > ${name}.yaml