""" Certbot ZoneEdit DNS-01 auth plugin. """

from certbot import errors, interfaces
from certbot.plugins import common, dns_common
import requests
import logging
import dns.resolver
import json
import time

logger = logging.getLogger(__name__)

CREATE_URL = "https://dynamic.zoneedit.com/txt-create.php"
DELETE_URL = "https://dynamic.zoneedit.com/txt-delete.php"

class Authenticator(dns_common.DNSAuthenticator):

    description = "Certbot DNS-01 authenticator plugin for ZoneEdit"


    def __init__(self, *args, **kwargs):
        logger.debug("__init__: %s", self)
        super(Authenticator, self).__init__(*args, **kwargs)
        self.credentials = None


    @classmethod
    def add_parser_arguments(cls, add):  # pylint: disable=arguments-differ
        super(Authenticator, cls).add_parser_arguments(
            add, default_propagation_seconds=120
        )
        add(
            "credentials",
            help="ZoneEdit credentials INI file.",
            default="/etc/letsencrypt/zoneedit.ini",
        )


    def more_info(self):
        return (
            "This plugin configures a DNS TXT record to respond to a DNS-01 challenge using "
            + "the ZoneEdit API."
        )


    def _setup_credentials(self):
        self.credentials = self._configure_credentials(
            "credentials",
            "ZoneEdit credentials INI file",
            {
                "user": "User ID of the owner of the DNS zone.",
                "token": "ZoneEdit-generated token for the DNS zone.",
            },
        )
        self.zoneedit_user = self.credentials.conf("user")
        self.zoneedit_token = self.credentials.conf("token")
        logger.debug("self.zoneedit_user=%s", self.zoneedit_user)
        logger.debug("self.zoneedit_token=%s", self.zoneedit_token)
        self.zoneedit_login = ( self.zoneedit_user, self.zoneedit_token )


    def _perform(self, domain: str, validation_domain_name: str, validation: str) -> None:
        """
        Performs a dns-01 challenge by creating a DNS TXT record.

        :param str domain: The domain being validated.
        :param str validation_domain_name: The validation record domain name.
        :param str validation: The validation record content.
        :raises errors.PluginError: If the challenge cannot be performed
        """

        self._cleanup(domain, validation_domain_name, validation)

        logger.debug("_perform: %s", validation_domain_name)

        payload = { 'host': validation_domain_name, 'rdata': validation }
        r = requests.get(CREATE_URL, params=payload, auth=self.zoneedit_login)

        logger.debug(r.text)
        time.sleep(10)
        r.raise_for_status()


    def _cleanup(self, domain: str, validation_domain_name: str, validation: str) -> None:
        """
        Deletes the DNS TXT record(s) previously created by _perform().
        Fails gracefully if no such record exists.

        :param str domain: The domain being validated.
        :param str validation_domain_name: The validation record domain name.
        :param str validation: The validation record content.
        """

        logger.debug("_cleanup: %s", validation_domain_name)

        answers = dns.resolver.query(validation_domain_name, 'TXT', raise_on_no_answer = False)
        logger.debug(answers.response)

        for rdata in answers:
            for rdataval in rdata.strings:
                payload = { 'host': validation_domain_name, 'rdata': rdataval }
                r = requests.get(DELETE_URL, params=payload, auth=self.zoneedit_login)

                logger.debug(r.text)
                time.sleep(10)
