echo "L1qued-SH: Копирую папки config файлов..."
# cp -r / /
# cp -r / /
# cp -r / /

sleep 1

echo "L1qued-SH: Устанавливаю hostname и временной зоны"
hostnamectl set-hostname hq-rtr.au-team.irpo; exec bash
timedatectl set-timezone Asia/Yekaterinburg

sleep 1

echo "L1qued-SH: Настраиваю iptables"
iptables -t nat -A POSTROUTING -s 192.168.1.0/26 -o eth0 -j MASQUERADE
iptables -t nat -A POSTROUTING -s 192.168.2.0/28 -o eth0 -j MASQUERADE
iptables -t nat -A POSTROUTING -s 192.168.3.0/29 -o eth0 -j MASQUERADE
iptables-save > /root/rules

sleep 2

echo "L1qued-SH: Настраваю OSPF"
vtysh << EOF
conf t
router ospf
network 10.10.10.0/30 area 0
network 192.168.1.0/26 area 0
network 192.168.2.0/28 area 0
network 192.168.3.0/29 area 0
do wr mem
exit
exit
EOF

sleep 1

echo "L1qued-SH: Настраиваю OSPF аутентификации"
vtysh << EOF
conf t
int gre1
ip ospf authentication message-digest
ip ospf message-digest-key 1 md5 P@ssw0rd
do wr mem
exit
exit
EOF

sleep 1

echo "L1qued-SH: Создаю пользователя net_admin"
useradd net_admin -m
echo "L1qued-SH: Устанавливаю пароль для net_admin"
echo "net_admin:P@\$\$word" | chpasswd

echo "L1qued-SH: Настраиваю chrony"
systemctl enable --now chrony

sleep 3

systemctl restart chrony

sleep 3

timedatectl set-ntp 0

echo "L1qued-SH: Настраиваю SSH"
systemctl restart sshd

sleep 3

systemctl enable --now sshd

sleep 3

echo "L1qued-SH: Добавляю DNAT правила"
iptables -t nat -A PREROUTING -p tcp -d 192.168.1.1 --dport 2024 -j DNAT --to-destination 192.168.1.2:2024
iptables-save > /root/rules

# Настройка nginx
echo "L1qued-SH: Настраиваю nginx"
rm -rf /etc/nginx/sites-available/default
rm -rf /etc/nginx/sites-enabled/default
ln -s /etc/nginx/sites-available/proxy /etc/nginx/sites-enabled
systemctl restart nginx

sleep 3

echo "L1qued-SH: Машина настроена!"
echo "L1qued-SH: Отчистка истории ввода команд"

history -c
echo "L1qued-SH: Готово"
