""" Certbot ZoneEdit DNS-01 auth plugin.

As of 6 June 2023, the following API is available:

https://$dns_zoneedit_user:$dns_zoneedit_token@dynamic.zoneedit.com/txt-create.php?host=_acme-challenge.$domain_name&rdata=$dns01_challenge
https://$dns_zoneedit_user:$dns_zoneedit_token@dynamic.zoneedit.com/txt-delete.php?host=_acme-challenge.$domain_name&rdata=$dns01_challenge

The GET requests return information such as the following:

<ERROR CODE="708" TEXT="Login Failed: $dns_zoneedit_user" ZONE="_acme-challenge.$domain">

"""
from certbot import errors, interfaces
from certbot.plugins import common, dns_common
import requests
import logging

logger = logging.getLogger(__name__)


class Authenticator(dns_common.DNSAuthenticator):

    description = "Certbot DNS-01 authenticator plugin for ZoneEdit"


    def __init__(self, *args, **kwargs):
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
            default="/etc/letsencrypt/zeneedit.ini",
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
                "dns_zoneedit_user": "User ID of the owner of the DNS zone.",
                "dns_zoneedit_token": "ZoneEdit-generated token for the DNS zone.",
            },
        )
        self.zoneedit_user = self.credentials.conf("dns_zoneedit_user")
        self.zoneedit_token = self.credentials.conf("dns_zoneedit_token")
        logger.debug("self.zoneedit_user=%s", self.zoneedit_user)
        logger.debug("self.zoneedit_token=%s", self.zoneedit_token)

       
    def _perform(self, _domain: str, validation_name: str, validation: str) -> None:
        """
        Performs a dns-01 challenge by creating a DNS TXT record.

        :param str domain: The domain being validated.
        :param str validation_domain_name: The validation record domain name.
        :param str validation: The validation record content.
        :raises errors.PluginError: If the challenge cannot be performed
        """
        self._fetch_urlt("txt-create", _domain, validation_name, validation)


    def _cleanup(self, _domain: str, validation_name: str, validation: str) -> None:
        """
        Deletes the DNS TXT record previously created by _perform().
        Fails gracefully if no such record exists.

        :param str domain: The domain being validated.
        :param str validation_domain_name: The validation record domain name.
        :param str validation: The validation record content.
        """
        self._fetch_url("txt-delete", _domain, validation_name, validation)

    def _fetch_url(verb: str, domain_name: str, record_name: str, record_content: str)
        url = "https://dynamic.zoneedit.com/" + verb + ".php"
        payload = { 'host': domain_name, 'rdata': record_content }
        credentials = ( self.zoneedit_user, self.zoneedit_token )

        logger.debug("Getting %s [%s %s %s]", url, domain_name, record_name, record_content);
        
        r = requests.get(url, params=payload, auth=credentials)
        logger.debug("Returned code %d", p.status_code);
        logger.debug("\n%s", p.text);
        r.raise_for_status()
        

    def _find_domain(self, record_name: str) -> str:
        """
        Find the closest domain with an SOA record for a given domain name.

        :param str record_name: The record name for which to find the closest SOA record.
        :returns: The domain, if found.
        :rtype: str
        :raises certbot.errors.PluginError: if no SOA record can be found.
        """

        logger.debug("Guessing domain for %s", record_name);
        domain_name_guesses = dns_common.base_domain_name_guesses(record_name)

        # Loop through until we find an authoritative SOA record
        for guess in domain_name_guesses:
            if self._query_soa(guess):
                logger.debug("Guessed %s", guess);
                return guess

        raise errors.PluginError('Unable to determine base domain for {0} using names: {1}.'
                                 .format(record_name, domain_name_guesses))

