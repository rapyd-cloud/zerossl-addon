#!/bin/bash

source /etc/profile

# clean up any old version 
rm -rf /opt/letsencrypt
# clean up any old version 


DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/..";
WGET=$(which wget);
BASE_URL=$1
CLIENT_VERSION=$2
RAW_REPO_SCRIPS_URL="${BASE_URL}/scripts/"
RAW_REPO_CONFIG_URL="${BASE_URL}/configs/"
YUM_REPO_PATH="/etc/yum.repos.d/"
CENTOS_REPO_FILE="CentOS-Base.repo"
CENTOS_REPO_FILE_BACKUP=${CENTOS_REPO_FILE}"-backup"
VERS_FILE="vers.yaml"

echo Checking RPM database
{
  rpm -qa > /dev/null 2>&1  || rpm --rebuilddb
} &> /dev/null

echo "Installing required packages"
{
  grep -q "CentOS release 6." /etc/system-release && {
    command && code=$(echo $?) && [[ $code == "0" ]] && {
      [[ ! -f "${YUM_REPO_PATH}/${CENTOS_REPO_FILE_BACKUP}" ]] && {
      command cp -f ${YUM_REPO_PATH}/${CENTOS_REPO_FILE} ${YUM_REPO_PATH}/${CENTOS_REPO_FILE_BACKUP}
      $WGET --no-check-certificate "${RAW_REPO_CONFIG_URL}/${CENTOS_REPO_FILE}" -O ${YUM_REPO_PATH}/${CENTOS_REPO_FILE}
      }
    }
  }
  if grep -a 'AlmaLinux' /etc/system-release ; then
    microdnf -y install epel-release; microdnf install -y git bc nss socat --enablerepo='epel';
    wget http://repository.jelastic.com/pub/tinyproxy-1.8.3-2.el9.x86_64.rpm -O /tmp/tinyproxy-1.8.3-2.el9.x86_64.rpm
    dnf install -y /tmp/tinyproxy-1.8.3-2.el9.x86_64.rpm --disablerepo=* ; rm -f /tmp/tinyproxy-1.8.3-2.el9.x86_64.rpm
  else

    yum-config-manager --save --setopt=\*.retries=5 --setopt=\*.skip_if_unavailable=true --setopt=\*.timeout=5
    yum -y install epel-release git bc nss;
    yum -y install tinyproxy socat --enablerepo='epel';
  fi

  mkdir -p ${DIR}/opt;

  [[ -z $CLIENT_VERSION ]] && {
    $WGET --no-check-certificate "${RAW_REPO_CONFIG_URL}/${VERS_FILE}" -O /tmp/${VERS_FILE}
    CLIENT_VERSION=$(sed -n "s/.*version_acme-sh:.\(.*\)/\1/p" /tmp/${VERS_FILE})
  }

  [ ! -f "${DIR}/opt/letsencrypt/acme.sh" ] && {
    [ -d "${DIR}/opt/letsencrypt" ] && mv ${DIR}/opt/letsencrypt ${DIR}/opt/letsencrypt-certbot;
    git clone -b ${CLIENT_VERSION} https://github.com/acmesh-official/acme.sh ${DIR}/opt/letsencrypt;
  }

  #switch to letsencrypt acme path
  cd $DIR/opt/letsencrypt/

  #handle generic installation of acme.sh for zerosll
  ./acme.sh --server zerossl --install --no-cron --accountemail $email
  
  # zerossl requires a registered account with zerossl with EAB identification
  ./acme.sh  --server zerossl --register-account --insecure --force --eab-kid $RAPYDEABKID --eab-hmac-key $RAPYDEABHMAC
  
}

[ ! -f "${DIR}/root/validation.sh" ] && {
    $WGET --no-check-certificate $RAW_REPO_SCRIPS_URL/validation.sh -O ${DIR}/root/validation.sh
    chmod +x ${DIR}/root/validation.sh
}

JEM_SSL_MODULE_PATH="/usr/lib/jelastic/modules/ssl.module"
[[ -f "${JEM_SSL_MODULE_PATH}" && ! -s "$JEM_SSL_MODULE_PATH" ]] && {
    JEM_SSL_MODULE_LATEST_URL="https://raw.githubusercontent.com/jelastic/jem/master"$JEM_SSL_MODULE_PATH
    localedef -i en_US -f UTF-8 en_US.UTF-8
    wget --no-check-certificate "${JEM_SSL_MODULE_LATEST_URL}" -O $JEM_SSL_MODULE_PATH

    grep -q '^jelastic:' /etc/passwd && JELASTIC_UID=$(id -u jelastic) || JELASTIC_UID="700"
    [ -d "/var/www/" ] && chown ${JELASTIC_UID}:${JELASTIC_UID} /var/www/ /var/www/* 2> /dev/null
}

exit 0
