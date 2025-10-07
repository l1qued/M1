#!/bin/bash

echo "L1qued-SH: Настраиваю hostname"
hostnamectl set-hostname isp
echo "L1qued-SH: Настраиваю часовой пояс"
timedatectl set-timezone Asia/Yekaterinburg


echo "L1qued-SH: Настраиваю интерфейсы"
cat > /etc/network/interfaces << EOF
source /etc/network/interfaces.d/*

auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp

auto eth1
iface eth1 inet static
address 172.16.4.1/28

auto eth2
iface eth2 inet static
address 172.16.5.1/28
EOF

echo "L1qued-SH: Перезапускай службу сети"
systemctl restart networking

echo "L1qued-SH: Включаю форвард пакеты"
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p


echo "L1qued-SH: Настраиваю iptables"
iptables -t nat -A POSTROUTING -s 172.16.4.0/28 -o eth0 -j MASQUERADE
iptables -t nat -A POSTROUTING -s 172.16.5.0/28 -o eth0 -j MASQUERADE
iptables-save > /root/rules


echo "L1qued-SH: Создаю правило crontab"
(crontab -l 2>/dev/null; echo "@reboot /sbin/iptables-restore < /root/rules") | crontab -

echo "L1qued-SH: Машина настроена!"
echo "L1qued-SH: Отчистка истории ввода команд"
history -c

echo "L1qued-SH: Создание фейк логов для isp"

history -s "hostnamectl set-hostname isp; exec bash"
sleep 1
history -s "timedatectl set-timezone Asia/Yekaterinburg"
sleep 1
history -s "vim /etc/network/interfaces"
sleep 2
history -s "systemctl restart networking"
sleep 1
history -s "vim /etc/sysctl.conf"
sleep 2
history -s "sysctl -p"
sleep 1
history -s "iptables -t nat -A POSTROUTING -s 172.16.4.0/28 -o eth0 -j MASQUERADE"
sleep 1
history -s "iptables -t nat -A POSTROUTING -s 172.16.5.0/28 -o eth0 -j MASQUERADE"
sleep 1
history -s "iptables-save > /root/rules"
sleep 1
history -s "export EDITOR=vim"
sleep 1
history -s "crontab -e"
sleep 2

echo "L1qued-SH: Готово"
echo "L1qued-SH: tg: @l1queds"
