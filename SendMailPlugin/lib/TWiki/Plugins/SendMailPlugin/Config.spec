# ---+ Extensions
# ---++ SendMailPlugin
# **STRING 60**
# E-mail address of sender. Supported tokens: 
# <ul><li> <code>$webmastername</code> - name of TWiki administrator. </li>
# <li> <code>$webmasteremail</code> - e-mail of TWiki administrator. </li>
# <li> <code>$username</code> - WikiName of logged in user. </li>
# <li> <code>$useremail</code> - e-mail address of the logged in user. </li></ul>
# Defaults to <code>$webmastername &lt;$webmasteremail&gt;</code><br />
# <b>Note:</b> See Security Note on Open Mail Relay in SendMailPlugin topic.
$TWiki::cfg{Plugins}{SendMailPlugin}{From} = '';
# **STRING 60**
# To list: Comma-space delimited list of e-mail addresses of adressees.
# Same tokens supported as in <code>{Plugins}{SendMailPlugin}{From}</code>.
# Defaults to <code>$webmastername &lt;$webmasteremail&gt;</code>
$TWiki::cfg{Plugins}{SendMailPlugin}{To} = '';
# **STRING 60**
# CC list: Comma-space delimited list of e-mail addresses.
# Same tokens supported as in <code>{Plugins}{SendMailPlugin}{From}</code>.
$TWiki::cfg{Plugins}{SendMailPlugin}{CC} = '';
# **STRING 60**
# BCC list: Comma-space delimited list of e-mail addresses.
# Same tokens supported as in <code>{Plugins}{SendMailPlugin}{From}</code>.
$TWiki::cfg{Plugins}{SendMailPlugin}{BCC} = '';
# **BOOLEAN**
# Debug flag - see output in <code>twiki/data/debug.txt</code>.
$TWiki::cfg{Plugins}{SendMailPlugin}{Debug} = 0;
1;
