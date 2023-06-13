#!/bin/bash -x
sudo certbot certonly -v --dry-run -a dns-zoneedit --dns-zoneedit-propagation-seconds 120 \
    -d 'akisystems.com' -d '*.akisystems.com'  -d '*.hcsv.akisystems.com'
