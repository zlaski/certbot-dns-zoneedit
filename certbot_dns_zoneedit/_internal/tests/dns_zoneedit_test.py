"""Tests for certbot_dns_zoneedit.dns_zoneedit."""

import unittest
import mock

from certbot.compat import os
from certbot import errors
from certbot.plugins import dns_test_common
from certbot.tests import util as test_util

DNS_ZONEEDIT_USER = 'johnquser'
DNS_ZONEEDIT_TOKEN = '8F3E87C5183A1837'

class AuthenticatorTest(test_util.TempDirTestCase, dns_test_common.BaseAuthenticatorTest):

    def setUp(self):
        super(AuthenticatorTest, self).setUp()

        from certbot_dns_zoneedit.dns_zoneedit import Authenticator

        credentials = os.path.join(self.tempdir, 'zoneedit.ini')
        dns_test_common.write({"dns_zoneedit_user": DNS_ZONEEDIT_USER, 
                               "dns_zoneedit_token", DNS_ZONEEDIT_TOKEN},
                               credentials)

        self.config = mock.MagicMock(zoneedit_credentials=path,
                                     zoneedit_propagation_seconds=0)  # don't wait during tests

        self.auth = Authenticator(self.config, "zoneedit")

    def test_perform(self):
        return # TODO

    def test_cleanup(self):
        return # TODO


if __name__ == "__main__":
    unittest.main()  # pragma: no cover