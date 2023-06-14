#!/bin/bash -x
sudo rm -rf /etc/letsencrypt/live/aki*
sudo certbot -v -a dns-zoneedit -i nginx --dns-zoneedit-propagation-seconds 120 \
    -m 'zlaski@ziemas.net' --agree-tos --non-interactive \
    -d 'akisystems.com' -d '*.akisystems.com'  -d '*.hcsv.akisystems.com'
