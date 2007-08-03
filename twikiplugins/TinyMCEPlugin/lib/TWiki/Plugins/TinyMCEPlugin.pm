
# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html

package TWiki::Plugins::TinyMCEPlugin;

use strict;

use vars qw( $VERSION $RELEASE $SHORTDESCRIPTION );

$VERSION = '$Rev$';
$RELEASE = 'TWiki-4';
$SHORTDESCRIPTION = 'Integration of TinyMCE with WysiwygPlugin';

use TWiki::Func;

sub initPlugin {
    return 1;
}

sub beforeEditHandler {
    #my ($text, $topic, $web) = @_;

    my $query = TWiki::Func::getCgiQuery();

    require TWiki::Plugins::WysiwygPlugin;
#    return unless TWiki::Plugins::WysiwygPlugin::isWysiwygEditable(
#        $_[0], $TWiki::cfg{Plugins}{TinyMCEPlugin}{EXCLUDE});

    # SMELL: why do we need twiki.js?
    # _src.js for debug
    TWiki::Func::addToHEAD('tinyMCE', <<SCRIPT);
<script language="javascript" type="text/javascript" src="%PUBURLPATH%/%TWIKIWEB%/TinyMCEPlugin/tinymce/jscripts/tiny_mce/tiny_mce_src.js"></script>
<script type="text/javascript" src="%PUBURLPATH%/%TWIKIWEB%/TinyMCEPlugin/twiki.js"></script>
<script type="text/javascript">
// <![CDATA[
tinyMCE.init({
 mode : "textareas",
 force_br_newlines : true,
 theme : "advanced",
// theme_advanced_disable: "strikethrough,justifyleft,justifyright,justifycenter,justifyfull,cleanup,sub,sup,anchor,charmap,removeformat,separator,styleselect,visualaid,hr",
 gecko_spellcheck : true,
 convert_urls : false,
 relative_urls : false,
 remove_script_host : false,
 plugins : "table,searchreplace",
 theme_advanced_buttons3_add : "search,replace",
 //theme_advanced_layout_manager : "RowLayout",
 setupcontent_callback : "tinymce_plugin_setUpContent",
 init_instance_callback : "tinymce_plugin_addWysiwygTagToForm",
 theme_advanced_toolbar_align : "left",
 theme_advanced_buttons1 : "bold,italic,separator,bullist,numlist,separator,outdent,indent,separator,undo,redo,separator,link,unlink,removeformat,hr,visualaid,separator,sub,sup,separator,styleselect,formatselect,anchor,image,help,code,charmap",
 theme_advanced_buttons2: "",
 theme_advanced_buttons3: "",
 theme_advanced_toolbar_location: "top",
 theme_advanced_styles : "LINK=WYSIWYG_LINK;PROTECTED=WYSIWYG_PROTECTED;NOAUTOLINK=WYSIWYG_NOAUTOLINK;VERBATIM=WYSIWYG_VERBATIM",
 content_css : "%PUBURLPATH%/%TWIKIWEB%/TinyMCEPlugin/wysiwyg.css,%PUBURLPATH%/%TWIKIWEB%/TWikiTemplates/base.css,%PUBURLPATH%/%TWIKIWEB%/PatternSkin/style.css,%PUBURLPATH%/%TWIKIWEB%/PatternSkin/colors.css"
});
// ]]>
</script>
SCRIPT

    $_[0] = TWiki::Plugins::WysiwygPlugin::TranslateTML2HTML($_[0]);
}
sub afterEditHandler {
    #my( $text, $topic, $web ) = @_;
    my $query = TWiki::Func::getCgiQuery();
    return unless $query;
    return if $query->{wysiwyg_blocked};
    $query->{wysiwyg_blocked} = 1;
    require TWiki::Plugins::WysiwygPlugin;
    TWiki::Plugins::WysiwygPlugin::_postProcess( @_ );
}

1;

