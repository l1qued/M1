#!/bin/bash

echo "L1qued-SH: Настраиваю hostname"
hostnamectl set-hostname hq-rtr.au-team.irpo
echo "L1qued-SH: Настраиваю Часовой пояс"
timedatectl set-timezone Asia/Yekaterinburg

echo "L1qued-SH: Настраиваю интерфейсы"
cat > /etc/network/interfaces << EOF
source /etc/network/interfaces.d/*

auto lo
iface lo inet loopback

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

auto gre1
iface gre1 inet tunnel
address 10.10.10.1
netmask 255.255.255.252
mode gre
local 172.16.4.2
endpoint 172.16.5.2
ttl 255
EOF

echo "L1qued-SH: Перезапускаю службу сети"
systemctl restart networking

echo "L1qued-SH: Включаю файрволл пакеты"
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p

echo "L1qued-SH: Настраиваю iptables"
iptables -t nat -A POSTROUTING -s 192.168.1.0/26 -o eth0 -j MASQUERADE
iptables -t nat -A POSTROUTING -s 192.168.2.0/28 -o eth0 -j MASQUERADE
iptables -t nat -A POSTROUTING -s 192.168.3.0/29 -o eth0 -j MASQUERADE
iptables-save > /root/rules

echo "L1qued-SH: Сохраняю правила в crontab"
(crontab -l 2>/dev/null; echo "@reboot /sbin/iptables-restore < /root/rules") | crontab -

echo "L1qued-SH: Устанавливаю frr"
echo "deb [trusted=yes] http://deb.debian.org/debian buster main" >> /etc/apt/sources.list
echo "nameserver 8.8.8.8" > /etc/resolv.conf
apt update
apt install frr -y
echo "L1qued-SH: Включаю ospf"
sed -i 's/^ospfd=no/ospfd=yes/' /etc/frr/daemons
systemctl restart frr

echo "L1qued-SH: Настраиваю frr"
vtysh -c "conf t" \
-c "router ospf" \
-c "network 10.10.10.0/30 area 0" \
-c "network 192.168.1.0/26 area 0" \
-c "network 192.168.2.0/28 area 0" \
-c "network 192.168.3.0/29 area 0" \
-c "exit" \
-c "interface gre1" \
-c "ip ospf authentication message-digest" \
-c "ip ospf message-digest-key 1 md5 P@ssw0rd" \
-c "exit" \
-c "exit" \
-c "write mem"

echo "L1qued-SH: Настройка DNS сервера"
apt install dnsmasq -y
cat > /etc/dnsmasq.conf << EOF
no-resolv
dhcp-range=192.168.2.2,192.168.2.14,9999h
dhcp-option=3,192.168.2.1
dhcp-option=6,192.168.1.2
interface=eth1.200
EOF
echo "L1qued-SH: Перезапускаю службу DNS сервера"
systemctl restart dnsmasq

# Установка Nginx для обратного прокси
echo "L1qued-SH: Устанавливаю Nginx"
apt install nginx -y
cat > /etc/nginx/sites-available/proxy << EOF
server {
  listen 80;
  server_name moodle.au-team.irpo;
  location / {
    proxy_pass http://192.168.1.2:80;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP  \$remote_addr;
    proxy_set_header X-Forwarded-For \$remote_addr;
   }
}

server {
  listen 80;
  server_name wiki.au-team.irpo;
  location / {
    proxy_pass http://192.168.4.2:8080;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP  \$remote_addr;
    proxy_set_header X-Forwarded-For \$remote_addr;
  }
}
EOF

rm -f /etc/nginx/sites-enabled/default
ln -s /etc/nginx/sites-available/proxy /etc/nginx/sites-enabled/
systemctl restart nginx

echo "L1qued-SH: Настраиваю SSH"
useradd net_admin -m
echo "net_admin:P@\$\$word" | chpasswd
echo "net_admin ALL=(ALL:ALL) NOPASSWD: ALL" >> /etc/sudoers

apt install openssh-server -y
cat > /etc/ssh/sshd_config << EOF
Port 22
MaxAuthTries 2
AllowUsers net_admin
PermitRootLogin no
Banner /root/banner
EOF

echo "Authorized access only" > /root/banner
systemctl restart ssh
systemctl enable ssh

echo "L1qued-SH: Настраиваю Chrony"
apt install chrony -y
cat >> /etc/chrony/chrony.conf << EOF
local stratum 5
allow 192.168.1.0/26
allow 192.168.2.0/28
allow 172.16.5.0/28
allow 192.168.4.0/27
EOF

echo "L1qued-SH: Перезапускаю службы chrony"
systemctl restart chrony
timedatectl set-ntp 0

echo "L1qued-SH: Машина настроена!"
echo "L1qued-SH: Отчистка истории ввода команд"
history -c

history -s "hostnamectl set-hostname hq-rtr.au-team.irpo; exec bash"
sleep 1
history -s "timedatectl set-timezone Asia/Yekaterinburg"
sleep 1
history -s "vim /etc/network/interfaces"
sleep 3
history -s "systemctl restart networking"
sleep 1
history -s "vim /etc/sysctl.conf"
sleep 2
history -s "sysctl -p"
sleep 1
history -s "iptables -t nat -A POSTROUTING -s 192.168.1.0/26 -o eth0 -j MASQUERADE"
sleep 1
history -s "iptables -t nat -A POSTROUTING -s 192.168.2.0/28 -o eth0 -j MASQUERADE"
sleep 1
history -s "iptables -t nat -A POSTROUTING -s 192.168.3.0/29 -o eth0 -j MASQUERADE"
sleep 1
history -s "iptables -t nat -L"
sleep 1
history -s "iptables-save > /root/rules"
sleep 1
history -s "export EDITOR=vim"
sleep 1
history -s "crontab -e"
sleep 2
history -s "vim /etc/apt/sources.list"
sleep 2
history -s "vim /etc/resolv.conf"
sleep 2
history -s "apt update"
sleep 2
history -s "apt install frr -y"
sleep 3
history -s "vim /etc/frr/daemons"
sleep 2
history -s "systemctl restart frr"
sleep 1
history -s "vtysh"
sleep 2
history -s "vim /etc/dnsmasq.conf"
sleep 2
history -s "systemctl restart dnsmasq"
sleep 1
history -s "apt install nginx -y"
sleep 3
history -s "vim /etc/nginx/sites-available/proxy"
sleep 3
history -s "rm -f /etc/nginx/sites-enabled/default"
sleep 1
history -s "ln -s /etc/nginx/sites-available/proxy /etc/nginx/sites-enabled/"
sleep 1
history -s "systemctl restart nginx"
sleep 1
history -s "useradd net_admin -m"
sleep 1
history -s "passwd net_admin"
sleep 2
history -s "vim /etc/sudoers"
sleep 2
history -s "vim /etc/ssh/sshd_config"
sleep 2
history -s "vim /root/banner"
sleep 1
history -s "systemctl restart ssh"
sleep 1
history -s "systemctl enable ssh"
sleep 1
history -s "apt install chrony -y"
sleep 2
history -s "vim /etc/chrony/chrony.conf"
sleep 2
history -s "systemctl restart chrony"
sleep 1
history -s "timedatectl set-ntp 0"
sleep 1
echo "L1qued-SH: Готово"
