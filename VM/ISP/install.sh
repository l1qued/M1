#!/bin/bash

echo "L1qued-SH: Копирую папки config файлов..."
# cp -r / /
# cp -r / /
# cp -r / /

echo "L1qued-SH: Устанавливаю hostname"
hostnamectl set-hostname isp; exec bash

echo "L1qued-SH: Перезапускаю сеть"
systemctl restart networking

sleep 3

echo "L1qued-SH: Устанавливаю временную зону"
timedatectl set-timezone Asia/Yekaterinburg

echo "L1qued-SH: Настраиваю iptables"
iptables -t nat -A POSTROUTING -s 172.16.4.0/28 -o eth0 -j MASQUERADE
iptables -t nat -A POSTROUTING -s 172.16.5.0/28 -o eth0 -j MASQUERADE

echo "L1qued-SH: Сохраняю правила iptables"
iptables-save > /root/rules

echo "L1qued-SH: Машина настроена"
echo "L1qued-SH: Отчистка истории ввода команд"

history -c
echo "L1qued-SH: Готово!"
