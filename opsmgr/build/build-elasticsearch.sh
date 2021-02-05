#!/bin/bash

SCRIPT_PATH="$( cd $( dirname ${BASH_SOURCE[0]} ) >/dev/null 2>&1 && pwd )"
PATCHES_PATH="$SCRIPT_PATH/patches"
VERSION="7.10.2"

export JAVA_HOME=`alternatives --list | grep java_sdk_11_openjdk | awk '{ print $3 }'`

ARTIFACTS_PATH="$SCRIPT_PATH/distribution/packages"
PREFIX="elasticsearch-oss-$VERSION"
ARTIFACTS=(
  "$ARTIFACTS_PATH/oss-no-jdk-rpm/build/distributions/$PREFIX-SNAPSHOT-no-jdk-x86_64.rpm","deps-noarch-cache","$PREFIX.ibm.el8.noarch.rpm"
  "$ARTIFACTS_PATH/oss-rpm/build/distributions/$PREFIX-SNAPSHOT-x86_64.rpm","deps-x86-cache","$PREFIX.ibm.el8.x86_64.rpm"
  "$ARTIFACTS_PATH/ppc64le-oss-rpm/build/distributions/$PREFIX-SNAPSHOT-ppc64le.rpm","deps-ppc64le-cache","$PREFIX.ibm.el8.ppc64le.rpm"
)

OUTPUT_PATH="/gsa/pokgsa/projects/p/posee/pvcos-build/pvcos-wallaby"
if [ ! -d "${OUTPUT_PATH}" ]; then
  OUTPUT_PATH="/tmp/rpmbuild-elastic"
  mkdir -p $OUTPUT_PATH
fi

cd $SCRIPT_PATH # make sure we're in the right directory

git clone https://github.com/elastic/elasticsearch.git
cd elasticsearch
git checkout v$VERSION
patch -s -p0 < $PATCHES_PATH/elasticsearch-$VERSION.patch

./gradlew :distribution:packages:oss-no-jdk-rpm:assemble
./gradlew :distribution:packages:oss-rpm:assemble
./gradlew :distribution:packages:ppc64le-oss-rpm:assemble

IFS=","
for i in "${ARTIFACTS[@]}"
do
  set -- $i
  echo Copying $1 to $OUTPUT_PATH/$2/$3
  mkdir -p $OUTPUT_PATH/$2
  \cp $1 $OUTPUT_PATH/$2/$3
done

