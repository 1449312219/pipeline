set -e
set -o pipefail

# 替换给定内容的占位符, 以IFS拆分占位值,解析成多条内容
# 1. 以export KEY="V1 V2 V3 ..."暴露占位值
# 2. 占位符模式 ${[A-Z_]+}
# 3. 占位值内容为单行字符串, 值不可含'|'
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

  for v in $(eval echo \${$key}); do
    __replace "$(echo "$line" | sed -r "s|\\$\{$key}|$v|g")"
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

function formatToDNS() {
  local value=$1
  echo $value | tr /[A-Z] .[a-z]
}

function printSplit() {
  echo ---
  echo
}

function printYamlContent() {
  key=$1
  sed -nr "/^${key}:/,/^[^- ].*$/ {  \
    /^${key}: *[^| ]+ *$/{  s/.*: *([^ ]*) */\1/p;q };  \
    /^[- ]/p;  \
  }"
}
