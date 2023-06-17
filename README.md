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
