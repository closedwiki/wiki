# ---+ Extensions
# ---++ PublishWebPlugin
# All path settings may include these variables:
# <br />&#8226;
# <code>%WEB%</code> - name of the publish web
# <br />&#8226; 
# <code>%LCWEB%</code> - lower case name of the publish
# web (preferred over mixed case)
# <br />&#8226;
# <code>%SKIN%</code> - name of the publish skin
# **PATH**
# Template path where skin files are located:
# <br />&#8226;
# If empty or omitted: the <code>twiki/templates</code> directory is
# assumed; normal TWiki.TWikiTemplates search path applies, e.g. for
# a <code>PUBLISHSKIN = website</code> setting, a
# <code>twiki/templates/view.website.tmpl</code> template file is
# assumed.
# <br />&#8226;
# If specified: Must be an absolute path; skin is assumed
# to be an html page at that location, e.g. for a
# <code>PUBLISHSKIN = website</code> setting, the
# <code>{Plugins}{PublishWebPlugin}{TemplatePath}/website.html</code>
# file is referenced.
$TWiki::cfg{Plugins}{PublishWebPlugin}{TemplatePath} = '';
# **PATH M**
# Path where the plugin places the generated html files. Specify
# an absolute or relative path.
# <br />&#8226; 
# If relative, path is relative to <code>twiki/pub</code>, such as
# <code>'../../html'</code>.
# <br />&#8226; 
# Example to publish to multiple virtual hosts, one for each publish web:
# <code>'/var/www/vhosts/%LCWEB%/html'</code>.
$TWiki::cfg{Plugins}{PublishWebPlugin}{PublishPath} = '/path/to/apache/html';
# **STRING 40**
# Path where the plugin places images and other topic attachments.
# Must be relative to <code>{Plugins}{PublishWebPlugin}{PublishPath}</code>,
# default is <code>'_publish'</code>.
$TWiki::cfg{Plugins}{PublishWebPlugin}{AttachPath} = '_publish';
# **STRING 40**
# URL path that corresponds to <code>{PublishPath}</code> directory. Leave
# empty if it is the HTML document root.
$TWiki::cfg{Plugins}{PublishWebPlugin}{PublishUrlPath} = '';
# **BOOLEAN**
# Debug flag - see output in <code>twiki/data/debug.txt</code>.
$TWiki::cfg{Plugins}{PublishWebPlugin}{Debug} = 0;
1;
