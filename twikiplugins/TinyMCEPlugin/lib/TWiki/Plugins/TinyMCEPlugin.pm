
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

my $secret_id = 'TinyMCE WYSIWYG content - do not remove this comment';

sub initPlugin {
    return _isAvailable();
}

sub _isAvailable {
    my $disabled = TWiki::Func::getPreferencesValue(
        'TINYMCEPLUGIN_DISABLE');

    # Check the client browser to see if it is supported by TinyMCE
    my $query = TWiki::Func::getCgiQuery();
    if (!$query || $query->user_agent() &&
          $query->user_agent() =~ /(Konqueror|Opera)/i) {
        $disabled = 1;
    }

    return $disabled ? 0 : 1;
}

sub beforeEditHandler {
    #my ($text, $topic, $web) = @_;

    return unless _isAvailable();

    my $init = TWiki::Func::getPreferencesValue('TINYMCEPLUGIN_INIT')
      || <<'HERE';
'
HERE

    require TWiki::Plugins::WysiwygPlugin;

    # _src.js for debug
    TWiki::Func::addToHEAD('tinyMCE', <<SCRIPT);
<script language="javascript" type="text/javascript" src="%PUBURL%/%TWIKIWEB%/TinyMCEPlugin/tinymce/jscripts/tiny_mce/tiny_mce.js"></script>
<script type="text/javascript" src="%PUBURL%/%TWIKIWEB%/TinyMCEPlugin/twiki.js"></script>
<script type="text/javascript">
// <![CDATA[
function initTextArea () {
	textareaInited = true;
}
tinyMCE.init({ $init });
// ]]>
</script>
SCRIPT

    $_[0] = '<!--'.$secret_id.'-->'.
      TWiki::Plugins::WysiwygPlugin::TranslateTML2HTML($_[0]);

    TWiki::Func::getContext()->{textareas_hijacked} = 1;
}

sub afterEditHandler {
    #my( $text, $topic, $web ) = @_;

    return unless _isAvailable();

    my $query = TWiki::Func::getCgiQuery();
    return unless $query;
    # Check for our flag
    return unless $_[0] =~ s/<!--$secret_id-->//so;

    if ($TWiki::cfg{Plugins}{WysiwygPlugin}{Enabled}) {
        # if the wysiwyg plugin is enabled, we don't want to do anything
        # if wysiwyg_edit is enabled, as the WysiwygPlugin afterEditHandler
        # will deal with it.
        return if ($query->param( 'wysiwyg_edit' ));
        # otherwise wysiwygplugin isn't going to do anything, so we can
        # post-process.
    }

    require TWiki::Plugins::WysiwygPlugin;
    $_[0] = TWiki::Plugins::WysiwygPlugin::postProcess( @_ );
}

1;

