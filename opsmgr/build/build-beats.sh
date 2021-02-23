#!/bin/bash

SCRIPT_PATH="$( cd $( dirname ${BASH_SOURCE[0]} ) >/dev/null 2>&1 && pwd )"
VERSION="7.10.2"
EXEUSER="beats"

if [ `id -u` == 0 ]; then
  if [ ! $( id -u $EXEUSER 2>/dev/null ) ]; then
    useradd $EXEUSER
  fi
  LINE="$EXEUSER ALL=(ALL:ALL) NOPASSWD:ALL"
  grep -qF -- "$LINE" /etc/sudoers || echo "$LINE" >> /etc/sudoers
  export EXEC_PATH="/home/$EXEUSER/rpmbuild-elastic"
  mkdir -p $EXEC_PATH
  cp -R $SCRIPT_PATH/* $EXEC_PATH 
  chown -R $EXEUSER.$EXEUSER $EXEC_PATH
  su -s /bin/bash -c "cd $EXEC_PATH; ./build-beats.sh" - beats
  pkill -u $EXEUSER
  userdel -r $EXEUSER
  exit 0
else
  export EXEC_PATH="$SCRIPT_PATH"
fi

export GODDIR=$EXEC_PATH/go-daemon
export GOROOT=$EXEC_PATH/go
export GOPATH=$EXEC_PATH/gopath
export PATH=$GOROOT/bin:$GOPATH/bin:$PATH

BEATSURL="https://artifacts.elastic.co/downloads/beats"
BEATSDIR=$EXEC_PATH/beats
MYPREFIX="filebeat-oss-$VERSION.ibm.el8"
SPECNAME="filebeat-$VERSION-1"
SPECPATH="$BEATSDIR/BUILDROOT/$SPECNAME.ppc64le"
X86FNAME="$MYPREFIX.x86_64.rpm"
PPCFNAME="$MYPREFIX.ppc64le.rpm"

X86RPM="$BEATSDIR/RPMS/x86_64/$X86FNAME"
PPCRPM="$BEATSDIR/RPMS/ppc64le/$PPCFNAME"
MYSPEC="$BEATSDIR/SPECS/$MYPREFIX.ppc64le.spec"

ARTIFACTS=(
  "$X86RPM","deps-x86-cache","$X86FNAME"
  "$PPCRPM","deps-ppc64le-cache","$PPCFNAME"
)

OUTPUT_PATH="/gsa/pokgsa/projects/p/posee/pvcos-build/pvcos-wallaby"
SUDOCMD="sudo"
if [ ! -d "${OUTPUT_PATH}" ]; then
  OUTPUT_PATH="/tmp/rpmbuild-elastic"
  SUDOCMD=""
  mkdir -p $OUTPUT_PATH
fi

cd $EXEC_PATH # make sure we're in the right directory
git clone https://go.googlesource.com/go go
cd go
git checkout go1.16 # beats need go1.15.8 or above
cd src
./make.bash

cd $EXEC_PATH # make sure we're in the right directory
git clone https://github.com/tsg/go-daemon.git
cd $GODDIR
gcc src/god.c -m64 -o god-linux-ppc64le -lpthread

cd $EXEC_PATH # make sure we're in the right directory
mkdir -p $GOPATH/bin
mkdir -p $GOPATH/src/github.com/elastic
git clone https://github.com/elastic/beats.git $GOPATH/src/github.com/elastic/beats
cd $GOPATH/src/github.com/elastic/beats
git checkout v$VERSION

make mage
cd filebeat; mage build
chmod -R u+w $GOPATH

mkdir -p $BEATSDIR/RPMS/x86_64
cd $BEATSDIR/RPMS/x86_64
wget $BEATSURL/filebeat/filebeat-oss-$VERSION-x86_64.rpm -O $MYPREFIX.x86_64.rpm

mkdir -p $SPECPATH
cd $SPECPATH
rpm2cpio $BEATSDIR/RPMS/x86_64/$MYPREFIX.x86_64.rpm | cpio -idmv

mkdir -p $BEATSDIR/SPECS
cd $BEATSDIR/SPECS
rpmrebuild --notest-install --package --spec-only=$MYSPEC $X86RPM
sed -i 's/x86_64/ppc64le/g' $MYSPEC
sed -i 's/x86-64/ppc-64/g' $MYSPEC

cd $SPECPATH/usr/share/filebeat/bin
\cp $GOPATH/src/github.com/elastic/beats/filebeat/filebeat .
\cp $GODDIR/god-linux-ppc64le ./filebeat-god
chmod 0755 ./*

cd $BEATSDIR
rpmbuild --define "_topdir $BEATSDIR" -bb $MYSPEC
mv $BEATSDIR/RPMS/ppc64le/$SPECNAME.ppc64le.rpm $PPCRPM

IFS=","
for i in "${ARTIFACTS[@]}"
do
  set -- $i
  echo Copying $1 to $OUTPUT_PATH/$2/$3
  $SUDOCMD mkdir -p $OUTPUT_PATH/$2
  $SUDOCMD \cp $1 $OUTPUT_PATH/$2/$3
done

