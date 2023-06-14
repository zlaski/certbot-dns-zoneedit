#!/bin/bash

sudo apt upgrade -y || exit 1
sudo apt install --reinstall automake autoconf || exit 1

pushd ~/git
git clone https://github.com/ddclient/ddclient    # may fail
cd ddclient || exit 1
git remote add upstream https://github.com/ddclient/ddclient    # may fail
git fetch upstream || exit 1

./autogen || exit 1
./configure --prefix=/usr --bindir=/usr/sbin --sbindir=/usr/sbin --sysconfdir=/etc --localstatedir=/var || exit 1
make || exit 1
make VERBOSE=1 check || exit 1
sudo make install || exit 1
sudo cp sample-etc_systemd.service /etc/systemd/system/ddclient.service || exit 1

sudo cat <<EOF >/etc/ddclient.conf || exit 1
# /etc/ddclient.conf for akisystems.com
protocol=zoneedit1
daemon=666

zone=akisystems.com \
use=web, web=http://dynamic.zoneedit.com/checkip.html \
login=zlaski, password='8F11B2E318331836' \
mail-failure=zlaski@ziemas.net \
akisystems.com,*.akisystems.com,*.hcsv.akisystems.com
EOF

sudo systemctl enable ddclient.service || exit 1
sudo systemctl start ddclient.service || exit 1
sudo systemctl status ddclient.service || exit 1
popd

sudo apt install --reinstall snapd || exit 1
sudo snap install core || exit 1
sudo snap refresh core || exit 1

sudo apt purge certbot -y || exit 1
sudo snap install --classic certbot || exit 1
sudo ln -sf /snap/bin/certbot /usr/bin/certbot || exit 1
sudo snap set certbot trust-plugin-with-root=ok || exit 1

sudo apt install --reinstall python3-pip
sudo certbot plugins --init || exit 1

pushd ~/git
git clone https://github.com/zlaski/certbot-dns-zoneedit    # may fail
cd certbot-dns-zoneedit || exit 1
git fetch origin || exit 1
sudo python3 -m pip install --upgrade . || exit 1
popd
