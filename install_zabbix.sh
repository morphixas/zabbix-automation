# Zabbix installation script
# Made by Tauras

# ------------CHANGEABLE PARAMETERS----------------------

# Main Zabbix server or proxy server IP address
ZabbixProxyIP="X.X.X.X"

# Zabbix userparameters and scripts from remote server (.tar.gz format)
# example: zabbix_scripts="http://1.1.1.1/zbxscripts/zbxscripts.tar.gz"

zabbix_scripts="1.1.1.1/server-preparation/zabbix_scripts.tar.gz"
zabbix_userparams="1.1.1.1/server-preparation/userparams.tar.gz"

# -------------------------------------------------------

# Operating system check
ubuntu=0
centos=0

if cat /etc/os-release | grep PRETTY_NAME | cut -d " " -f1 | cut -c14- | grep -q "Ubuntu"; then
  echo "OS detected: Ubuntu"
  ubuntu=1

elif cat /etc/os-release | grep PRETTY_NAME | cut -d " " -f1 | cut -c14- | grep -q "CentOS"; then
  echo "OS detected: CentOS"
  centos=1

else
  echo "OS is not supported"
  exit N
fi

# Zabbix agent installation
if [[ $ubuntu -eq 1 ]]; then
  echo "Installing Zabbix package"
  wget https://repo.zabbix.com/zabbix/4.2/ubuntu/pool/main/z/zabbix-release/zabbix-release_4.2-2+bionic_all.deb

  # add zabbix user
  groupadd zabbix
  useradd -g zabbix zabbix

  # install wget
  yes | sudo apt-get install wget

  # install zabbix agent and sender
  yes | sudo dpkg -i zabbix-release_4.2-2+bionic_all.deb
  sudo apt update
  yes | sudo apt-get install zabbix-agent zabbix-sender zabbix-get
  echo "Zabbix agent package was installed/updated"

elif [[ $centos -eq 1 ]]; then
  echo "Installing Zabbix package"
  yes | rpm -Uvh https://repo.zabbix.com/zabbix/4.2/rhel/7/x86_64/zabbix-release-4.2-2.el7.noarch.rpm

  # add zabbix user
  groupadd zabbix
  useradd -g zabbix zabbix

  # install wget
  yes | sudo yum install wget 

  # install zabbix agent and sender
  yes | sudo yum install zabbix-agent zabbix-sender zabbix-get -y
  echo "Zabbix agent package was installed/updated"
fi

# Configure Zabbix configuration file
cd /etc/zabbix/
cat /dev/null > zabbix_agentd.conf
cat << EOT >> zabbix_agentd.conf
PidFile=/var/run/zabbix/zabbix_agentd.pid
LogFile=/var/log/zabbix/zabbix_agentd.log
LogFileSize=0
Server=$ZabbixProxyIP
ServerActive=$ZabbixProxyIP
Hostname=$HOSTNAME
Include=/etc/zabbix/zabbix_agentd.d/*.conf
Timeout=10
EOT
echo "Zabbix configuration file created"

# Add Zabbix to sudoers list
cd /etc/sudoers.d/
cat /dev/null > zabbix
cat << EOT >> zabbix
Defaults:zabbix !requiretty
zabbix ALL=NOPASSWD: /sbin/dmsetup
zabbix ALL=NOPASSWD: /usr/sbin/zabbix_agentd
zabbix ALL=NOPASSWD: /usr/sbin/smartctl
zabbix ALL=NOPASSWD: /bin/ps
zabbix ALL=NOPASSWD: /usr/bin/ipmitool
zabbix ALL=NOPASSWD: /sbin/lsmod
zabbix ALL=NOPASSWD: /usr/libexec/zabbix-extensions/scripts/check_raid.pl
zabbix ALL=NOPASSWD: /opt/MicronTechnology/MicronStorageExecutive/msecli
zabbix ALL=NOPASSWD: /usr/bin/lsblk
zabbix ALL=NOPASSWD: /bin/lsblk
zabbix ALL=NOPASSWD: /bin/grep
zabbix ALL=NOPASSWD: /usr/bin/ceph
zabbix ALL=NOPASSWD: /opt/MegaRAID/MegaCli/MegaCli64
zabbix ALL=NOPASSWD: /usr/bin/python
zabbix ALL=NOPASSWD: /usr/sbin/blkid
zabbix ALL=NOPASSWD: /usr/sbin/bcache-super-show
zabbix ALL=NOPASSWD: /usr/sbin/ceph-disk
zabbix ALL=NOPASSWD: /usr/bin/sensors
zabbix ALL=NOPASSWD: /usr/bin/isdct
zabbix ALL=NOPASSWD: /usr/bin/lscpu
zabbix ALL=NOPASSWD: /usr/bin/systemctl
zabbix ALL=NOPASSWD: /sbin/lsmod
zabbix ALL=NOPASSWD: /usr/libexec/zabbix-extensions/scripts/check_raid.pl
zabbix ALL=NOPASSWD: /usr/sbin/megacli
zabbix ALL=(ALL) NOPASSWD: /usr/sbin/vzlicview
zabbix  ALL=(ALL:ALL) NOPASSWD:ALL
EOT
echo "Zabbix added to sudoers list"

# Create Zabbix extensions folder
mkdir -p /usr/libexec/zabbix-extensions/scripts/var
chown zabbix:zabbix -R /usr/libexec/zabbix-extensions
echo "Zabbix extensions folder created"

# Copy script files from remote server 
cd /usr/libexec/zabbix-extensions/scripts/

wget --no-check-certificate "${zabbix_scripts}"
file_name=$(ls | grep .tar.gz)
tar -zxvf $file_name
yes | rm $file_name
echo "Script files deployed form remote server"

# Copy user parameter from remote server 
cd /etc/zabbix/zabbix_agentd.d/

wget --no-check-certificate "${zabbix_userparams}"
file_name=$(ls | grep .tar.gz)
tar -zxvf $file_name
yes | rm $file_name
echo "User parameters deployed form remote server"

# Grant executable permission to Zabbix scripts
chmod u+x -R /usr/libexec/zabbix-extensions
echo "Executable permission granted for Zabbix scripts"

# Start the Zabbix process
systemctl enable zabbix-agent
systemctl start zabbix-agent
echo "SCRIPT COMPLETED"
