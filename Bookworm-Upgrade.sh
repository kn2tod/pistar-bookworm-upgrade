#!/bin/bash
# Upgrade Pi-Star Bullseye system to Bookworm in-place:
# 
# ref: <https://www.cyberciti.biz/faq/update-upgrade-debian-11-to-debian-12-bookworm/>
#
# Basic updates/changes:
#   1) change boot device for consistency with all current Raspbian systems;
#      remove obsolete cmdline.txt options; fix incorrect fstab options
#   2) remove UI option from APT packages; update APT packages to point to Bookworm archives
#   3) run the update/upgrade APT process
#   4) install PHP/FPM 8.2 (prior versions removed during upgrade?)
#   7) apply some minor fixes (broken in original installation or during upgrade)
#
# Assumptions:
#   Starting from a current Raspbian/Pi-Star BULLSEYE system: all applicable updates applied
#   Dormant system: system should not be actively running: mmdvm, cron, etc. i.e. Pi-Star should be "down"
#    (at a minimum, the NGINX, PISTAR-WATCHDOG, PISTAR-REMOTE, and MMDVMHOST tasks should be stopped)
#   python programs previously updated to spec
#   Tested on a fully-wired (ethernet) system
#
# Prelims:
#   If starting with a (working) fresh image:
#   - timezone may need to be set (e.g. sudo timedatectl set-timezone 'America/New_York')   # !!!!!!!
#     or set timezone/language in Pi-Star's config panel
#   - run Pi-Star's update/upgrade to bring app up-to-date
#   - run APT update/upgrade to bring system up-to-date
#
# Pre/Post-Install Anomalies:
#   1) Pi-Star's task to remount read-only at 17 past may need to be temporarily stopped
#   2) nano config parameters changed - need tweaking
#   3) bookworm change: ntp -> ntpsec?
#   4) expired keys update required?
#
# This process can be restarted from the top but with caution
#
# Testing: 
#   Rpi-4B, wired, USB, unconfigured new Pi-Star image
#
# ===========================================================================================================
#rpi-rw
q=${1:+"-qq"}       # invoke script with an argument ("x") to supress APT messages
t1=$SECONDS
echo "===============================> Start in-place Buster -> Bullseye update process:"
if [ ! "$(grep -i "bullseye\|bookworm" /etc/os-release)" ]; then
  echo "Only BULLSEYE/BOOKWORM systems can be upgraded"
  exit 1
fi
#
sudo mount -o remount,rw / ; sudo mount -o remount,rw /boot
#
sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 0E98404D386FA1D9
sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 6ED0E7B82643E131
#
# Change the cmdline file to be consistent with current Raspbian boots:
uuid=$(ls -la /dev/disk/by-partuuid | sed -n 's/^.* \([[:alnum:]]*-[0-9]* \).*/\1/p' | sed -n 's/\(.*\)-.*/\1/p' | head -n 1)
if [ ! "$(grep partuuid /boot/cmdline.txt)" ]; then   # (skip if this already made)
  sudo sed -i.bak "s|\/dev\/mmcblk0p2 |PARTUUID=$uuid-02 |g" /boot/cmdline.txt
# sudo sed -i.bak "s|\/dev\/mmcblk0p2 |PARTUUID=$uuid-02 |g; s| quiet | |g" /boot/cmdline.txt
  sudo sed -i.bak "s|\/dev\/mmcblk0p1\t|PARTUUID=$uuid-01|g" /etc/fstab
  sudo sed -i "s|\/dev\/mmcblk0p2\t|PARTUUID=$uuid-02|g" /etc/fstab
  sudo sed -i.bak "s/mmcblk0p2 /\x2e\x2a /g" /etc/bash.bashrc
  source /etc/bash.bashrc
  echo "===============================> boot code modified"
else
# fix up UUID's ??????  
  uuidx=$(sed -n 's/.*PARTUUID=\(.*\)-02.*/\1/p' /boot/cmdline.txt)
  if ["$uuid" != "$uuidx" ]; then
    echo "****** partition id mismatch! ******  ($uuid  $uuidx)"
#    sudo sed -i.bac "s/PARTUUID=${uuidx}/PARTUUID=${uuid}/g" /boot/cmdline.txt
#    sudo sed -i.bac "s/PARTUUID=${uuidx}/PARTUUID=${uuid}/g' /etc/fstab"
  fi
