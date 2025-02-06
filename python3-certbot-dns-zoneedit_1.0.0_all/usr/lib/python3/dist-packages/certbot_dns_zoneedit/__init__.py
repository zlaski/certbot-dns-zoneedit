"""
The `~certbot_dns_zoneedit.dns_zoneedit` plugin automates the process of
completing a ``dns-01`` challenge (`~acme.challenges.DNS01`) by creating, and
subsequently removing, TXT records using the ZoneEdit API.

.. note::
   The plugin is not installed by default. It can be installed by heading to
   `certbot.eff.org <https://certbot.eff.org/instructions#wildcard>`_, choosing your system and
   selecting the Wildcard tab.

Named Arguments
---------------

==========================================  ===================================
``--dns-zoneedit-credentials``              ZoneEdit credentials_ INI file.
                                            (Required)
``--dns-zoneedit-propagation-seconds``      The number of seconds to wait for
                                            DNS to propagate before asking the
                                            ACME server to verify the DNS
                                            record.
                                            (Default: 10)
==========================================  ===================================


Credentials
-----------

Use of this plugin requires a configuration file containing ZoneEdit API
credentials, obtained from your ZoneEdit account.  Please visit
`<https://cloud.zoneedit.com/settings/api/tokens>` for more information.

.. code-block:: ini
   :name: zoneedit.ini
   :caption: Example credentials file:

   # ZoneEdit API credentials used by Certbot
   dns_zoneedit_user = johnquser
   dns_zoneedit_token = 8F3E87C5183A1837

The path to this file can be provided interactively or using the
``--dns-zoneedit-credentials`` command-line argument. Certbot records the
path to this file for use during renewal, but does not store the file's contents.

.. caution::
   You should protect these API credentials as you would the password to your
   ZoneEdit account. Users who can read this file can use these credentials
   to issue arbitrary API calls on your behalf. Users who can cause Certbot to
   run using these credentials can complete a ``dns-01`` challenge to acquire
   new certificates or revoke existing certificates for associated domains,
   even if those domains aren't being managed by this server.

Certbot will emit a warning if it detects that the credentials file can be
accessed by other users on your system. The warning reads "Unsafe permissions
on credentials configuration file", followed by the path to the credentials
file. This warning will be emitted each time Certbot uses the credentials file,
including for renewal, and cannot be silenced except by addressing the issue
(e.g., by using a command like ``chmod 600`` to restrict access to the file).


Examples
--------

.. code-block:: bash
   :caption: To acquire a certificate for ``example.com``

   certbot certonly \\
     --dns-zoneedit \\
     --dns-zoneedit-credentials ~/.secrets/certbot/zoneedit.ini \\
     -d example.com

.. code-block:: bash
   :caption: To acquire a single certificate for both ``example.com`` and
             ``www.example.com``

   certbot certonly \\
     --dns-zoneedit \\
     --dns-zoneedit-credentials ~/.secrets/certbot/zoneedit.ini \\
     -d example.com \\
     -d www.example.com

.. code-block:: bash
   :caption: To acquire a wildcard certificate for ``*.example.com``

   certbot certonly \\
     --dns-zoneedit \\
     --dns-zoneedit-credentials ~/.secrets/certbot/zoneedit.ini \\
     -d example.com \\
     -d '*.example.com'

.. code-block:: bash
   :caption: To acquire a certificate for ``example.com``, waiting 60 seconds
             for DNS propagation

   certbot certonly \\
     --dns-zoneedit \\
     --dns-zoneedit-credentials ~/.secrets/certbot/zoneedit.ini \\
     --dns-zoneedit-propagation-seconds 60 \\
     -d example.com

"""
