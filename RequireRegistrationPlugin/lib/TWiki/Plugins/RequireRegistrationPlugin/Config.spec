# ---+ Extensions
# ---++ RequireRegistrationPlugin
# **STRING 80**
# Comma-separated list of actions that this plugin should work on. If not
# defined, it will work on all actions. Example actions: 'attach, edit, login'
$TWiki::cfg{Plugins}{RequireRegistrationPlugin}{Actions} = '';
# **NUMBER**
# Refresh time in seconds to do a meta refresh redirect to the registration
# page. Specify -1 to use an immediate redirect CGI query.
$TWiki::cfg{Plugins}{RequireRegistrationPlugin}{Refresh} = 0;
# **BOOLEAN**
# Debug flag - see output in <code>twiki/data/debug.txt</code>.
$TWiki::cfg{Plugins}{RequireRegistrationPlugin}{Debug} = 0;
1;
