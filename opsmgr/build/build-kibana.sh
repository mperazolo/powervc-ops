#!/bin/bash

SCRIPT_PATH="$( cd $( dirname ${BASH_SOURCE[0]} ) >/dev/null 2>&1 && pwd )"
EXEC_PATH="/home/kibana/rpmbuild-elastic"

if [ `id -u` == 0 ]; then
  if [ ! $( id -u kibana 2>/dev/null ) ]; then
    useradd kibana
  fi
  LINE="kibana ALL=(ALL:ALL) NOPASSWD:ALL"
  grep -qF -- "$LINE" /etc/sudoers || echo "$LINE" >> /etc/sudoers
  mkdir -p $EXEC_PATH
  cp -R $SCRIPT_PATH/* $EXEC_PATH 
  chown -R kibana.kibana $EXEC_PATH 
  su -s /bin/bash -c "cd $EXEC_PATH; ./build-kibana.sh" - kibana
  userdel -r kibana
  exit 0
fi

PATCHES_PATH="$EXEC_PATH/patches"
VERSION="7.10.2"

ARTIFACTS_PATH="$EXEC_PATH/kibana/target"
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

cd $EXEC_PATH # make sure we're in the right directory
git clone https://github.com/elastic/kibana.git
cd kibana
git checkout v$VERSION
patch -s -p0 < $PATCHES_PATH/kibana-$VERSION.patch

cd $EXEC_PATH
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
export NODEJS_HOME=$EXEC_PATH/node/bin
export JAVA_HOME=`alternatives --list | grep java_sdk_11_openjdk | awk '{ print $3 }'`
export PATH=$NODEJS_HOME:$JAVA_HOME/bin:$PATH

cd kibana
KEYS_PATH=$EXEC_PATH/keys
RUBY="2.1.0"
echo $RUBY > .ruby-version
gpg --import $KEYS_PATH/409B6B1796C275462A1703113804BB82D39DC0E3.key
gpg --import $KEYS_PATH/7D2BAF1CF37B13E2069D6956105BD0E739499BDB.key
curl -sSL https://get.rvm.io | bash -s stable --ruby=$(cat .ruby-version)
if [[ $EUID -ne 0 ]]; then
  source ~/.rvm/scripts/rvm
else
  source /usr/local/rvm/scripts/rvm
fi

gem install --no-document childprocess -v 1.0.1
gem install --no-document fpm -v 1.5.0
npm install --global yarn
yarn kbn bootstrap --oss
yarn build --oss --rpm --skip-archives

IFS=","
for i in "${ARTIFACTS[@]}"
do
  set -- $i
  echo Copying $1 to $OUTPUT_PATH/$2/$3
  sudo mkdir -p $OUTPUT_PATH/$2
  sudo \cp $1 $OUTPUT_PATH/$2/$3
done

