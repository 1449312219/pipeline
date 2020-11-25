srcRootPath=$1
monitoredPath=$1/$2
deployedNamesapce=$3

function cpResoruces() {
  local type=$1
  local length=$(( ${#type} + 1 ))
  local path=$2
  for f in ${type}-*.yaml; do
    cp ${f} ${path}/${f:${length}}
  done
}


mkdir ${monitoredPath} -p
cpResoruces env ${monitoredPath}

for f in ${monitoredPath}/*.yaml; do
  sed -i -e "s/\${NAMESPACE}/${deployedNamesapce}/g" ${f}
done


commonPath=${monitoredPath}/../common
if test ! -d ${commonPath} && mkdir ${commonPath}; then
  cpResoruces common ${commonPath}
fi
