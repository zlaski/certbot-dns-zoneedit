""" Certbot ZoneEdit DNS-01 auth plugins.


"""
from certbot import interfaces
from certbot.plugins import common

class Authenticator(dns_common.DNSAuthenticator):
    """Example Authenticator."""

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
                "zoneedit-user": "User ID of the owner of the DNS zone.",
                "zoneedit-token": "ZoneEdit-generated token for the DNS zone.",
            },
        )
        """ zoneedit.sh must live right alongside zoneedit.ini """
        self.script_file = os.path.abspath(__file__).rsplit( ".", 1 )[ 0 ]+".sh"
        self.zoneedit_user = self.credentials.conf("zoneedit-user")
        self.zoneedit_token = self.credentials.conf("zoneedit-token")

       
    def _perform(self, _domain: str, validation_name: str, validation: str) -> None:
        """
        Performs a dns-01 challenge by creating a DNS TXT record.

        :param str domain: The domain being validated.
        :param str validation_domain_name: The validation record domain name.
        :param str validation: The validation record content.
        :raises errors.PluginError: If the challenge cannot be performed
        """
        self.call_script("perform", _domain, validation_name, validation)

    def _cleanup(self, _domain: str, validation_name: str, validation: str) -> None:
        """
        Deletes the DNS TXT record which would have been created by `_perform_achall`.

        Fails gracefully if no such record exists.

        :param str domain: The domain being validated.
        :param str validation_domain_name: The validation record domain name.
        :param str validation: The validation record content.
        """
        self._call_script("cleanup", _domain, validation_name, validation)

    def _call_script(verb: str, domain_name: str, record_name: str, record_content: str)
        proc = subprocess.Popen([self.script_file, verb, _find_domain(domain_name), record_name, 
                                record_content, self.ttl, self.zoneedit_user, self.zoneedit_token],
                                shell=True, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        stdout, stderr = proc.communicate()

    def _find_domain(self, record_name: str) -> str:
        """
        Find the closest domain with an SOA record for a given domain name.

        :param str record_name: The record name for which to find the closest SOA record.
        :returns: The domain, if found.
        :rtype: str
        :raises certbot.errors.PluginError: if no SOA record can be found.
        """

        domain_name_guesses = dns_common.base_domain_name_guesses(record_name)

        # Loop through until we find an authoritative SOA record
        for guess in domain_name_guesses:
            if self._query_soa(guess):
                return guess

        raise errors.PluginError('Unable to determine base domain for {0} using names: {1}.'
                                 .format(record_name, domain_name_guesses))