fi
#
sudo sed -i 's/ elevator=deadline / /g' /boot/cmdline.txt     # remove: no longer in use/supported
sudo sed -i 's/ noswap / /g' /boot/cmdline.txt                # remove: unknown kernel param
#sudo sed -i 's/.*$/& net.ifnames=0 biosdevname=0/g' /boot/cmdline.txt  # ref: <https://michlstechblog.info/blog/linux-disable-assignment-of-new-names-for-network-interfaces/>
sudo sed -i '/^tmpfs.*\/sys\/fs\/cgroup/,1 {s/,mode=1755,size=32m/\t\t/g}' /etc/fstab  # mode,size not allowed?
#
read -p "-- press any key to continue --" ipq
#
echo "===============================> Initial OS info:"
# ref: https://ostechnix.com/upgrade-to-debian-11-bullseye-from-debian-10-buster/
cat /etc/os-release
echo "==="
cat /etc/debian_version         # display current system/version
echo "==="
hostnamectl                     # display debian codename
#echo "==="
#lsb_release -a
echo "==="
uname -mrs
echo "==="
cat /boot/cmdline.txt
echo "==="
cat /etc/fstab
echo "==="
ls -la /etc/resolv.conf
#
read -p "-- press any key to continue --" ipq
#
echo "===============================> Make it up-to-date:"
if [ ! "$(grep bookworm /etc/apt/sources.list)" ]; then   # (skip if this proc has been restarted)
sudo mount -o remount,rw / ; sudo mount -o remount,rw /boot
sudo apt update
read -p "-- press any key to continue --" ipq
echo "==="
sudo mount -o remount,rw / ; sudo mount -o remount,rw /boot
sudo apt upgrade --fix-missing --fix-broken -y
read -p "-- press any key to continue --" ipq
#
echo "===============================> Cleanup:"
sudo mount -o remount,rw / ; sudo mount -o remount,rw /boot
sudo apt clean
sudo mount -o remount,rw / ; sudo mount -o remount,rw /boot
sudo apt autoremove -y
#
echo "===============================> Preliminary updates finished"
read -p "-- press any key to continue --" ipq
#
#sudo su                # make sure Pi-Star is update to date
#pistar-update
#
#mkdir ~/apt            # backup APT packages
#sudo cp /etc/apt/sources.list ~/apt
#sudo cp -rv /etc/apt/sources.list.d/ ~/apt
#
echo "===============================> Mod APT source lists for new OS:"
sudo mount -o remount,rw / ; sudo mount -o remount,rw /boot
sudo sed -i 's/bullseye/bookworm/g' /etc/apt/sources.list
sudo sed -i 's/bullseye/bookworm/g' /etc/apt/sources.list.d/*
#
# ref: https://forums.raspberrypi.com/viewtopic.php?t=318159 UI problem:
sudo sed -i 's/main ui/main # ui/g' /etc/apt/sources.list.d/raspi.list
#sudo mv /etc/apt/sources.list.d/stretch-backports.list /etc/apt/sources.list.d/buster-backports.list
sudo mv /etc/apt/sources.list.d/buster-backports.list /etc/apt/sources.list.d/bullseye-backports.list   # ?????
fi
#
echo "==="
cat /etc/apt/sources.list
echo "==="
cat /etc/apt/sources.list.d/raspi.list
echo "==="
#cat /lib/systemd/system/dhcpcd.service
#echo "==="
#cat /etc/systemd/system/dhcpcd.service.d/wait.conf
#echo "==="
#ls -la /etc/resolv.conf
#sudo cp -p /etc/resolv.conf /home/pi-star/resolv.conf.sav
#
# ===========================================================================================================
read -p "-- press any key to continue --" ipq
echo "===============================> Start OS update"
#sudo apt-mark hold dhcpcd5    # add per: https://github.com/pi-hole/pi-hole/issues/4051  ???
# ref: https://forums.raspberrypi.com/viewtopic.php?t=320383 DHCPCD problem:
# ref: https://blog.riton.fr/en-us/2021/10/raspberry-pi-dhcpcd-upgrade-break-raspbian-bullseye-network/
#echo "==="
sudo mount -o remount,rw / ; sudo mount -o remount,rw /boot
sudo apt update -y $q  # -q? -qq?
#echo "==="
#cat /lib/systemd/system/dhcpcd.service
read -p "-- press any key to continue --" ipq
echo "===============================> Start OS upgrade"
sudo mount -o remount,rw / ; sudo mount -o remount,rw /boot
#sudo apt upgrade --without-new-pkgs -y $q                 # reply "N" for all; -q? -qq?
sudo apt upgrade --without-new-pkgs --fix-missing --fix-broken -y $q                 # reply "N" for all; -q? -qq?
echo "==="
#cat /lib/systemd/system/dhcpcd.service
#echo "==="
#cat /etc/systemd/system/dhcpcd.service.d/wait.conf
#
echo "--Half-way there!"
read -p "--Complete upgrade? (Y/n)? " ipq
if [ "$ipq" == "Y" ]; then                 #  ${ipq^^}?
#
#echo "==="
#ls -la /etc/resolv.conf
#sudo ln -sf /var/lib/dhcpcd/resolv.conf /etc/resolv.conf
#sudo mkdir /var/lib/dhcpcd
#sudo cp /home/pi-star/resolv.conf.sav /var/lib/dhcpcd/resolv.conf
#sudo systemctl daemon-reload
#sudo systemctl restart dhcpcd.service
#echo "==="
#ls -la /etc/resolv.conf
#
#read -p "-- press any key to continue --" ipq
echo "===============================> Finish upgrade:"
sudo mount -o remount,rw / ; sudo mount -o remount,rw /boot
#sudo apt full-upgrade -y $q                 # reply "N" for all; tab-OK for all; -q? -qq?
sudo apt full-upgrade --fix-missing --fix-broken-y $q                 # reply "N" for all; tab-OK for all; -q? -qq?
read -p "-- press any key to continue --" ipq
#
echo "===============================> Cleanup:"
sudo mount -o remount,rw / ; sudo mount -o remount,rw /boot
sudo apt autoremove -y
sudo mount -o remount,rw / ; sudo mount -o remount,rw /boot
sudo apt clean
#
# ===========================================================================================================
read -p "-- press any key to continue --" ipq
echo "===============================> Install new PHP w/FPM:"
if [ ! -x /usr/bin/php8.2 ]; then
# ref: https://www.linuxcapable.com/how-to-install-php-7-4-on-debian-11-bullseye/
# ref: https://www.techrepublic.com/article/how-to-add-php-fpm-support-for-nginx-sites/
sudo mount -o remount,rw / ; sudo mount -o remount,rw /boot
sudo apt install php8.2          -y
sudo apt install php8.2-fpm      -y
sudo apt install php8.2-cli      -y
sudo apt install php8.2-mbstring -y
sudo apt install php8.2-zip      -y
#
sudo mount -o remount,rw / ; sudo mount -o remount,rw /boot
sudo sed -i "s/php7.4-/php8.2-/g" /etc/nginx/default.d/php.conf
echo "==="
cat /etc/nginx/default.d/php.conf
echo "==="
cat /lib/systemd/system/nginx.service
fi
#echo "Checking nginx config"
if ! [ $(cat /lib/systemd/system/nginx.service | grep -o "mkdir") ]; then
  sudo sed -i '\/PIDFile=\/run\/nginx.pid/a ExecStartPre=\/bin\/mkdir -p \/var\/log\/nginx' /lib/systemd/system/nginx.service
  sudo systemctl daemon-reload
# sudo systemctl restart nginx.service
  echo "nginx config repaired"
  cat /lib/systemd/system/nginx.service
fi
echo "==="
sudo mount -o remount,rw / ; sudo mount -o remount,rw /boot
sudo nginx -t                          # config check
sudo systemctl restart nginx           # restart just-in-case
sudo systemctl restart php8.2-fpm      # restart just-in-case
echo "==="
php --version                          # list current version info
echo "==="
pstree
read -p "-- press any key to continue --" ipq
echo "==============================> Re-install python2:"
#sudo apt install python -y
#sudo ln -fs /usr/bin/python2.7 /usr/bin/python    #  link generic python to 2.7
#echo "==============================> correct python3 issues:"
#sudo ln -fs /usr/bin/python3.9 /usr/bin/python    #  link generic python to 3.9
#sudo ln -fs /usr/bin/python3.11 /usr/bin/python   #  link generic python to 3.11
#
#sudo sed -i 's/ ConfigParser/ configparser/g' /usr/local/sbin/pistar-watchdog
#sudo sed -i 's/ ConfigParser/ configparser/g' /usr/local/sbin/pistar-remote
#
#sudo sed -i 's/^\x20\{8\}/\t/g'               /usr/local/sbin/pistar-watchdog
#sudo sed -i 's/^\x20\{8\}/\t/g'               /usr/local/sbin/pistar-remote
#sudo sed -i 's/^\x20\{8\}/\t/g'               /usr/local/sbin/pistar-keeper
#
#sudo sed -i '20,$ s/\x20\{8\}/\t/g'           /usr/local/sbin/pistar-watchdog
#sudo sed -i '20,$ s/\x20\{8\}/\t/g'           /usr/local/sbin/pistar-remote
#
#sudo sed -i 's/if "in checkprocremote:/in checkprocremote.decode():/g' pistar-watchdog
sudo python --version
#
# https://forums.raspberrypi.com/viewtopic.php?t=323583:
#sudo mv /lib/dhcpcd/dhcpcd-hooks/64-timesyncd.conf /lib/dhcpcd/dhcpcd-hooks/.64-timesyncd.conf
#
echo "==============================> misc system fixes:"
sudo mount -o remount,rw / ; sudo mount -o remount,rw /boot
if [ $(grep -c SystemCallFilter /lib/systemd/system/haveged.service) -lt 3 ]; then
  sudo sed -i 's/^SystemCallFilter/#SystemCallFilter/g'                                          /lib/systemd/system/haveged.service
  sudo sed -i 's/.*arch_prctl.*/&\nSystemCallFilter=@system-service\nSystemCallFilter=~@mount/g' /lib/systemd/system/haveged.service
