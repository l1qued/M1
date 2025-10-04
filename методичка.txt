# Методичка

Сети:
HQ-CLI
1 HQ-Net

ISP
1 NAT
2 ISP-HQ
3 ISP-BR

HQ-SRV
1 HQ- Net

HQ-RTR
1 ISP-HQ
2 HQ-Net

BR-RTR
1 ISP-BR
2 BR-Net

BR-SRV
1 BR- Net

-------------- 1 Базовые настройки

HQ-CLI
hostnamectl set-hostname hq-cli.au-team.irpo; exec bash

HQ-SRV
hostnamectl set-hostname hq-srv.au-team.irpo; exec bash


ISP
hostnamectl set-hostname isp; exec bash
nano /etc/network/interfaces
auto eth0
	iface eth0 inet dhcp
auto eth1
	iface eth1 inet static
	address 172.16.4.1/28
auto eth2
	iface eth2 inet static
	address 172.16.5.1/28
systemctl restart networking
ip -c a

HQ-RTR
hostnamectl set-hostname hq-rtr.au-team.irpo; exec bash
nano /etc/network/interfaces
auto eth0
	iface eth0 inet static
	address 172.16.4.2/28
	gateway 172.16.4.1
auto eth1
	iface eth1 inet manual
auto eth1.100
	iface eth1.100 inet static
	address 192.168.1.1/26	
	vlan-raw-device eth1
auto eth1.200
	iface eth1.200 inet static
	address 192.168.2.1/28	
	vlan-raw-device eth1
auto eth1.999
	iface eth1.999 inet static
	address 192.168.3.1/29	
	vlan-raw-device eth1
systemctl restart networking
ip -c a


BR-RTR
hostnamectl set-hostname br-rtr.au-team.irpo; exec bash
nano /etc/network/interfaces
auto eth0
	iface eth0 inet static
	address 172.16.5.2/28
	gateway 172.16.5.1
auto eth1
	iface eth1 inet static
	address 192.168.4.1/27
systemctl restart networking
ip -c a


BR-SRV
hostnamectl set-hostname br-srv.au-team.irpo; exec bash
ip -c a
vim /etc/net/ifaces/enp0s3/options
	TYPE=eth
	DISABLED=no
	BOOTPROTO=static
	NM_CONTROLLED=no
vim /etc/net/ifaces/enp0s3/ipv4address
	192.168.4.2/27
vim /etc/net/ifaces/enp0s3/ipv4route
	default via 192.168.4.1
systemctl restart network
ip -c a


-------------- 2 Настройте часовой пояс 

HQ-CLI
timedatectl set-timezone Asia/Yekaterinburg
timedatectl status

ISP
timedatectl set-timezone Asia/Yekaterinburg
timedatectl status

HQ-SRV
timedatectl set-timezone Asia/Yekaterinburg
timedatectl status

HQ-RTR
timedatectl set-timezone Asia/Yekaterinburg
timedatectl status

BR-RTR
timedatectl set-timezone Asia/Yekaterinburg
timedatectl status

BR-SRV
timedatectl set-timezone Asia/Yekaterinburg
timedatectl status


-------------- 3 Настройка forward пакетов

ISP
nano /etc/sysctl.conf
	net.ipv4.ip_forward=1
sysctl -p
	
HQ-RTR
nano /etc/sysctl.conf
	net.ipv4.ip_forward=1
sysctl -p

BR-RTR
nano /etc/sysctl.conf
	net.ipv4.ip_forward=1
sysctl -p

-------------- 4 Настройка NAT

ISP
iptables -t nat -A POSTROUTING –s 172.16.4.0/28 –o eth0 -j MASQUERADE
iptables -t nat -A POSTROUTING –s 172.16.5.0/28 –o eth0 -j MASQUERADE
iptables -t nat -L
iptables-save > /root/rules
export EDITOR=nano
crontab -e
	@reboot /sbin/iptables-restore < /root/rules
iptables –t nat -L


HQ-RTR
iptables -t nat -A POSTROUTING -s 192.168.1.0/26 -o eth0 -j MASQUERADE
iptables -t nat -A POSTROUTING -s 192.168.2.0/28 -o eth0 -j MASQUERADE
iptables -t nat -A POSTROUTING -s 192.168.3.0/29 -o eth0 -j MASQUERADE
iptables -t nat -L
iptables-save > /root/rules
export EDITOR=nano
crontab -e
	@reboot /sbin/iptables-restore < /root/rules
