#!/bin/bash

PROJECT="elasticsearch"
SCRIPT_PATH="$( cd $( dirname ${BASH_SOURCE[0]} ) >/dev/null 2>&1 && pwd )"
EXEC_PATH="${SCRIPT_PATH}"
PATCHES_PATH="${EXEC_PATH}/patches"
OUTPUT_PATH="/tmp/rpmbuild-elastic"
PROJECT="elasticsearch"
VERSION="7.10.2"
JNAVERS="5.5.0"

export JAVA_HOME=`alternatives --list | grep java_sdk_11_openjdk | awk '{ print $3 }'`

if [ `id -u` == 0 ]; then
  EXEC_PATH="/home/${PROJECT}/rpmbuild-elastic"
  if [ ! $( id -u ${PROJECT} 2>/dev/null ) ]; then
    useradd ${PROJECT}
  fi
  LINE="${PROJECT} ALL=(ALL:ALL) NOPASSWD:ALL"
  grep -qF -- "$LINE" /etc/sudoers || echo "$LINE" >> /etc/sudoers
  mkdir -p ${EXEC_PATH}
  cp -R ${SCRIPT_PATH}/* ${EXEC_PATH}
  chown -R ${PROJECT}.${PROJECT} ${EXEC_PATH}
  su -s /bin/bash -c "cd ${EXEC_PATH}; ./build-${PROJECT}.sh" - ${PROJECT}
  GSA_PATH="/gsa/pokgsa/projects/p/posee/pvcos-build/pvcos-wallaby"
  if [ -d "${GSA_PATH}" ]; then
    echo "Copying build output to ${GSA_PATH}"
    \cp -R ${OUTPUT_PATH}/* ${GSA_PATH}
    rm -rf ${OUTPUT_PATH}
  fi
  pkill -u ${PROJECT}
  userdel -r ${PROJECT}
  exit 0
fi

ARTIFACTS_PATH="${EXEC_PATH}/elasticsearch/distribution/packages"
PREFIX="elasticsearch-oss-${VERSION}"
ARTIFACTS=(
  "${ARTIFACTS_PATH}/oss-no-jdk-rpm/build/distributions/${PREFIX}-SNAPSHOT-no-jdk-x86_64.rpm","deps-noarch-cache","${PREFIX}.ibm.el8.noarch.rpm"
  "${ARTIFACTS_PATH}/oss-rpm/build/distributions/${PREFIX}-SNAPSHOT-x86_64.rpm","deps-x86-cache","${PREFIX}.ibm.el8.x86_64.rpm"
  "${ARTIFACTS_PATH}/ppc64le-oss-rpm/build/distributions/${PREFIX}-SNAPSHOT-ppc64le.rpm","deps-ppc64le-cache","${PREFIX}.ibm.el8.ppc64le.rpm"
)

echo "Cloning ${PROJECT}"
cd ${EXEC_PATH} # make sure we're in the right directory
git clone https://github.com/elastic/elasticsearch.git
cd elasticsearch
git checkout v${VERSION}
patch -s -p0 < ${PATCHES_PATH}/elasticsearch-${VERSION}.patch

# Elastic sabotages the jna library to not include any other archs besides x86 and aarch64
# We need to patch their "custom" jna library to re-add support for ppc64le

# Download the original version of jna being used by Elastic
echo "Cloning jna-${JNAVERS}"
cd ${EXEC_PATH} # make sure we're in the right directory
git clone https://github.com/java-native-access/jna.git
cd jna
git checkout ${JNAVERS}

# Assemble no-jdk first 
# This will trigger download of custom jna library to cache
cd ${EXEC_PATH}/elasticsearch
./gradlew :distribution:packages:oss-no-jdk-rpm:assemble

# Fix cached jna library
CACHE_DIR=~/.gradle/caches
JAR_NAME=jna-${JNAVERS}.jar
JAR_FIND=$( find ${CACHE_DIR} -name ${JAR_NAME} | grep "org.elasticsearch" )
JAR_PATH=$( dirname ${JAR_FIND} )
cd ${JAR_PATH}
mkdir tmp
cd tmp
echo "Extract contents from ${JAR_NAME}"
jar xvf ../${JAR_NAME}
mv ../${JAR_NAME} ../${JAR_NAME}.old
cd com/sun/jna
mkdir linux-ppc64le
cd linux-ppc64le
echo "Adding native support for ppc64le"
jar xvf ${EXEC_PATH}/jna/dist/linux-ppc64le.jar
rm -rf META-INF/
cd ${JAR_PATH}/tmp
echo "Repacking ${JAR_NAME}"
jar cvf ../${JAR_NAME} .
cd ..
rm -rf tmp

# Go back and build our target arch RPMs
cd ${EXEC_PATH}/elasticsearch
./gradlew :distribution:packages:oss-rpm:assemble
./gradlew :distribution:packages:ppc64le-oss-rpm:assemble

if [ -d "${OUTPUT_PATH}" ]; then
  sudo rm -rf ${OUTPUT_PATH}
fi
mkdir -p ${OUTPUT_PATH}

IFS=","
for i in "${ARTIFACTS[@]}"
do
  set -- $i
  echo "Saving build artifact $1"
  mkdir -p ${OUTPUT_PATH}/$2
  \cp $1 ${OUTPUT_PATH}/$2/$3
done

