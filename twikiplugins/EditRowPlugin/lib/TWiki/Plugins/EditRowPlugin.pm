# See bottom of file for copyright
package TWiki::Plugins::EditRowPlugin;

use strict;

use vars qw( $VERSION $RELEASE $SHORTDESCRIPTION $debug $pluginName $NO_PREFS_IN_TOPIC );

$VERSION = '$Rev$';
$RELEASE = '$Date$';
$SHORTDESCRIPTION = 'Single table row inline edit';

$NO_PREFS_IN_TOPIC = 1;

$pluginName = 'EditRowPlugin';

use vars qw($ADD_ROW $DELETE_ROW $QUIET_SAVE $NOISY_SAVE $EDIT_ROW);
$ADD_ROW = 'Add Row';
$DELETE_ROW = 'Delete Row';
$QUIET_SAVE = 'Quiet Save';
$NOISY_SAVE = 'Save';
$EDIT_ROW = 'Edit';

sub initPlugin {
    my( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.1 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    TWiki::Func::registerRESTHandler('save', \&save);

    # Plugin correctly initialized
    return 1;
}

# Handler run when viewing a topic
sub commonTagsHandler {
    # my ( $text, $topic, $web ) = @_;

    return unless
      TWiki::Func::getPreferencesValue('ENABLE_TABLE_ROW_EDIT');

    return unless $_[0] =~ /%EDITTABLE{(.*?)}%/;

    my ($topic, $web) = ($_[1], $_[2]);

    require TWiki::Plugins::EditRowPlugin::Table;
    return if $@;

    my $content = TWiki::Plugins::EditRowPlugin::Table::parseTables(@_);

    $_[0] =~ s/\\\n//gs;

    my $query = TWiki::Func::getCgiQuery();

    return unless $query;

    my $urps = $query->Vars();
    $urps->{active_table} ||= 0;
    $urps->{active_row} ||= 0;

    my $nlines = '';
    my $table = undef;
    my $active_table = 0;

    foreach my $line (@$content) {
        if (ref($line) eq 'TWiki::Plugins::EditRowPlugin::Table') {
            $table = $line;
            $active_table++;
            if ($active_table == $urps->{active_table}) {
                my $saveUrl =
                  TWiki::Func::getScriptUrl($pluginName, 'save', 'rest');
                $line = <<HTML;
<form name='roweditform_$active_table' method='post' action='$saveUrl'>
<input type="hidden" name="topic" value="$web.$topic" />
<input type="hidden" name="active_table" value="$active_table" />
<input type="hidden" name="active_row" value="$urps->{active_row}" />
HTML
                $line .= $table->renderForEdit($urps->{active_row});
                $line .= "\n</form>";
            } else {
                $line = $table->renderForDisplay();
            }
            $table->finish();
        }
        $nlines .= "$line\n";
    }
    $_[0] = $nlines;
}

# REST handler for table row edit save. Supports all four functions
sub save {
    my $query = TWiki::Func::getCgiQuery();

    return unless $query;

    my $saveType = $query->param('editrowplugin_save') || '';
    my ($web, $topic) = TWiki::Func::normalizeWebTopicName(
        undef, $query->param('topic'));

    my ($meta, $text) = TWiki::Func::readTopic($web, $topic);
    my $url;
    if (!TWiki::Func::checkAccessPermission(
        'CHANGE', TWiki::Func::getWikiName(), $text, $topic, $web, $meta)) {
        $url = TWiki::Func::getOopsUrl(
            $web, $topic, 'oopsaccessdenied',
            'accessdenied', 'param2', 'param3');
    } else {
        $text =~ s/\\\n//gs;
        require TWiki::Plugins::EditRowPlugin::Table;
        die $@ if $@;
        my $content = TWiki::Plugins::EditRowPlugin::Table::parseTables(
            $text, $topic, $web);

        my $urps = $query->Vars();

        my $nlines = '';
        my $table = undef;
        my $active_table = 0;

        my $action;
        if ($saveType =~ /^($QUIET_SAVE|$NOISY_SAVE)$/o) {
            $action = 'changeRow';
        } elsif ($saveType eq $ADD_ROW) {
            $action = 'addRow';
        } elsif ($saveType eq $DELETE_ROW) {
            $action = 'deleteRow';
        }

        foreach my $line (@$content) {
            if (ref($line) eq 'TWiki::Plugins::EditRowPlugin::Table') {
                $table = $line;
                $active_table++;
                if ($active_table == $urps->{active_table}) {
                    $line = $table->$action($urps);
                } else {
                    $line = $table->stringify();
                }
                $table->finish();
            }
            $nlines .= "$line\n";
        }
        TWiki::Func::saveTopic($web, $topic, $meta, $nlines,
                                { minor => 1 });

        $url = TWiki::Func::getScriptUrl($web, $topic, 'view');
    }
    TWiki::Func::redirectCgiQuery(undef, $url);
    return 0;
}

1;
__END__

Author: Crawford Currie http://c-dot.co.uk

Copyright (C) 2007 WindRiver Inc. and TWiki Contributors.
All Rights Reserved. TWiki Contributors are listed in the
AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

Do not remove this copyright notice.

This plugin supports editing of a table row-by-row.

It uses a fairly generic table object, and employs a REST handler
for saving.
