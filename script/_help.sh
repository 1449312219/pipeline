# 替换数组元素
# 1.数组元素内容为单行字符串, 值不可含'|'
# 2.模板内,一行仅可指定一数组变量
function __replace(){
  line=$1

  key=$(echo "'$line'" | sed -r 's/.*\$\{([A-Z_]+)}.*/\1/')

  for v in $(eval echo \${$key}); do
    echo "$line" | sed -r "s|\\$\{[^}]+}|$v|"
  done
}
export -f __replace

function parsePlaceHolder() {
  local file=$1
  awk '/\$\{[A-Z_]+}/{gsub("'"'"'","'"'\\\''"'"); L="'\''"$0"'\''"; system("__replace "L); next} {print}' \
  $file
}

function addNamespace() {
  local namespace=${1,,*}
  sed -e "/^metadata:/ a\  namespace: ${namespace}" \
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
