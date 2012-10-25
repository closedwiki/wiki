# ---+ Extensions
# ---++ SingleSignOnPlugin
# This plugin forwards credentials from the browser to external intranet
# resources, when TWiki makes HTTP requests (e.g. %INCLUDE{"Intranet URL"}%).
# Currently, only cookie-based SSO is supported.
# **STRING H**
$TWiki::cfg{HTTPRequestHandler} = 'TWiki::Plugins::SingleSignOnPlugin::HTTPRequestHandler';
# **STRING**
# Set the single sign-on target domains (comma-separated).
# It must be the same as TWiki server's domain, or a superdomain with a dot prefix.
$TWiki::cfg{Plugins}{SingleSignOnPlugin}{Domains} = '';
# **STRING**
# Set cookie names that are forwarded to any matched domains (comma-separated).
# Specify a single start (*) to forward all cookies (not recommended).
$TWiki::cfg{Plugins}{SingleSignOnPlugin}{ForwardedCookieNames} = '';
# **BOOLEAN**
# Turn on the debug flag for troubleshooting and see the debug log.
$TWiki::cfg{Plugins}{SingleSignOnPlugin}{Debug} = 0;
1;
