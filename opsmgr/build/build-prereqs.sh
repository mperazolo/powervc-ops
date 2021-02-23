#!/bin/bash

GIFURL="http://mirror.centos.org/centos/8/PowerTools/`uname -m`/os/Packages"
GIFLIB="giflib-devel-5.1.4-3.el8.`uname -m`.rpm"

RPMURL="https://sourceforge.net/projects/rpmrebuild/files/rpmrebuild/2.16"
RPMRBD="rpmrebuild-2.16-1.noarch.rpm"

sudo yum -y install make rpm-build gpg
sudo yum -y install gcc gcc-c++ golang
sudo yum -y install python2 python2-devel python3 python3-devel
sudo yum -y install java-1.8.0-openjdk-devel java-11-openjdk-devel
sudo yum -y install ruby ruby-devel rubygems
sudo yum -y install cairo cairo-devel libjpeg-turbo-devel pango pango-devel
sudo yum -y install ${GIFURL}/${GIFLIB}
sudo yum -y install ${RPMURL}/${RPMRBD}
echo "% _binaries_in_noarch_packages_terminate_build 0" | sudo tee /etc/rpm/macros

