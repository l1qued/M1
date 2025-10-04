#!/bin/bash

echo "L1qued-SH: Настраиваю hostname"
hostnamectl set-hostname br-rtr.au-team.irpo
echo "L1qued-SH: Настраиваю часовой пояс"
timedatectl set-timezone Asia/Yekaterinburg

echo "L1qued-SH: Настраиваю интерфейсы"
cat > /etc/network/interfaces << EOF
source /etc/network/interfaces.d/*

auto lo
iface lo inet loopback

auto eth0
iface eth0 inet static
address 172.16.5.2/28
gateway 172.16.5.1

auto eth1
iface eth1 inet static
address 192.168.4.1/27

auto gre1
iface gre1 inet tunnel
address 10.10.10.2
netmask 255.255.255.252
mode gre
local 172.16.5.2
endpoint 172.16.4.2
ttl 255
EOF

echo "L1qued-SH: Перезапускаю службу сети"
systemctl restart networking

echo "L1qued-SH: Включаю файрвол пакеты"
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p

echo "L1qued-SH: Настраиваю iptables"
iptables -t nat -A POSTROUTING -s 192.168.4.0/27 -o eth0 -j MASQUERADE
iptables-save > /root/rules

echo "L1qued-SH: Сохраняю правила в crontab"
(crontab -l 2>/dev/null; echo "@reboot /sbin/iptables-restore < /root/rules") | crontab -

echo "L1qued-SH: Настраиваю статическую трансляцию портов (iptables)"
iptables -t nat -A PREROUTING -p tcp -d 192.168.4.1 --dport 80 -j DNAT --to-destination 192.168.4.2:8080
iptables -t nat -A PREROUTING -p tcp -d 192.168.4.1 --dport 2024 -j DNAT --to-destination 192.168.4.2:2024
iptables-save >> /root/rules

echo "L1qued-SH: Устанавливаю frr"
echo "deb [trusted=yes] http://deb.debian.org/debian buster main" >> /etc/apt/sources.list
echo "nameserver 8.8.8.8" > /etc/resolv.conf
apt update
apt install frr -y

echo "L1qued-SH: Настраиваю OSPF"
sed -i 's/^ospfd=no/ospfd=yes/' /etc/frr/daemons
systemctl restart frr

vtysh -c "conf t" \
-c "router ospf" \
-c "network 10.10.10.0/30 area 0" \
-c "network 192.168.4.0/27 area 0" \
-c "exit" \
-c "interface gre1" \
-c "ip ospf authentication message-digest" \
-c "ip ospf message-digest-key 1 md5 P@ssw0rd" \
-c "exit" \
-c "exit" \
-c "write mem"

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

echo "L1qued-SH: Машина настроена!"
echo "L1qued-SH: Отчистка истории ввода команд"

history -c
echo "L1qued-SH: Готово"
