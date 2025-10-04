#!/bin/bash

echo "L1qued-SH: Настраиваю hostname"
hostnamectl set-hostname br-srv.au-team.irpo
echo "L1qued-SH: Настраиваю часовой пояс"
timedatectl set-timezone Asia/Yekaterinburg

echo "L1qued-SH: Настраиваю интерфейсы"
mkdir -p /etc/net/ifaces/enp0s3
cat > /etc/net/ifaces/enp0s3/options << EOF
TYPE=eth
DISABLED=no
BOOTPROTO=static
NM_CONTROLLED=no
EOF

echo "192.168.4.2/27" > /etc/net/ifaces/enp0s3/ipv4address
echo "default via 192.168.4.1" > /etc/net/ifaces/enp0s3/ipv4route

echo "L1qued-SH: Перезапускаю службу сети"
systemctl restart network

echo "L1qued-SH: Установка Samba Domain Controller"
echo "nameserver 8.8.8.8" > /etc/resolv.conf
apt update
apt install task-samba-dc -y

echo "192.168.4.2 br-srv.au-team.irpo" >> /etc/hosts

echo "L1qued-SH: Настройка Provision Samba Domain"
rm -rf /etc/samba/smb.conf
samba-tool domain provision --realm=AU-TEAM.IRPO --domain=AU-TEAM --server-role=dc --dns-backend=SAMBA_INTERNAL --adminpass=P@ssw0rd

mv /var/lib/samba/private/krb5.conf /etc/krb5.conf
systemctl enable samba

echo "L1qued-SH: Создаю пользователей"
samba-tool user create user1.hq P@ssw0rd
samba-tool user create user2.hq P@ssw0rd
samba-tool user create user3.hq P@ssw0rd
samba-tool user create user4.hq P@ssw0rd
samba-tool user create user5.hq P@ssw0rd

samba-tool group add hq
samba-tool group addmembers hq user1.hq,user2.hq,user3.hq,user4.hq,user5.hq

echo "L1qued-SH: Настраиваю учётные записи"
useradd sshuser -u 1010
echo "sshuser:P@ssw0rd" | chpasswd
echo "WHEEL_USERS ALL=(ALL:ALL) NOPASSWD: ALL" >> /etc/sudoers
usermod -aG wheel sshuser

echo "L1qued-SH: Настраиваю SSH"
apt install openssh-common -y
cat > /etc/ssh/sshd_config << EOF
Port 2024
MaxAuthTries 2
AllowUsers sshuser
PermitRootLogin no
Banner /root/banner
EOF

echo "Authorized access only" > /root/banner
systemctl enable ssh
systemctl restart ssh

echo "L1qued-SH: Устанавливаю Docker и MediaWiki"
apt update
apt install docker-engine docker-compose -y
systemctl enable docker
systemctl start docker

docker pull mediawiki
docker pull mariadb

echo "L1qued-SH: Создаю docker-compose файла для MediaWiki"
cat > /root/wiki.yml << EOF
services:
  mariadb:
    image: mariadb
    container_name: mariadb
    restart: always
    environment:
      MYSQL_ROOT_PASSWORD: P@ssw0rd
      MYSQL_DATABASE: mediawiki
      MYSQL_USER: wiki
      MYSQL_PASSWORD: P@ssw0rd
    volumes:
      - mariadb_data:/var/lib/mysql
  wiki:
    image: mediawiki
    container_name: wiki
    restart: always
    environment:
      MEDIAWIKI_DB_HOST: mariadb
      MEDIAWIKI_DB_USER: wiki
      MEDIAWIKI_DB_PASSWORD: P@ssw0rd
      MEDIAWIKI_DB_NAME: mediawiki
    ports:
      - "8080:80"
    volumes:
      - wiki_data:/var/www/html/images
volumes:
  mariadb_data:
  wiki_data:
EOF

docker compose -f /root/wiki.yml up -d

echo "L1qued-SH: Устанавливаю Ansible"
apt install ansible -y
cat > /etc/ansible/hosts << EOF
hq-srv ansible_host=sshuser@192.168.1.2 ansible_port=2024
hq-cli ansible_host=sshuser@192.168.2.5 ansible_port=2024
hq-rtr ansible_host=net_admin@192.168.1.1 ansible_port=22
br-rtr ansible_host=net_admin@192.168.4.1 ansible_port=22
EOF

cat > /etc/ansible/ansible.cfg << EOF
[defaults]
interpreter_python=auto_silent
ansible_python_interpreter=/usr/bin/python3
host_key_checking=False
EOF

echo "L1qued-SH: Генерирую SSH ключи для Ansible"
ssh-keygen -t rsa -N "" -f /root/.ssh/id_rsa

echo "L1qued-SH: Не забудьте выполнить вручную:"
echo "1. ssh-copy-id для всех хостов"
echo "2. Настроить sudo схему Samba"
echo "3. Импорт пользователей из CSV"

sleep 5

echo "L1qued-SH: Машина настроена!"
echo "L1qued-SH: Отчистка истории ввода команд"

history -c
echo "L1qued-SH: Готово"
