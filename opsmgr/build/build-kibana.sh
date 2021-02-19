#!/bin/bash

SCRIPT_PATH="$( cd $( dirname ${BASH_SOURCE[0]} ) >/dev/null 2>&1 && pwd )"
PATCHES_PATH="$SCRIPT_PATH/patches"
VERSION="7.10.2"

ARTIFACTS_PATH="$SCRIPT_PATH/kibana/target"
PREFIX="kibana-oss-$VERSION"
ARTIFACTS=(
  "$ARTIFACTS_PATH/$PREFIX-SNAPSHOT-x86_64.rpm","deps-x86-cache","$PREFIX.ibm.el8.x86_64.rpm"
  "$ARTIFACTS_PATH/$PREFIX-SNAPSHOT-ppc64le.rpm","deps-ppc64le-cache","$PREFIX.ibm.el8.ppc64le.rpm"
)

OUTPUT_PATH="/gsa/pokgsa/projects/p/posee/pvcos-build/pvcos-wallaby"
if [ ! -d "${OUTPUT_PATH}" ]; then
  OUTPUT_PATH="/tmp/rpmbuild-elastic"
  mkdir -p $OUTPUT_PATH
fi

cd $SCRIPT_PATH # make sure we're in the right directory
git clone https://github.com/elastic/kibana.git
cd kibana
git checkout v$VERSION
patch -s -p0 < $PATCHES_PATH/kibana-$VERSION.patch

cd $SCRIPT_PATH
NODEVERS="v`cat kibana/.node-version`"
NODEARCH=`uname -m`
NODEFILE=""
if [[ "${NODEARCH}" == "x86_64" ]]; then
  NODEFILE="node-${NODEVERS}-linux-x64"
elif [[ "${NODEARCH}" == "ppc64le" ]]; then
  NODEFILE="node-${NODEVERS}-linux-ppc64le"
else
  echo "Architecture not supported: ${NODEARCH}"
  exit 1
fi
wget https://nodejs.org/dist/${NODEVERS}/${NODEFILE}.tar.gz
tar xzf ${NODEFILE}.tar.gz
rm -f ${NODEFILE}.tar.gz
mv -f ${NODEFILE} node
export NODEJS_HOME=`pwd`/node/bin
export JAVA_HOME=`alternatives --list | grep java_sdk_11_openjdk | awk '{ print $3 }'`
export PATH=$NODEJS_HOME:$JAVA_HOME/bin:$PATH

cd kibana
npm install --global yarn
gem install fpm -v 1.5.0
yarn kbn bootstrap
yarn build --oss --rpm --skip-archives

IFS=","
for i in "${ARTIFACTS[@]}"
do
  set -- $i
  echo Copying $1 to $OUTPUT_PATH/$2/$3
  mkdir -p $OUTPUT_PATH/$2
  \cp $1 $OUTPUT_PATH/$2/$3
done