iptables –t nat -L


BR-RTR
iptables -t nat -A POSTROUTING -s 192.168.4.0/27 -o eth0 -j MASQUERADE
iptables -t nat -L
iptables-save > /root/rules
export EDITOR=nano
crontab -e
	@reboot /sbin/iptables-restore < /root/rules
iptables –t nat -L



-------------- 5 Настройка VLAN для HQ-SRV и HQ-CLI:

HQ-SRV
mkdir /etc/net/ifaces/enp0s3.100
vim /etc/net/ifaces/enp0s3.100/options
	TYPE=vlan
	HOST= enp0s3
	VID=100
	DISABLED=no
	BOOTPROTO=static
vim /etc/net/ifaces/enp0s3.100/ipv4address 
	192.168.1.2/26
vim /etc/net/ifaces/enp0s3.100/ipv4route
	default via 192.168.1.1
systemctl restart network

ip -c a
ping 192.168.1.1


HQ-CLI
mkdir /etc/net/ifaces/enp0s3.200
vim /etc/net/ifaces/enp0s3.200/options
	TYPE=vlan
	VID=200
	HOST= enp0s3
	DISABLED=no
	BOOTPROTO=dhcp
systemctl restart network

ip -c a
ping 192.168.2.1

-------------- 6 Настройка IP-туннеля

HQ-RTR
nano /etc/network/interfaces
	auto gre1
	iface gre1 inet tunnel
	address 10.10.10.1
	netmask 255.255.255.252
	mode gre
	local 172.16.4.2
	endpoint 172.16.5.2
	ttl 255
systemctl restart networking
ip -c a

BR-RTR
nano /etc/network/interfaces
	auto gre1
	iface gre1 inet tunnel
	address 10.10.10.2
	netmask 255.255.255.252
	mode gre
	local 172.16.5.2
	endpoint 172.16.4.2
	ttl 255
systemctl restart networking
ip -c a
ping 10.10.10.1

-------------- 7 Настройка OSPF

HQ-RTR
nano /etc/apt/sources.list
#
deb [trusted=yes] http://deb.debian.org/debian buster main
nano /etc/resolv.conf
	nameserver 8.8.8.8
apt update
apt install frr -y
nano /etc/frr/daemons
	ospfd=yes
systemctl restart frr

vtysh 
conf t 
router ospf
network 10.10.10.0/30 area 0
network 192.168.1.0/26 area 0
network 192.168.2.0/28 area 0
network 192.168.3.0/29 area 0
do wr mem

vtysh
conf t
int gre1
ip ospf authentication message-digest
ip ospf message-digest-key 1 md5 P@ssw0rd
do wr mem

nano /etc/apt/sources.list
#deb [trusted=yes] http://deb.debian.org/debian buster main

BR-RTR
nano /etc/apt/sources.list
#
deb [trusted=yes] http://deb.debian.org/debian buster main
nano /etc/resolv.conf
	nameserver 8.8.8.8
apt update
apt install frr -y
nano /etc/frr/daemons
	ospfd=yes
systemctl restart frr

vtysh 
conf t 
router ospf
network 10.10.10.0/30 area 0
network 192.168.4.0/27 area 0
do wr mem

vtysh
conf t
int gre1
ip ospf authentication message-digest
ip ospf message-digest-key 1 md5 P@ssw0rd
do wr mem

do show ip ospf neighbor

nano /etc/apt/sources.list
#deb [trusted=yes] http://deb.debian.org/debian buster main

HQ-SRV
ping 192.168.4.2
traceroute 192.168.4.2

-------------- 8 Настройка DHCP

HQ-RTR
apt update
apt install dnsmasq
nano /etc/dnsmasq.conf
	no-resolv
	dhcp-range=192.168.2.2,192.168.2.14,9999h
	dhcp-option=3,192.168.2.1
	dhcp-option=6,192.168.1.2
	interface=eth1.200
systemctl restart dnsmasq
systemctl status dnsmasq

HQ-CLI
systemctl restart network
ip -c a
ping 192.168.2.1


