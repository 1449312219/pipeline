set -ex

gitLabel=$1
gitUrl=$2
gitPaths=${3:-""}
ns=${4:-default}
manifestGen=${5:-true}
clusterRole=${6:-flux}
httpRegistry=${7:-inner-docker-registry:5000}
syncGarbage=${8:-false}


# 创建命名空间
kubectl get ns ${ns} >/dev/null 2>&1 || kubectl create ns ${ns}


# 创建flux资源文件
./fluxctl install \
--git-url=${gitUrl} \
--git-path=${gitPaths} \
--manifest-generation=${manifestGen} \
--namespace=${ns} \
--git-user=robot \
--git-email=robot@users.noreply.github.com \
| sed -r '/^apiVersion: rbac\.authorization\.k8s\.io\/v1beta1$/,/^---$/d' \
> k/flux.yaml


# 获取gitServer ssh公钥
type ssh-keyscan 2>/dev/null \
&& ssh-keyscan $(echo ${gitUrl} \
            | sed -r 's|.*git@([^:/]+):?([^/]*)/.*|host=\1;port=\2;echo ${port:+-p $port} $host|e') \
   2>/dev/null > k/ssh-config.yaml


# 生成 flux + fluxcloud 资源文件
kubectl apply -k k --dry-run=client -o yaml \
| sed -r -e "/image:/{ s|image:( *)docker.io/|image:\1|; s|image:( *)(.*)|image:\1inner-docker-registry:5000/\2| }" \
         -e "s|GIT_LABEL_PLACEHOLDER|${gitLabel}|" \
         -e "s|NAMESPACE_PLACEHOLDER|${ns}|" \
         -e "s|FLUX_CLUSTERROLE_PLACEHOLDER|${clusterRole}|" \
         -e "s|HTTP_REGISTRYS_PLACEHOLDER|${httpRegistry}|" \
         -e "s|SYNC_GARBAGE_PLACEHOLDER|${syncGarbage}|" \
| kubectl apply -f - -n ${ns}


# 打印 ssh-key
kubectl wait -n ${ns} deployments --all --for=condition=Available --timeout=5m
key=$(./fluxctl identity --k8s-fwd-ns=${ns} --k8s-fwd-labels="name=flux")
key=${key% *}
echo $key
