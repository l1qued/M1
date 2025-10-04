#!/bin/bash

echo "L1qued-SH: Настраиваю hostnamectl"
hostnamectl set-hostname hq-cli.au-team.irpo
echo "L1qued-SH: Настраиваю часовой пояс"
timedatectl set-timezone Asia/Yekaterinburg

echo "L1qued-SH: Настраиваю VLAN"
mkdir -p /etc/net/ifaces/enp0s3.200

cat > /etc/net/ifaces/enp0s3.200/options << EOF
TYPE=vlan
VID=200
HOST=enp0s3
DISABLED=no
BOOTPROTO=dhcp
EOF

echo "L1qued-SH: Перезапускаю службу сети"
systemctl restart network

echo "L1qued-SH: Устанавливаю и настраиваю NFS клиент"
apt update
apt install nfs-common -y

mkdir -p /mnt/nfs
echo "192.168.1.2:/raid5/nfs /mnt/nfs nfs intr,soft,_netdev,x-systemd.automount 0 0" >> /etc/fstab
mount -a

echo "L1qued-SH: Создаю и настраиваю учетную запись sshuser"
useradd sshuser -u 1010
echo "sshuser:P@ssw0rd" | chpasswd
echo "WHEEL_USERS ALL=(ALL:ALL) NOPASSWD: ALL" >> /etc/sudoers
usermod -aG wheel sshuser

echo "L1qued-SH: Устанавливаю и настраиваю SSH"
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

echo "L1qued-SH: Устанавливаю Python для Ansible"
apt install python3 python3-pip -y

echo "L1qued-SH: Устанавливаю Yandex Browser"
apt update
apt install yandex-browser-stable -y

echo "L1qued-SH: Машина настроена!"
echo "L1qued-SH: Отчистка истории ввода команд"

history -c
echo "L1qued-SH: Готово"
