sudo nmcli con add con-name "static-ip" ifname enp114s0 type ethernet ip4 192.168.1.28/24 gw4 125.253.106.1
nmcli con mod "static-ip" ipv4.dns "8.8.8.8,8.8.4.4"
nmcli con mod "static-ip" ipv4.method manual
nmcli con up "static-ip" ifname enp114s0
nmcli con show