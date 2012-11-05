# ---+ Extensions
# ---++ SsoForwardCookiePlugin
# This plugin forwards credential cookies from the browser to external
# resources, when TWiki makes HTTP requests (e.g. %INCLUDE{"Intranet URL"}%).
# **STRING**
# Set the target domains (comma-separated) to which cookies are allowed to be
# forwarded. It must be the same as TWiki server's domain, or a superdomain
# with a dot prefix (e.g. ".example.com").
# Alternatively, if there are many domains that need to be listed, a topic name
# can be specified with a "topic:" prefix (e.g.
# "topic:%<nop>SYSTEMWEB%.SsoForwardCookieDomains") where variables with
# percent signs (%) are expanded.
$TWiki::cfg{Plugins}{SsoForwardCookiePlugin}{Domains} = '';
# **STRING**
# Set cookie names that are forwarded to any matched domains (comma-separated).
# Specify a single star (*) to forward all cookies (not recommended).
$TWiki::cfg{Plugins}{SsoForwardCookiePlugin}{CookieNames} = '';
# **BOOLEAN**
# Turn on the debug flag for troubleshooting and see the debug log.
$TWiki::cfg{Plugins}{SsoForwardCookiePlugin}{Debug} = 0;
1;
