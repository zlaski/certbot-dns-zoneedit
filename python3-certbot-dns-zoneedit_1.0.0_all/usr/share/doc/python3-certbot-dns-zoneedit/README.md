certbot-dns-zoneedit
====================

[ZoneEdit](https://www.zoneedit.com/) DNS Authenticator plugin for [Certbot](https://certbot.eff.org/).

This plugin automates the process of completing a `DNS-01` challenge by creating, and subsequently removing, 
`TXT` records using the ZoneEdit API end-points.

Installation
------------

    pip install certbot-dns-zoneedit

Named Arguments
---------------

To start using DNS authentication for ZoneEdit, pass the following arguments on Certbot's command line:

Option|Description|
---|---|
`--authenticator dns-zoneedit`|Select the authenticator plugin (Required)|
`--dns-zoneedit-credentials FILE`|ZoneEdit credentials INI file. (Default is `/etc/letsencrypt/zoneedit.ini`)|
`--dns-zoneedit-propagation-seconds NUM`|How long to wait before veryfing the written `TXT` challenges. (Default is `120`)|

Credentials
-----------

Use of this plugin requires a configuration file containing your ZoneEdit user name and authentication token.  
The token can be obtained from the [ZoneEdit DynDNS settings](https://cp.zoneedit.com/manage/domains/dyn/) page.

An example `zoneedit.ini` file:

``` {.sourceCode .ini}
dns_zoneedit_user =   <login-user-id>
dns_zoneedit_token =  <dyn-authentication-token>
```

The default path to this file is set to `/etc/letsencrypt/zoneedit.ini`, but this can can be changed using the
`--dns-zoneedit-credentials` command-line argument.

**CAUTION:** You should protect these API credentials as you would the password to your ZoneEdit account 
(e.g., by using a command like `chmod 600` to restrict access to the file).

Examples
--------

To acquire a single certificate for both `example.com` and `*.example.com`, waiting 900 seconds for DNS propagation:

    certbot certonly \
      --authenticator dns-zoneedit \
      --dns-zoneedit-credentials ~/.secrets/certbot/zoneedit.ini \
      --dns-zoneedit-propagation-seconds 900 \
      --keep-until-expiring --non-interactive --expand \
      --server https://acme-v02.api.letsencrypt.org/directory \
      -d 'example.com' \
      -d '*.example.com'

Docker
------

You can build a docker image from source using the included `Dockerfile` or pull the latest version directly from Docker Hub:

    docker pull zlaski/certbot-dns-zoneedit

Once the installation is finished, the application can be run as follows:

    docker run --rm \
      -v /var/lib/letsencrypt:/var/lib/letsencrypt \
      -v /etc/letsencrypt:/etc/letsencrypt \
      --cap-drop=all \
      zlaski/certbot-dns-zoneedit certbot certonly \
        --authenticator dns-zoneedit \
        --dns-zoneedit-propagation-seconds 900 \
        --dns-zoneedit-credentials /var/lib/letsencrypt/zoneedit_credentials.ini \
        --keep-until-expiring --non-interactive --expand \
        --agree-tos --email "webmaster@example.com" \
        -d example.com -d '*.example.com'

Debian package
--------------

You can easily create a Debian package to install this plugin on a Debian 12 system (it should work with other versions too). Just run:

    dpkg-deb --build python3-certbot-dns-zoneedit_1.0.0_all

It creates the package `python3-certbot-dns-zoneedit_1.0.0_all.deb`. Install it on your server with:

    sudo dpkg -i python3-certbot-dns-zoneedit_1.0.0_all.deb

You must complete your ZoneEdi credentials in the `zoneedit.ini` file:

    sudo vi /etc/letsencrypt/zoneedit.ini

Ensure that everything is setup correctly with a dry run on Let's Encript's staging servers (don't forget to replace `example.com` by your domain):

    sudo certbot certonly --authenticator dns-zoneedit --cert-name example.com --domains example.com --domains '*.example.com' --dry-run

And then you can ask for a new certificate for your domains with something like:

    sudo certbot certonly --authenticator dns-zoneedit --cert-name example.com --domains example.com --domains '*.example.com' --non-interactive

Certbot on Debian systems is setup to renew automatically when the certificate is about to expire. You can check that everythin's fine with:

    sudo systemctl status certbot.timer
    sudo systemctl status certbot.service
    sudo certbot renew --dry-run
