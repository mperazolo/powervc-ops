sudo yum -y install ruby-devel gcc gcc-c++ make rpm-build rubygems gpg java-1.8.0-openjdk-devel
echo "% _binaries_in_noarch_packages_terminate_build 0" | sudo tee /etc/rpm/macros
