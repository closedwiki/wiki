# ---+ TinyMCE Plugin
# **STRING**
# The TinyMCEPlugin works by replacing standard textareas in TWiki screens
# with the TinyMCE editor. However this editor doesn't always cope with all
# TWiki syntax, so it can fall back to the default text editor if that syntax
# is seen in a topic. It takes the same values as the WYSIWYG_EXCLUDE TWiki
# variable (see TWiki.WysiwygPlugin for more details). If this option is
# undefined, then the editor will use the definition of the TWiki variable
# WYSIWYG_EXCLUDE to determine which (if any) content to exclude from WYSIWYG.
$TWiki::cfg{Plugins}{TinyMCEPlugin}{EXCLUDE} = 'calls';