fi
#
sudo sed -i 's/^#DAEMON.*/&\nDAEMON_ARGS="-w 1024 -d 16"/g'          /etc/default/haveged
sudo sed -i 's/^DAEMON_ARGS="-w 1024"/DAEMON_ARGS="-w 1024 -d 16"/g' /etc/default/haveged
#
sudo systemctl daemon-reload
sudo systemctl restart haveged.service
sudo systemctl status haveged.service
#
echo "==============================> Final OS info:"
cat /etc/os-release
echo "==="
cat /etc/debian_version
echo "==="
hostnamectl
#echo "==="
#lsb_release -a
echo "==="
uname -mrs
echo "==="
cat /boot/cmdline.txt
#
echo "==============================> /Boot info doc:"
sudo mount -o remount,rw / ; sudo mount -o remount,rw /boot
cd /boot
f=$(hostname).gen.txt
m1=$(tac $(ls -1t /var/log/pi-star/MMDVM-*.log 2>/dev/null) /dev/null | grep "protocol" -m 1 | sed -n "s|.*\(v[0-9]*\x2e[0-9]*\x2e[0-9]*\).*|\1|p")
m2=$(sed -n "/\[Modem\]/{n;p;}" /etc/dstar-radio.mmdvmhost | awk -F "=" '/Hardware/ {print $2}')
m3=$(hostnamectl 2>/dev/null | sed -n "s/.* System: .* (\([a-zA-Z0-9]*\))/\u\1/p")
#
sudo echo "Modified: $(date +%Y-%m-%d" "%H:%M:%S)" > $f
sudo echo "Software: $(sed -n 's|$version = \x27\([0-9]\{4\}\)\([0-9][0-9]\)\([0-9]*\)\x27;|\1/\2/\3|p' /var/www/dashboard/config/version.php)  Ver: $(sed -n 's/Version = \(.*\)/\1/p' /etc/pistar-release)  $m3: $(cat /etc/debian_version)  Kernel: $(uname -r)" >> $f
sudo echo "Hardware: ($(sed -n 's|^Model.*: Raspberry \(.*\)|\1|p' /proc/cpuinfo | sed 's/ Model //g' | sed 's/ Plus/+/g')) - Modem: $m1 ($m2) - Disk: ("$(blkid | sed -n 's/\/dev\/\(.*2\):.*/\1/p')")" >> $f
cat $f
#
#sudo mkdir /home/pi-star/.config      # deleted during update?!?
sudo mount -o remount,rw / ; sudo mount -o remount,rw /boot
sudo sed -i '/cron.daily/,/^mount/ s/mount -o remount,ro \/$/& || true/g' /etc/rc.local  # make sure script completes all steps
#
sudo sed -i 's/boot.log/bootx.log/g' /etc/logrotate.d/bootlog     # makes boot.log persistent
#
sudo sed -i 's/^PIDFile=/#PIDFile=/g' /lib/systemd/system/dstarrepeater.service  # PID seems unnecessary here
#
sudo sed -i 's/ExecStartPost=\//ExecStartPost=-\//g' /etc/systemd/system/apt-daily.service  # makes RO state conditional
#
sudo systemctl daemon-reload
#
#<https://unix.stackexchange.com/questions/633370/bash-needs-another-newline-to-execute-pasted-lines>
echo set enable-bracketed-paste off >> /home/pi-star/.
sudo chown pi-star:pi-star /home/pi-star
#
#--------------------------------------------------------------------------
read -p "-- press any key to continue --" ipq
#sudo apt-mark unhold dhcpcd5
#sudo umount /var/lib/dhcpcd5
#sudo apt upgrade -y
#sudo sed -i 's/^tmpfs\(.*\)\/var\/lib\/dhcpcd5\(.*\)/#tmpfs\1\/var\/lib\/dhcpcd5\2/g' /etc/fstab  # ????
#sudo sed -i 's/\/var\/lib\/dhcpcd5/\/var\/lib\/dhcpcd\t/g' /etc/fstab
#echo "==="
#cat /lib/systemd/system/dhcpcd.service
#echo "==="
#cat /etc/systemd/system/dhcpcd.service.d/wait.conf
#
sudo cp /etc/apt/trusted.gpg /etc/apt/trusted.gpg.d
# NANO deprecations in bookworm:
sudo sed -i 's/include.*mutt.nanorc/#&/g'   /etc/nanorc
sudo sed -i 's/include.*gentoo.nanorc/#&/g' /etc/nanorc
sudo sed -i 's/include.*pov.nanorc/#&/g'    /etc/nanorc
sudo sed -i 's/set suspend/#&/g'            /etc/nanorc
#
sudo apt install htop -y
sudo apt install lsof -y
sudo apt install bat  -y
# sudo apt install procinfo ntpstat ntpdate ntptime sysstat nmap lshw pydf
#
#sudo systemctl cat plymouth-start.service
#sudo sed -i 's/KillMode=none/KillMode=mixed/g' /lib/systemd/system/plymouth-start.service
#sudo systemctl daemon-reload
#
sudo touch -m --date="2020-01-20" /etc/fstab                                    # ?????
#
echo "==============================> End of Bullseye-Bookworm upgrade"
t2=$SECONDS
echo "--- (time to complete upgrade: " $(($t2-$t1)) "secs)"
#
#rpi-ro
sudo mount -o remount,ro / ; sudo mount -o remount,ro /boot   # may fail; can ignore
#
# By this point, system should be fully upgraded and operational; reboot if you want
read -p "--Recommended! Reboot (Y/n)? " ipq
if [ "$ipq" == "Y" ]; then
  history -a
  sudo reboot