-------------- 9 Настройка DNS

HQ-SRV
systemctl disable --now bind
vim /etc/resolv.conf
	nameserver 8.8.8.8
apt-get update
apt-get install dnsmasq
systemctl enable --now dnsmasq
systemctl status dnsmasq

vim /etc/dnsmasq.conf

no-resolv 
domain=au-team.irpo
server=8.8.8.8 
interface=* 

address=/hq-rtr.au-team.irpo/192.168.1.1
ptr-record=1.1.168.192.in-addr.arpa,hq-rtr.au-team.irpo
cname=moodle.au-team.irpo,hq-rtr.au-team.irpo
cname=wiki.au-team.irpo,hq-rtr.au-team.irpo

address=/br-rtr.au-team.irpo/192.168.4.1

address=/hq-srv.au-team.irpo/192.168.1.2
ptr-record=2.1.168.192.in-addr.arpa,hq-srv.au-team.irpo

address=/hq-cli.au-team.irpo/192.168.2.11 
ptr-record=11.2.168.192.in-addr.arpa,hq-cli.au-team.irpo

address=/br-srv.au-team.irpo/192.168.4.2


vim /etc/hosts
192.168.1.1	hq-rtr.au-team.irpo

systemctl restart dnsmasq

ping google.com
ping hq-rtr.au-team.irpo

HQ-CLI
ping google.com
ping hq-rtr.au-team.irpo
dig moodle.au-team.irpo
dig wiki.au-team.irpo


-------------- 10 Создание локальных учетных записей

HQ-SRV

useradd sshuser -u 1010
passwd sshuser
P@ssw0rd
vim /etc/sudoers
	WHEEL_USERS ALL=(ALL:ALL) NOPASSWD: ALL
usermod -aG wheel sshuser
id sshuser


BR-SRV

useradd sshuser -u 1010
passwd sshuser
P@ssw0rd
vim /etc/sudoers
	WHEEL_USERS ALL=(ALL:ALL) NOPASSWD: ALL
usermod -aG wheel sshuser
id sshuser


HQ-RTR

useradd net_admin -m
passwd net_admin
P@$$word
nano /etc/sudoers
net_admin	ALL=(ALL:ALL) NOPASSWD: ALL
	

BR-RTR

useradd net_admin -m
passwd net_admin
P@$$word
nano /etc/sudoers
net_admin	ALL=(ALL:ALL) NOPASSWD: ALL


-------------- 11 Настройка SSH

HQ-SRV

apt-get install openssh-common
vim /etc/openssh/sshd_config
	Port 2024
	MaxAuthTries 2
	AllowUsers sshuser
	PermitRootLogin no
	Banner /root/banner
vim /root/banner
	Authorized access only
systemctl enable --now sshd
systemctl restart sshd


BR-SRV

apt-get install openssh-common
vim /etc/openssh/sshd_config
	Port 2024
	MaxAuthTries 2
	AllowUsers sshuser
	PermitRootLogin no
	Banner /root/banner
vim /root/banner
	Authorized access only
systemctl enable --now sshd
systemctl restart sshd

HQ-CLI

ssh sshuser@192.168.1.2 -p 2024
ssh sshuser@192.168.4.2 -p 2024


 Module 2

 -------------- 1 Настройка доменного контроллера Samba
BR-SRV
vim /etc/resolv.conf
	nameserver 8.8.8.8
apt-get update
apt-get install task-samba-dc -y
vim /etc/resolv.conf
	nameserver 192.168.1.2

rm -rf /etc/samba/smb.conf
hostname -f
//hostnamectl set-hostname br-srv.au-team.irpo; exec bash

vim /etc/hosts
192.168.4.2	br-srv.au-team.irpo

HQ-SRV
vim /etc/dnsmasq.conf
server=/au-team.irpo/192.168.4.2
systemctl restart dnsmasq

BR-SRV
samba-tool domain provision
	AU-TEAM.IRPO
	AU-TEAM
	dc
	SAMBA_INTERNAL
	192.168.1.2 

mv -f /var/lib/samba/private/krb5.conf /etc/krb5.conf
systemctl enable samba

export EDITOR=vim
сrontab -e

@reboot /bin/systemctl restart network
@reboot /bin/systemctl restart samba

reboot

