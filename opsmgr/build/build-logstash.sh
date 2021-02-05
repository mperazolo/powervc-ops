#!/bin/bash

export SCRIPT_PATH="$( cd $( dirname ${BASH_SOURCE[0]} ) >/dev/null 2>&1 && pwd )"
export JAVA_HOME=`alternatives --list | grep java_sdk_1.8.0_openjdk | awk '{ print $3 }'`
export OSS=true
export LOGSTASH_SOURCE=1
export PATCHES_PATH="$SCRIPT_PATH/patches"
export KEYS_PATH="$SCRIPT_PATH/keys"
export RUBY="jruby-9.2.9.0"
export VERSION="7.10.2"

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
ls -al build/logstash-oss-$VERSION-SNAPSHOT-no-jdk.rpm
ls -al build/logstash-oss-$VERSION-SNAPSHOT-x86_64.rpm
ls -al build/logstash-oss-$VERSION-SNAPSHOT-ppc64le.rpm

