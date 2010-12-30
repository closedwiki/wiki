# ---+ Extensions
# ---++ AutoViewTemplate settings
# This is the configuration used by the <b>AutoViewTemplatePlugin</b>.

# **BOOLEAN**
# Turn on/off debugging in debug.txt
$TWiki::cfg{Plugins}{AutoViewTemplatePlugin}{Debug} = 0;

# **BOOLEAN**
# Template defined by form overrides existing VIEW_TEMPLATE or EDIT_TEMPLATE settings
$TWiki::cfg{Plugins}{AutoViewTemplatePlugin}{Override} = 0;

# **SELECT exist,section**
# How to find the view or edit template. 'exist' means the template name is derived from the name of the form definition topic. 'section' means the template name is defined in a section in the form definition topic.
$TWiki::cfg{Plugins}{AutoViewTemplatePlugin}{Mode} = 'exist';