samba-tool domain info 127.0.0.1

samba-tool user add user1.hq P@ssw0rd
samba-tool user add user2.hq P@ssw0rd
samba-tool user add user3.hq P@ssw0rd
samba-tool user add user4.hq P@ssw0rd
samba-tool user add user5.hq P@ssw0rd

samba-tool group add hq

samba-tool group addmembers hq user1.hq,user2.hq,user3.hq,user4.hq,user5.hq

HQ-CLI
acc
Аутентификация
Домен AD
	AU-TEAM.IRPO
	AU-TEAM
	hq-cli
Administrator
P@ssw0rd


BR-SRV
apt-repo add rpm http://altrepo.ru/local-p10 noarch local-p10
apt-get update
apt-get install sudo-samba-schema -y
sudo-schema-apply

yes
Administrator
P@ssw0rd
ok

create-sudo-rule

Имя правила	: prava_hq
sudoHost 	: ALL
sudoCommand	: /bin/cat
sudoUser	: %hq

HQ-CLI
su -
apt-get update
apt-get install admc -y
kinit administrator
P@ssw0rd

admc
Настройки-Доп возм-sudoers-Атрибуты-sudoOption
!authenticate
Настройки-Доп возм-sudoers-Атрибуты-sudoCommand
/bin/cat
/bin/grep
/usr/bin/id

apt-get update
apt-get install sudo libsss_sudo

control sudo public

vim /etc/sssd/sssd.conf
	services = nss, pam, sudo
	sudo_provider = ad

vim /etc/nsswitch.conf
	sudoers: files sss

