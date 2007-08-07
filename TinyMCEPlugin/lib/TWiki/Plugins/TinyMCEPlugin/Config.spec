# ---+ TinyMCE Plugin
# **STRING**
# The TinyMCEPlugin works by replacing standard textareas in TWiki screens
# with the TinyMCE editor. However this editor doesn't always cope with all
# TWiki syntax, so it can fall back to the default text editor if that syntax
# is seen in a topic. It takes the same values as the WYSIWYG_EXCLUDE TWiki
# variable (see TWiki.WysiwygPlugin for more details). If this option is
# undefined, then the editor will use the definition of the TWiki variable
# WYSIWYG_EXCLUDE to determine which (if any) content to exclude from WYSIWYG.
$TWiki::cfg{Plugins}{TinyMCEPlugin}{INIT} = '
 mode : "textareas",
 force_br_newlines : true,
 theme : "advanced",
 convert_urls : false,
 relative_urls : false,
 remove_script_host : false,
 plugins : "table,searchreplace",
 theme_advanced_buttons3_add : "search,replace",
 force_br_newlines : true,
 force_p_newlines : false,
 setupcontent_callback : "tinymce_plugin_setUpContent",
 init_instance_callback : "tinymce_plugin_addWysiwygTagToForm",
 theme_advanced_toolbar_align : "left",
 theme_advanced_buttons1 : "bold,italic,separator,bullist,numlist,separator,outdent,indent,separator,undo,redo,separator,link,unlink,removeformat,hr,visualaid,separator,sub,sup,separator,styleselect,formatselect,anchor,image,help,code,charmap",
 theme_advanced_buttons2: "",
 theme_advanced_buttons3: "",
 theme_advanced_toolbar_location: "top",
 theme_advanced_styles : "LINK=WYSIWYG_LINK;PROTECTED=WYSIWYG_PROTECTED;NOAUTOLINK=WYSIWYG_NOAUTOLINK;VERBATIM=WYSIWYG_VERBATIM",
 content_css : "%PUBURLPATH%/%TWIKIWEB%/TinyMCEPlugin/wysiwyg.css,%PUBURLPATH%/%TWIKIWEB%/TWikiTemplates/base.css,%PUBURLPATH%/%TWIKIWEB%/PatternSkin/style.css,%PUBURLPATH%/%TWIKIWEB%/PatternSkin/colors.css"
'
