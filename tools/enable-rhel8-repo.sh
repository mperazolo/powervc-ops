#!/bin/bash
############################################################################
#
#               ------------------------------------------
#               THIS SCRIPT PROVIDED AS IS WITHOUT SUPPORT
#               ------------------------------------------
#
# Modified ibm_yum.sh to only create a repo file.
#
# ======= Full change history on SCM and Git                       =======
# ======= Keeping the original commit as a tribute to lnxgeek      =======
#
# Author: scott russell <lnxgeek@us.ibm.com>
# Version: 0.1
# Description: Wrapper script for up2date to use yum repos from the
#              ftp3.linux.ibm.com server. Avoids the need to keep a
#              user id and password exposed in the sources file.
#
#
# === INSTRUCTIONS:
# The following environment variables can be used:
#
#   FTP3USER=user@cc.ibm.com        Enterprise Linux FTP Account
#   FTP3PASS=mypasswd               Enterprise Linux FTP Password
#   FTP3HOST=ftp3.linux.ibm.com     Server to use for updates
#
# You must be root to run this script. The user id and password will be
# prompted for if the environment variables are not set. The server can be
# any site listed from https://ftp3.linux.ibm.com/sites.html and defaults
# to ftp3.linux.ibm.com.
#

############################################################################

## default host
if [ -z "$FTP3HOST" ] ; then
    FTP3HOST="ftp3.linux.ibm.com"
fi

## other vars that most likely should not change
YUM="/usr/bin/yum --noplugins"
RHN_SOURCE="/etc/yum.repos.d/ibm-ftp3.repo"
RHN_OLD="/etc/sysconfig/rhn/systemid"
RHREPO_SAVE="/etc/yum.repos.d/redhat.repo.$$.sav";

## these are detected automatically
ARCH=
VERSION=
RELEASE=

## this is called on exit to restore the sources file from the backup
cleanUp()
{
    if [ -e $RHN_SOURCE ] ; then
        TEMP=`rm --force $RHN_SOURCE`
        if [ $? != 0 ] ; then
            echo ""
            echo "Failed to remove temporary config file"
            echo "Remove $RHN_SOURCE"
            echo ""
        else
            echo ""
            echo "Removed temporary configuration"
            echo ""
        fi
    fi
    return 0;
}

## clean up proper if something goes bad
trap EXIT HUP INT QUIT TERM;


## must be root to run this
if [ `whoami` != "root" ] ; then
    echo "You must run this script as root. Goodbye."
    echo ""
    exit 1
fi

## get the userid
if [ -z "$FTP3USER" ] ; then
    echo -n "User ID: "
    read FTP3USER

    if [ -z "$FTP3USER" ] ; then
        echo ""
        echo "Missing userid. Either set the environment variable"
        echo "FTP3USER to your user id or enter a user id when prompted."
        echo "Goodbye."
        echo ""
        exit 1
    fi
fi

## get the password
if [ -z "$FTP3PASS" ] ; then
    ## prompt for password
    echo -n "Password for $FTP3USER: "
    stty -echo
    read -r FTP3PASS
    stty echo
    echo ""
    echo ""

    if [ -z "$FTP3PASS" ] ; then
        echo "Missing password. Either set the environment variable"
        echo "FTP3PASS to your user password or enter a password when"
        echo "prompted. Goodbye."
        echo ""
        exit 1
    fi
fi

## get the system arch
case `uname -m` in
    i?86    ) ARCH="i386"
              LABEL="server"
              ;;
    ppc64   ) ARCH="ppc64"
              LABEL="power"
              ;;
    ppc64le ) ARCH="ppc64le"
              LABEL="power-le"
              ;;
    s390x   ) ARCH="s390x"
              LABEL="system-z"
              ;;
    x86_64  ) ARCH="x86_64"
              LABEL="server"
              ;;
    *       ) ARCH=;;
esac

## check to see we got a good arch
if [ -z "$ARCH" ] ; then
    echo "Unknown or unsupported system arch: `uname -m`"
    echo "Try reporting this to ftpadmin@linux.ibm.com with"
    echo "the full output of uname -a and the contents of"
    echo "/etc/redhat-release"
    echo ""
    exit 1
fi

## get the version and release, most likely only works on RHEL
VERREL=`rpm -qf --qf "%{NAME}-%{VERSION}\n" /etc/redhat-release`
if [ $? != 0 ] ; then
    echo "Failed to find system version and release with the"
    echo "command \"rpm -q redhat-release\". Is this system"
    echo "running Red Hat Enterprise Linux?"
    echo ""
    exit 1
fi

if [ $(echo $VERREL | sed 's/.*release-//' | cut -b1) == 5 ]; then
  ## split something like "redhat-release-5Server" into 5 and server
  VERREL=`echo $VERREL | sed 's/.*release-//' | tr '[:upper:]' '[:lower:]'`
  RELEASE=${VERREL:0:1}
  VERSION=${VERREL:1}
elif [ $(echo $VERREL | sed 's/.*release-//' | cut -b1) == 8 ]; then
    ## split something like "redhat-release-8.0" into 8 and server
    VERREL=`echo $VERREL | sed 's/.*release-//' | tr '[:upper:]' '[:lower:]'`
    RELEASE=8
    VERSION="server"