reboot
Ctrl+Alt+F1 (под рутом)
rm -rf /var/lib/sss/db/*
sss_cache -E
systemctl restart sssd

Ctrl+Alt+F2 (под доменным user1.hq)
sudo -l -U user1.hq

Ctrl+Alt+F1 (релогин под user1.hq)
sudo cat /etc/passwd | sudo grep root && sudo id root


BR-SRV
curl -L https://bit.ly/3C1nEYz > /root/users.zip
unzip /root/users.zip
mv /root/Users.csv /opt/Users.csv

vim import
csv_file=”/opt/Users.csv”
while IFS=”;” read -r firstName lastName role phone ou street zip city country password; do
if [ “$firstName” == “First Name” ]; then
		continue
fi
username=”${firstName,,}.${lastName,,}”
sudo samba-tool user add “$username” 123qweR%
done < “$csv_file”

chmod +x /root/import
bash /root/import


-------------- 2 Конфигурация файлового хранилища 

HQ-SRV
Ctrl+D

lsblk
mdadm --create /dev/md0 --level=5 --raid-devices=3 /dev/sd[b-d]
cat /proc/mdstat

mdadm --detail -scan --verbose > /etc/mdadm.conf
fdisk /dev/md0
n
Enter x3
w

mkfs.ext4 /dev/md0p1

vim /etc/fstab
/dev/md0p1	/raid5	ext4	defaults	0	0

mkdir /raid5
mount -a

apt-get update
apt-get install nfs-server

mkdir /raid5/nfs
chown 99:99 /raid5/nfs
chmod 777 /raid5/nfs

vim /etc/exports
/raid5/nfs 192.168.2.0/28(rw,sync,no_subtree_check)

exportfs -a
exportfs -v

systemctl enable nfs
systemctl restart nfs


HQ-CLI
apt-get update
apt-get install nfs-clients

mkdir -p /mnt/nfs
vim /etc/fstab

192.168.1.2:/raid5/nfs	/mnt/nfs	nfs	intr,soft,_netdev,x-systemd.automount 0 0

mount -a
mount -v

touch /mnt/nfs/cock

BR-SRV
ls /raid5/nfs

-------------- 3 Настройка chrony

HQ-RTR
apt update
apt install chrony -y
systemctl status chrony
timedatectl

nano /etc/chrony/chrony.conf
local stratum 5
allow 192.168.1.0/26
allow 192.168.2.0/28
allow 172.16.5.0/28
allow 192.168.4.0/27
#pool 2.debian
#rtcsync

systemctl enable --now chrony
systemctl restart chrony

timedatectl set-ntp 0
timedatectl

HQ-CLI
systemctl disable --now chronyd
systemctl status chronyd

apt-get update
apt-get install systemd-timesyncd -y
vim /etc/systemd/timesyncd.conf
	NTP=192.168.1.1
systemctl enable --now systemd-timesyncd
timedatectl timesync-status

Ctrl+Alt+F2
startx
continue 
reboot

BR-RTR
//apt purge ntp  
//apt purge chrony
//apt update
//apt install systemd-timesyncd
nano /etc/systemd/timesyncd.conf
	NTP=172.16.4.2
systemctl enable --now systemd-timesyncd


HQ-SRV
systemctl disable --now chronyd
systemctl status chronyd
apt-get update
apt-get install systemd-timesyncd -y
vim /etc/systemd/timesyncd.conf
	NTP=192.168.1.1
systemctl enable --now systemd-timesyncd
timedatectl timesync-status

BR-SRV
systemctl disable --now chronyd
systemctl status chronyd
apt-get update
apt-get install systemd-timesyncd
vim /etc/systemd/timesyncd.conf
	NTP=172.16.4.2
systemctl enable --now systemd-timesyncd
timedatectl

-------------- 4 Сконфигурируйте ansible

BR-SRV
apt-repo rm rpm http://altrepo.ru/local-p10
apt-get update
apt-get install ansible
vim /etc/ansible/hosts
	hq-srv ansible_host=sshuser@192.168.1.2 ansible_port=2024
	hq-cli ansible_host=sshuser@192.168.2.5 ansible_port=2024
	hq-rtr ansible_host=net_admin@192.168.1.1 ansible_port=22
	br-rtr ansible_host=net_admin@192.168.4.1 ansible_port=22

vim /etc/ansible/ansible.cfg
	interpreter_python=auto_silent
	ansible_python_interpreter=/usr/bin/python3


HQ-RTR
apt-get update
apt-get install ssh-server -y
nano /etc/ssh/sshd_config
	Port 22
	MaxAuthTries 2
	AllowUsers net_admin
	PermitRootLogin no
	Banner /root/banner
nano /root/banner
	Authorized access only
systemctl restart sshd
systemctl enable --now sshd



BR-RTR
apt update
apt install ssh-server -y
nano /etc/ssh/sshd_config
	Port 22
	MaxAuthTries 2
	AllowUsers net_admin
	PermitRootLogin no
	Banner /root/banner
nano /root/banner
	Authorized access only
systemctl restart sshd
systemctl enable --now sshd



HQ-CLI

useradd sshuser -u 1010
passwd sshuser
P@ssw0rd
vim /etc/sudoers
	WHEEL_USERS ALL=(ALL:ALL) NOPASSWD: ALL
usermod -aG wheel sshuser
id sshuser

apt-get install openssh-common
vim /etc/openssh/sshd_config
	Port 2024
	MaxAuthTries 2
	AllowUsers sshuser
	PermitRootLogin no
	Banner /root/banner
vim /root/banner
	Authorized access only
systemctl enable --now sshd
systemctl restart sshd

apt-get install python-module-jinja2 

(apt-get install python python-module-yaml python-module-jinja2 python-modules-json python-modules-distutils)

BR-SRV
ssh-keygen -t rsa
ssh-copy-id -p 22 net_admin@192.168.4.1
ssh-copy-id -p 2024 sshuser@192.168.2.11
ssh-copy-id -p 2024 sshuser@192.168.1.2
ssh-copy-id -p 22 net_admin@192.168.1.1

ansible all -m ping

-------------- 5 Развертывание Docker

BR-SRV
apt-get update
apt-get install docker-engine docker-compose
systemctl enable --now docker
systemctl status docker
docker pull mediawiki
docker pull mariadb

vim /root/wiki.yml
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
    volumes: [ mariadb_data:/var/lib/mysql ]
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
    #volumes: [ /root/mediawiki/LocalSettings.php:/var/www/html/LocalSettings.php ]
volumes:
  mariadb_data:

docker compose -f /root/wiki.yml up -d

HQ-CLI
192.168.4.2:8080
Хост базы данных:
mariadb

Имя базы данных (без дефисов):
mediawiki

Имя пользователя базы данных:
wiki
Пароль базы данных:
P@ssw0rd

wiki (можно своё название)
Ваше имя участника:
wiki
Пароль:
WikiP@ssw0rd

BR-SRV
mkdir /root/mediawiki
mv /home/sshuser/LocalSettings.php /root/mediawiki/
ls /root/mediawiki/

vim /root/wiki.yml
docker compose -f wiki.yml up -d
CLI
192.168.4.2:8080

-------------- 6 Статическая трансляция портов

BR-RTR
iptables -t nat -A PREROUTING -p tcp -d 192.168.4.1 --dport 80 -j DNAT --to-destination 192.168.4.2:8080
iptables -t nat -A PREROUTING -p tcp -d 192.168.4.1 --dport 2024 -j DNAT --to-destination 192.168.4.2:2024
iptables-save > /root/rules


HQ-RTR
iptables -t nat -A PREROUTING -p tcp -d 192.168.1.1 --dport 2024 -j DNAT --to-destination 192.168.1.2:2024
iptables-save > /root/rules

HQ-CLI
ssh -p 2024 sshuser@192.168.4.1


-------------- 7 Запустите сервис moodle

HQ-SRV
apt-get update
apt-get install apache2 php8.2 
apache2-mod_php8.2
mariadb-server 
php8.2-opcache 
php8.2-curl 
php8.2-gd 
php8.2-intl 
php8.2-mysqli 
php8.2-xml 
php8.2-xmlrpc 
php8.2-ldap 
php8.2-zip 
php8.2-soap 
php8.2-mbstring 
php8.2-json 
php8.2-xmlreader 
php8.2-fileinfo 
php8.2-sodium

systemctl enable -–now httpd2 mysqld

mysql_secure_installation
Enter
Y
P@ssw0rd
Y

mariadb -u root -p
CREATE DATABASE moodledb;
CREATE USER moodle IDENTIFIED BY ‘P@ssw0rd’;
GRANT ALL PRIVILEGES ON moodledb.* TO moodle;
FLUSH PRIVILEGES;
exit

curl -L https://github.com/moodle/moodle/archive/refs/tags/v4.5.0.zip > /root/moodle.zip

unzip /root/moodle.zip -d /var/www/html
mv /var/www/html/moodle-4.5.0/* /var/www/html/
ls /var/www/html

mkdir /var/www/moodledata
chown apache2:apache2 /var/www/html
chown apache2:apache2 /var/www/moodledata

mcedit /etc/php/8.2/apache2-mod_php/php.ini
F7  max_input_vars
max_input_vars = 5000

cd /var/www/html
ls
rm index.html
systemctl restart httpd2

HQ-CLI
http://192.168.1.2/install.php

Название базы данных:		moodledb
Пользователь базы данных:	moodle
Пароль:				P@ssw0rd

далее
Логин:			admin
Новый пароль:		P@ssw0rd
Имя:			Администратор 
Фамилия:		Пользователь 
Адрес электронной 	test.test@mail.ru

Полное название сайта:	moodle 
Краткое сайта:		site
Настройки 		Азия/Екат 
Контакты поддержки:	test.test@mail.ru 


-------------- 8 Обратный прокси-сервер на HQ-RTR

HQ-SRV

mcedit /var/www/html/config.php
$CFG->wwwroot	= ‘http://moodle.au-team.irpo’;

HQ-RTR
apt install nginx -y
nano /etc/nginx/sites-available/proxy
server {
  listen 80;
  server_name moodle.au-team.irpo;
  location / {
    proxy_pass http://192.168.1.2:80;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP  $remote_addr;
    proxy_set_header X-Forwarded-For $remote_addr;
   }
}

server {
  listen 80;
  server_name wiki.au-team.irpo;
  location / {
    proxy_pass http://192.168.4.2:8080;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP  $remote_addr;
    proxy_set_header X-Forwarded-For $remote_addr;
  }
}

rm -rf /etc/nginx/sites-available/default
rm -rf /etc/nginx/sites-enabled/default
ln -s /etc/nginx/sites-available/proxy /etc/nginx/sites-enabled
ls -la /etc/nginx/sites-enabled
systemctl restart nginx

HQ-CLI
moodle.au-team.irpo и 
wiki.au-team.irpo 

-------------- 9 Яндекс Браузер

HQ-CLI
apt-get update
apt-get install yandex-browser-stable
