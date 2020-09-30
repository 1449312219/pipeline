name=$1
dir=${2:-$1}
kubectl create configmap $name --from-file=$dir --dry-run=client -o yaml \
| kubectl apply -f -