else
  ## split something like "redhat-release-workstation-6Workstation"
  ## into 6 and workstation
  RELEASE=`echo $VERREL | cut -f4 -d"-" | cut -b1`
  VERSION=`echo $VERREL | cut -f3 -d"-"`
fi


## verify support for this release
case $RELEASE in
    8   ) : ;;
    *       ) RELEASE= ;;
esac

## verify support for this version
case $VERSION in
    server      ) : ;;
    workstation ) : ;;
    *           ) VERSION= ;;
esac

if [ -z "$VERSION" ] || [ -z "$RELEASE" ] ; then
    echo "Unknown or unsupported system version and release: $VERREL"
    echo "Try reporting this to ftpadmin@linux.ibm.com with the"
    echo "full output of uname -a and the contents of /etc/redhat-release"
    echo ""
    exit 1
fi

echo "Detected RHEL $RELEASE $VERSION $ARCH ..."

echo "Removing old repo file"
[ -f $RHN_SOURCE ] && rm -f $RHN_SOURCE

echo "Removing old rhn file"
[ -f $RHN_OLD ] && rm -f $RHN_OLD

echo "cleaning up old subscriptions"
subscription-manager unregister

# Encode the the username for use in URLs
FTP3USERENC=`echo $FTP3USER | sed s/@/%40/g`

# Encode user password for use in URLs
FTP3PASSENC=`echo -n $FTP3PASS | od -tx1 -An | tr -d '\n' | sed 's/ /%/g'`

## write out a new sources file
URL="ftp://$FTP3USERENC:$FTP3PASSENC@$FTP3HOST"

if [ $VERSION == "workstation" ]; then
    $LABEL=$VERSION
fi

if [[ $(lscpu |grep 'Model name:'|cut -d' ' -f2|cut -d',' -f1) == "POWER9" ]]; then
    # Base OS packages
    RHELPATH="yum-alt"
    LABEL="server"
    ARCH="power9/ppc64le"
else
    RHELPATH="yum"
    if [[ $RELEASE -eq 5 ]]; then
        RHELPATH="yum-eus"
    fi
fi

# Base OS packages
echo "[ftp3]" >> $RHN_SOURCE
echo "name=FTP3 yum repository" >> $RHN_SOURCE
echo "baseurl=$URL/redhat/$RHELPATH/$LABEL/$RELEASE/${RELEASE}/$ARCH/baseos/os" >> $RHN_SOURCE
echo "gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release" >> $RHN_SOURCE

# Supplementary packages
echo "[ftp3-supplementary]" >> $RHN_SOURCE
echo "name=FTP3 supplementary yum repository" >> $RHN_SOURCE
echo "baseurl=$URL/redhat/$RHELPATH/$LABEL/$RELEASE/${RELEASE}/$ARCH/supplementary/os/" >> $RHN_SOURCE
echo "gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release" >> $RHN_SOURCE

# Optional packages
echo "[ftp3-optional]" >> $RHN_SOURCE
echo "name=FTP3 optional yum repository" >> $RHN_SOURCE
echo "baseurl=$URL/redhat/$RHELPATH/$LABEL/$RELEASE/${RELEASE}/$ARCH/optional/os/" >> $RHN_SOURCE
echo "gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release" >> $RHN_SOURCE
echo "skip_if_unavailable=1" >>$RHN_SOURCE

#Appstream packages
echo "[ftp3-appstream]" >> $RHN_SOURCE
echo "name=FTP3 appstream yum repository" >> $RHN_SOURCE
echo "baseurl=$URL/redhat/$RHELPATH/$LABEL/$RELEASE/${RELEASE}/$ARCH/appstream/os" >> $RHN_SOURCE
echo "gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release" >> $RHN_SOURCE
echo "skip_if_unavailable=1" >> $RHN_SOURCE

#HighAvailability
echo "[ftp3-HighAvailability]" >> $RHN_SOURCE
echo "name=FTP3 HighAvailability  yum repository" >> $RHN_SOURCE
echo "baseurl=$URL/redhat/$RHELPATH/$LABEL/$RELEASE/${RELEASE}/$ARCH/highavailability/os" >> $RHN_SOURCE
echo "gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release" >> $RHN_SOURCE
echo "skip_if_unavailable=1" >> $RHN_SOURCE

#ResilientStorage
echo "[ftp3-ResilientStorage]" >> $RHN_SOURCE
echo "name=FTP3 ResilientStorage yum repository" >> $RHN_SOURCE
echo "baseurl=$URL/redhat/$RHELPATH/$LABEL/$RELEASE/${RELEASE}/$ARCH/ResilientStorage/os" >> $RHN_SOURCE
echo "gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release" >> $RHN_SOURCE
echo "skip_if_unavailable=1" >> $RHN_SOURCE

#CRB
echo "[ftp3-CRB]" >> $RHN_SOURCE
echo "name=FTP3 CRB yum repository" >> $RHN_SOURCE
echo "baseurl=$URL/redhat/$RHELPATH/$LABEL/$RELEASE/${RELEASE}/$ARCH/codeready-builder/os" >> $RHN_SOURCE
echo "gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release" >> $RHN_SOURCE
echo "skip_if_unavailable=1" >> $RHN_SOURCE

echo "Wrote new config file $RHN_SOURCE"
echo "Clearing out cache"
yum clean all

exit $?
