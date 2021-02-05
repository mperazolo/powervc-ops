#!/bin/bash
set -x

export SCRIPT_PATH="$( cd $( dirname ${BASH_SOURCE[0]} ) >/dev/null 2>&1 && pwd )"
export JAVA_HOME=`alternatives --list | grep java_sdk_11_openjdk | awk '{ print $3 }'`
export PATCHES_PATH="$SCRIPT_PATH/patches"
export VERSION="7.10.2"

git clone https://github.com/elastic/elasticsearch.git
cd elasticsearch
git checkout v$VERSION
patch -s -p0 < $PATCHES_PATH/elasticsearch-$VERSION.patch

./gradlew :distribution:packages:oss-no-jdk-rpm:assemble
ls -al distribution/packages/oss-no-jdk-rpm/build/distributions/elasticsearch-oss-$VERSION-SNAPSHOT-no-jdk-x86_64.rpm

./gradlew :distribution:packages:oss-rpm:assemble
ls -al distribution/packages/oss-rpm/build/distributions/elasticsearch-oss-$VERSION-SNAPSHOT-x86_64.rpm

./gradlew :distribution:packages:ppc64le-oss-rpm:assemble
ls -al distribution/packages/ppc64le-oss-rpm/build/distributions/elasticsearch-oss-$VERSION-SNAPSHOT-ppc64le.rpm

