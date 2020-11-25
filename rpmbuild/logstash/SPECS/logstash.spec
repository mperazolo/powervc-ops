#Licensed Materials - Property of IBM.  (c) Copyright IBM Corp. 2020.  All Rights Reserved.
%global bindir /usr/share/logstash
%define debug_package %{nil}

Summary:       Logstash rpm using system jdk
Name:          logstash
Version:       7.9.3
Release:       1.ibm
License:       Apache License 2.0
Group:         Development/Languages
Source0:       %{_topdir}/SOURCES/logstash-oss-%{version}.tar.gz
Source1:       %{_topdir}/SOURCES/logstash.service
Source2:       %{_topdir}/SOURCES/my-logstash.*
BuildArch:     ppc64le

Requires:      java >= 1:1.8.0

Provides:      logstash

%description
Logstash is an open source data collection engine with real-time pipelining capabilities. 
Logstash can dynamically unify data from disparate sources and normalize the data into 
destinations of your choice. Cleanse and democratize all your data for diverse advanced 
downstream analytics and visualization use cases.

This package removes arch specific jdks and points to the system jdk instead.

%prep
%setup -q -n %{name}-%{version}

%build
#nothing to do here

%install
mkdir -p %buildroot/%{bindir}
cp -a * %{buildroot}/%{bindir}/.
mkdir -p %buildroot/%{_sysconfdir}/%name
mv %{buildroot}/%{bindir}/config/* %{buildroot}/%{_sysconfdir}/%{name}
rm -rf %{buildroot}/%{bindir}/config
mkdir -p %buildroot/%{_sysconfdir}/systemd/system
cp %SOURCE1 %buildroot/%{_sysconfdir}/systemd/system/
cp -a %SOURCE2 %buildroot/%{bindir}

%pre
#add user
if ! /usr/bin/getent group logstash >/dev/null; then
  /usr/sbin/groupadd -r logstash
fi

if ! /usr/bin/getent passwd logstash >/dev/null; then
  /usr/sbin/useradd -g logstash -s /bin/nologin -r -d /usr/share/logstash logstash
fi

%post
#selinux
semodule -x 300 -i /usr/share/logstash/my-logstash.pp

#services
/usr/bin/systemctl daemon-reload
/usr/bin/systemctl enable logstash
/usr/bin/systemctl start logstash

#todo: set java_home and path vars

%files
%defattr(-,logstash,logstash,-)
%{bindir}
%{_sysconfdir}

%changelog
* Mon Nov 23 2020 Billee Jo kelder <bkelder@us.ibm.com>
- Initial Packaging
