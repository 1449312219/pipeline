set -e
set -o pipefail

# 替换给定内容的占位符, 以IFS拆分占位值,解析成多条内容
# 1. 以export KEY="V1 V2 V3 ..."暴露占位值, 占位值含空格时,可由"包裹(同bash处理)
# 2. 占位符模式 ${[A-Z_]+}
# 3. 占位值内容为单行字符串, 值不可含'|', 且内容会被base扩展
# 4. 一行内容支持多个占位符, 从右到左解析替换
function __replace(){
  set -o pipefail

  local line=$1

  local key=$(echo "'$line'" | sed -nr '/\$\{[A-Z_]+}/s/^.*\$\{([A-Z_]+)}.*/\1/p')

  # 已无占位符
  if test -z "$key"; then
    echo "$line"
    return
  fi

  # 未指定占位值
  if test -z "$(eval echo \${${key}})"; then
    echo no PlaceHolder value [$key]
    return 1
  fi

  eval local values=($(eval echo \${${key}}))
  for i in ${!values[@]}; do
    __replace "$(echo "$line" | sed -r "s|\\$\{$key}|${values[$i]}|g")"
  done
}
export -f __replace

function parsePlaceHolder() {
  local file=$1
  awk '/\$\{[A-Z_]+}/{gsub("'"'"'","'"'\\\''"'"); L="'\''"$0"'\''"; c=system("__replace "L); if(c!=0){exit c} next} {print}' \
  $file
}

function addNamespace() {
  local namespace=${1,,*}
  sed -r -e "/^metadata:/ a\  namespace: ${namespace}" \
         -e "/^metadata:/,/^[^ ]{2}.+$/ {/  namespace:/ d}"
}

function formatToNamespace() {
  local value=$1
  local keepEnd=$2
  # [a-z0-9]([-a-z0-9]*[a-z0-9])?
  value=$(echo $value | sed -r -e 's/.*/\L&\E/;' \
                               -e 's/\*//g; y|/.|--|;' \
                               -e 's/^-+//;')
  if test "$keepEnd" != "false"; then
    value=$(echo $value | sed -r 's/-+$//')
  fi
  echo -n $value
}
function formatBranchType() {
  formatToNamespace "$1" false
}
function formatManifestName() {
  local value=$1
  # [a-z0-9]([-a-z0-9]*[a-z0-9])?(\.[a-z0-9]([-a-z0-9]*[a-z0-9])?)*
  echo $value | tr /[A-Z] .[a-z] | sed -r 's/\.+/./g; s/^\.?(.*)\.?$/\1/'
}

function printSplit() {
  echo ---
  echo
}

function printYamlContent() {
  local key=$1
  sed -nr "/^${key}:/,/^[^- ].*$/ {  \
    /^${key}: *[^| ]+ *$/{  s/.*: *([^ ]*) */\1/p;q };  \
    /^[- ]/p;  \
  }"
}

function findManifestPaths() {
  local dir=$1
  shift
  find $dir -! -regex '.*/_.*' -name '*.yaml' -type f "$@"
}

function addWebHook() {
  local url=$1
  local branchType=$2
  local envs=$3

  echo -n "\"${url} \'${branchType}\' ${envs}\" " >> .build-webhooks
}
function getWebHooks() {
  cat .build-webhooks
  rm .build-webhooks -f
}

function parseArg() {
  local arg=$1
  local _IFS=$IFS
  IFS=: read purpose envs promotionType args <<<$arg
  envs=($(echo $envs | tr , " "))
  IFS=${_IFS}
}
