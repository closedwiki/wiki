#---+ Extensions
#---++ AttachContentPlugin
# **BOOLEAN**
# Enable debugging (debug messages will be written to data/debug.txt)
$TWiki::cfg{Plugins}{AttachContentPlugin}{Debug} = 0;
# **BOOLEAN**
# By default, keep paragraph <code>&lt;p /&gt;</code> tags, <code>&lt;nop&gt;</code> tags, and square bracket type links (can be specified for each <code>ATTACHCONTENT</code> separately).
$TWiki::cfg{Plugins}{AttachContentPlugin}{KeepPars} = 0;
# **STRING 200**
# The default comment text that will be added to saved attachments.
$TWiki::cfg{Plugins}{AttachContentPlugin}{AttachmentComment} = 'Generated by <nop>AttachContentPlugin';
# **BOOLEAN**
# Flag to do/not do action in view, default set to not save during topic view. </br>
# Note, this behavior can be overriden using a =attachonview= parameter each time the directive is used. 
# If this flag is enabled, attachments are saved every time on page view which could
# <ul>
# <li>    slow down page views,
# <li>    increase server load,
# <li>    make pages look updated even if there is no update (recent changes and e-mail notification),
# <li>    save pages regardless of access control (for example as TWikiGuest if not logged in).
# </ul> 
$TWiki::cfg{Plugins}{AttachContentPlugin}{AttachOnView} = 0;