fi
#
# sudo apt install update
# sudo apt upgrade --fix-missing --fix-broken -y
# sudo apt autoremove
# sudo apt clean
fi
#
# ===========================================================================================================
# Some usefull items to consider as part of base:
#sudo apt install ethtool ascii htop lsof procinfo tree ntpstat ntpdate ntptime sysstat nmap lsb-release dnsutils lshw pydf bat
#
#sudo apt-mark showhold
#sudo dpkg --get-selections | grep 'hold$'
#
# -- misc installation notes
# log of responses:
#  1) response during "upgrade w/o new pkgs":
#    etc/sudoers             80% progress
#    etc/nanorc              82%
#    etc/logrotate.conf      90%
#    etc/default/rcS         90%
#
#  2) responses during "full-upgrade":
#    etc/default/useradd     23% 
#    etc/logrotate.d/rsyslog 63%
#    etc/rsyslog.conf        63%
#    etc/nginx/nginx.conf    63%
#    TAB-OK: run/samba/upgrades/smb.conf
#    etc/default/dnsmasq     65%
#    etc/dnsmasq.conf        65%
#    etc/logrotate.d/exim4-base        80%
#    etc/logrotate.d/exim4-paniclog    80%
#    etc/sysctl.conf                   85%
#    TAB-OK: /tmp... --> etc/ssh/ssh.conf
#    TAB-OK: /usr/share/unattended-upgrades/50unattended-upgrades (cmt chg only?)
#    etc/cups/cups-browsed.conf  (only if installed)
#    etc/init.d/nmbd         99%
#    etc/init.d/smbd         99%
#
# Example boot doc:
#   Modified: 2022-06-05 10:35:19
#   Software: 2022/05/12  Ver: 4.1.6  Bullseye: 11.3  Kernel: 5.15.32-v7l+
#   Hardware: (Pi 4B Rev 1.1) - Modem:  () - Disk: (sda2)
