#!/bin/bash

sudo yum -y install make rpm-build gpg
sudo yum -y install gcc gcc-c++
sudo yum -y install java-1.8.0-openjdk-devel java-11-openjdk-devel
sudo yum -y install ruby ruby-devel rubygems
sudo yum -y install cairo cairo-devel libjpeg-turbo-devel pango pango-devel
sudo yum -y install https://www.rpmfind.net/linux/centos/8-stream/PowerTools/ppc64le/os/Packages/giflib-devel-5.1.4-3.el8.ppc64le.rpm
echo "% _binaries_in_noarch_packages_terminate_build 0" | sudo tee /etc/rpm/macros

