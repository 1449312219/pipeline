#!/bin/bash

# copy form https://github.com/kubernetes-sigs/kustomize/edit/master/hack/install_kustomize.sh

release_url=https://api.github.com/repos/1449312219/pipeline/releases

if [ -n "$1" ]; then
    version=v$1
    release_url=${release_url}/tags/$version
fi

where=$PWD/pipeline
if [ -e $where ]; then
  echo "A file named pipeline already exists (remove it first)."
  exit 1
fi
mkdir $where

tmpDir=`mktemp -d`
if [[ ! "$tmpDir" || ! -d "$tmpDir" ]]; then
  echo "Could not create temp dir."
  exit 1
fi

function cleanup {
  rm -rf "$tmpDir"
}

trap cleanup EXIT

pushd $tmpDir >& /dev/null

curl -s $release_url |\
  grep tarball_url |\
  cut -d '"' -f 4 |\
  sort | tail -n 1 |\
  xargs curl -sLo pipeline.tar.gz

if [ -e ./pipeline.tar.gz ]; then
    tar xzf ./pipeline.tar.gz
else
    echo "Error: pipeline package does not exist!"
    exit 1
fi

cp ./*/* $where -R

popd >& /dev/null

chmod u+x $where/install.sh
ln -sf $where/install.sh /usr/bin/pipeline-install

echo pipeline installed to current directory.