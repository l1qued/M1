#!/bin/bash

execute_command() {
    echo "Выполняется: $1"
    eval $1
    if [ $? -ne 0 ]; then
        echo "Ошибка при выполнении: $1"
        exit 1
    fi
}

echo "L1qued-SH: Копирую конфиг файлы"
# cp -r /путь/источник1 /путь/назначение1
# cp -r /путь/источник2 /путь/назначение2  
# cp -r /путь/источник3 /путь/назначение3

echo "L1qued-SH:  Настраиваю hostname"
execute_command "hostnamectl set-hostname br-rtr.au-team.irpo"
execute_command "systemctl restart networking"

execute_command "timedatectl set-timezone Asia/Yekaterinburg"

echo "L1qued-SH: Настраиваю iptables"
execute_command "iptables -t nat -A POSTROUTING -s 192.168.4.0/27 -o eth0 -j MASQUERADE"
execute_command "iptables-save > /root/rules"

echo "L1qued-SH: Настраиваю OSPF"
vtysh << EOF
conf t
router ospf
network 10.10.10.0/30 area 0
network 192.168.4.0/27 area 0
do wr mem
EOF

echo "L1qued-SH: Настраиваю GRE интерфейсы"
vtysh << EOF
conf t
int gre1
ip ospf authentication message-digest
ip ospf message-digest-key 1 md5 P@ssw0rd
do wr mem
EOF

echo "L1qued-SH: Проверка OSPF соседей"
vtysh -c "show ip ospf neighbor"

echo "L1qued-SH: Создаю пользователей"
execute_command "useradd net_admin -m"
echo "L1qued-SH: Устанавливаю пароль для пользователя net_admin"
echo "net_admin:P@\$\$word" | chpasswd

echo "L1qued-SH: Настраиваю службы"
execute_command "systemctl enable --now systemd-timesyncd"

execute_command "systemctl restart sshd"
execute_command "systemctl enable --now sshd"

echo "L1qued-SH: Добавляю правила перенаправления iptables"
execute_command "iptables -t nat -A PREROUTING -p tcp -d 192.168.4.1 --dport 80 -j DNAT --to-destination 192.168.4.2:8080"
execute_command "iptables -t nat -A PREROUTING -p tcp -d 192.168.4.1 --dport 2024 -j DNAT --to-destination 192.168.4.2:2024"
execute_command "iptables-save > /root/rules"

echo "L1qued-SH: Машина настроена"
echo "L1qued-SH: Отчистка истории ввода команд"
history -c

echo "L1qued-SH: Готово!"
