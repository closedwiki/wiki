#---+ Update Attachments Plugin
# **BOOLEAN**
# remove references to attachments that no longer exist in pub
$TWiki::cfg{Plugins}{UpdateAttachmentsPlugin}{RemoveMissing} = $FALSE;
# **BOOLEAN**
# use the _internal_ _noHandlersSave - this may break in future if the internal method is changed
# not recomended unless you know the code.
$TWiki::cfg{Plugins}{UpdateAttachmentsPlugin}{UseDangerousNoHandlersSave} = $FALSE;