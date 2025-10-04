#!/bin/bash

echo "L1qued-SH: Настраиваю hostname"
hostnamectl set-hostname hq-srv.au-team.irpo
echo "L1qued-SH: Настраиваю часовой пояс"
timedatectl set-timezone Asia/Yekaterinburg

echo "L1qued-SH: Настраиваю VLAN"
mkdir -p /etc/net/ifaces/enp0s3.100

cat > /etc/net/ifaces/enp0s3.100/options << EOF
TYPE=vlan
HOST=enp0s3
VID=100
DISABLED=no
BOOTPROTO=static
EOF

echo "192.168.1.2/26" > /etc/net/ifaces/enp0s3.100/ipv4address
echo "default via 192.168.1.1" > /etc/net/ifaces/enp0s3.100/ipv4route

echo "L1qued-SH: Перезапускаю службу сети"
systemctl restart network

echo "L1qued-SH: Настраиваю DNS сервер"
systemctl disable --now bind
echo "nameserver 8.8.8.8" > /etc/resolv.conf

echo "L1qued-SH: Устанавливаю dnsmasq"
apt update
apt install dnsmasq -y

echo "L1qued-SH: Настраиваю dnsmasq"
cat > /etc/dnsmasq.conf << EOF
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

server=/au-team.irpo/192.168.4.2
EOF

echo "192.168.1.1 hq-rtr.au-team.irpo" >> /etc/hosts

echo "L1qued-SH: Перезапускаю службу dnsmasq"
systemctl restart dnsmasq

echo "L1qued-SH: Создаю RAID5"
echo "L1qued-SH: Предполагаю, что диски /dev/sdb, /dev/sdc, /dev/sdd существуют, если нет, сноси машину, и добавляй, за тем по новой запускай скрипт"
mdadm --create /dev/md0 --level=5 --raid-devices=3 /dev/sd[b-d] --force
echo "DEVICE /dev/sdb /dev/sdc /dev/sdd" > /etc/mdadm.conf
mdadm --detail --scan >> /etc/mdadm.conf

echo "L1qued-SH: Создаю разделы и файловую систему"
echo -e "n\np\n1\n\n\nw" | fdisk /dev/md0
mkfs.ext4 /dev/md0p1

echo "L1qued-SH: Монтирую RAID"
mkdir /raid5
echo "/dev/md0p1 /raid5 ext4 defaults 0 0" >> /etc/fstab
mount -a

echo "L1qued-SH: Устанавливаю NFS"
apt install nfs-server -y
echo "L1qued-SH: Настраиваю NFS"
mkdir /raid5/nfs
chown 99:99 /raid5/nfs
chmod 777 /raid5/nfs

echo "/raid5/nfs 192.168.2.0/28(rw,sync,no_subtree_check)" >> /etc/exports
exportfs -a
echo "L1qued-SH: Активирую и перезапускаю службу NFS"
systemctl enable nfs
systemctl restart nfs

echo "L1qued-SH: Создаю и настраиваю учетную запись sshuser"
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

echo "L1qued-SH: Устанавливаю Moodle"
apt update
apt install apache2 php8.2 mariadb-server -y
apt install php8.2-opcache php8.2-curl php8.2-gd php8.2-intl php8.2-mysqli \
php8.2-xml php8.2-xmlrpc php8.2-ldap php8.2-zip php8.2-soap php8.2-mbstring \
php8.2-json php8.2-xmlreader php8.2-fileinfo php8.2-sodium -y

systemctl enable apache2 mariadb
systemctl start apache2 mariadb

echo "L1qued-SH: Настраиваю MYSQL"
mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY 'P@ssw0rd';"
mysql -u root -pP@ssw0rd -e "CREATE DATABASE moodledb;"
mysql -u root -pP@ssw0rd -e "CREATE USER 'moodle'@'localhost' IDENTIFIED BY 'P@ssw0rd';"
mysql -u root -pP@ssw0rd -e "GRANT ALL PRIVILEGES ON moodledb.* TO 'moodle'@'localhost';"
mysql -u root -pP@ssw0rd -e "FLUSH PRIVILEGES;"

echo "L1qued-SH: Загружаю и устанавливаю Moodle"
curl -L https://github.com/moodle/moodle/archive/refs/tags/v4.5.0.zip -o /root/moodle.zip
apt install unzip -y
unzip /root/moodle.zip -d /var/www/html/
mv /var/www/html/moodle-4.5.0/* /var/www/html/
rm -rf /var/www/html/moodle-4.5.0

mkdir /var/www/moodledata
chown -R www-data:www-data /var/www/html
chown www-data:www-data /var/www/moodledata

echo "L1qued-SH: Настраиваю PHP"
sed -i 's/^max_input_vars = .*/max_input_vars = 5000/' /etc/php/8.2/apache2/php.ini

rm -f /var/www/html/index.html
systemctl restart apache2

echo "L1qued-SH: Машина настроена!"
echo "L1qued-SH: Отчистка истории ввода команд"

history -c
echo "L1qued-SH: Готово"
