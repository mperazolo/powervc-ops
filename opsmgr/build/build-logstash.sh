#!/bin/bash

export SCRIPT_PATH="$( cd $( dirname ${BASH_SOURCE[0]} ) >/dev/null 2>&1 && pwd )"
export JAVA_HOME=`alternatives --list | grep java_sdk_1.8.0_openjdk | awk '{ print $3 }'`
export OSS=true
export LOGSTASH_SOURCE=1
export LOGSTASH_PATH="$SCRIPT_PATH/logstash"
export PATCH_PATH="$SCRIPT_PATH/patch/logstash"

git clone https://github.com/elastic/logstash.git
cd logstash
git checkout v7.10.2

patch < $PATCH_PATH/build.gradle.patch
cd rakelib; patch < $PATCH_PATH/artifacts.rake.patch; cd ..

echo "jruby-9.2.9.0" > .ruby-version
gpg --keyserver hkp://ipv4.pool.sks-keyservers.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB
curl -sSL https://get.rvm.io | bash -s stable --ruby=$(cat .ruby-version)
source ~/.rvm/scripts/rvm

gem install --no-document rake bundler fpm

rake artifact:rpm_oss

