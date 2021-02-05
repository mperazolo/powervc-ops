#!/bin/bash

SCRIPT_PATH="$( cd $( dirname ${BASH_SOURCE[0]} ) >/dev/null 2>&1 && pwd )"
PATCHES_PATH="$SCRIPT_PATH/patches"
KEYS_PATH="$SCRIPT_PATH/keys"
RUBY="jruby-9.2.9.0"
VERSION="7.10.2"

export JAVA_HOME=`alternatives --list | grep java_sdk_1.8.0_openjdk | awk '{ print $3 }'`
export OSS=true
export LOGSTASH_SOURCE=1

ARTIFACTS_PATH="$SCRIPT_PATH/logstash/build"
PREFIX="logstash-oss-$VERSION"
ARTIFACTS=(
  "$ARTIFACTS_PATH/$PREFIX-SNAPSHOT-no-jdk.rpm","deps-noarch-cache","$PREFIX.ibm.el8.noarch.rpm"
  "$ARTIFACTS_PATH/$PREFIX-SNAPSHOT-x86_64.rpm","deps-x86-cache","$PREFIX.ibm.el8.x86_64.rpm"
  "$ARTIFACTS_PATH/$PREFIX-SNAPSHOT-ppc64le.rpm","deps-ppc64le-cache","$PREFIX.ibm.el8.ppc64le.rpm"
)

OUTPUT_PATH="/gsa/pokgsa/projects/p/posee/pvcos-build/pvcos-wallaby"
if [ ! -d "${OUTPUT_PATH}" ]; then
  OUTPUT_PATH="/tmp/rpmbuild-elastic"
  mkdir -p $OUTPUT_PATH
fi

cd $SCRIPT_PATH # make sure we're in the right directory

git clone https://github.com/elastic/logstash.git
cd logstash
git checkout v$VERSION
patch -s -p0 < $PATCHES_PATH/logstash-$VERSION.patch

echo $RUBY > .ruby-version
gpg --import $KEYS_PATH/409B6B1796C275462A1703113804BB82D39DC0E3.key
gpg --import $KEYS_PATH/7D2BAF1CF37B13E2069D6956105BD0E739499BDB.key
curl -sSL https://get.rvm.io | bash -s stable --ruby=$(cat .ruby-version)
if [[ $EUID -ne 0 ]]; then
  source ~/.rvm/scripts/rvm
else
  source /usr/local/rvm/scripts/rvm
fi
gem install --no-document rake bundler fpm

rake artifact:rpm_oss

IFS=","
for i in "${ARTIFACTS[@]}"
do
  set -- $i
  echo Copying $1 to $OUTPUT_PATH/$2/$3
  mkdir -p $OUTPUT_PATH/$2
  \cp $1 $OUTPUT_PATH/$2/$3
done

