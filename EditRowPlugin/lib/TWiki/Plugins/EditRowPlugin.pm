# See bottom of file for copyright
package TWiki::Plugins::EditRowPlugin;

use strict;

use vars qw( $VERSION $RELEASE $SHORTDESCRIPTION $debug $pluginName $NO_PREFS_IN_TOPIC );

$VERSION = '$Rev$';
$RELEASE = '$Date$';
$SHORTDESCRIPTION = 'Single table row inline edit';

$NO_PREFS_IN_TOPIC = 1;

$pluginName = 'EditRowPlugin';

use vars qw($ADD_ROW $DELETE_ROW $QUIET_SAVE $NOISY_SAVE $EDIT_ROW $CANCEL_ROW);
$ADD_ROW = 'Add Row';
$DELETE_ROW = 'Delete Row';
$QUIET_SAVE = 'Quiet Save';
$NOISY_SAVE = 'Save';
$EDIT_ROW = 'Edit';
$CANCEL_ROW = 'Cancel';

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
    # my ( $text, $topic, $web, $meta ) = @_;

    my $query = TWiki::Func::getCgiQuery();
    return unless $query;

    my $context = TWiki::Func::getContext();
    return unless $context->{view};

    # SMELL: hack to get around not having a proper topic object model
    my $meta = $_[3] || $context->{can_render_meta};
    return unless $meta;

    return unless $_[0] =~ /%EDITTABLE{(.*?)}%/;

    my ($topic, $web) = ($_[1], $_[2]);

    require TWiki::Plugins::EditRowPlugin::Table;
    return if $@;

    my $content = TWiki::Plugins::EditRowPlugin::Table::parseTables(@_);

    $_[0] =~ s/\\\n//gs;

    my $urps = $query->Vars();
    $urps->{erp_active_table} ||= 0;
    $urps->{erp_active_row} ||= 0;

    my $nlines = '';
    my $table = undef;
    my $active_table = 0;

    my $displayOnly = 0;

    unless (TWiki::Func::checkAccessPermission(
        'CHANGE', TWiki::Func::getWikiName(), $_[0], $topic, $web, $meta)) {
        $displayOnly = 1;
    }

    foreach my $line (@$content) {
        if (ref($line) eq 'TWiki::Plugins::EditRowPlugin::Table') {
            $table = $line;
            $active_table++;
            if (!$displayOnly && $active_table == $urps->{erp_active_table}) {
                my $active_row = $urps->{erp_active_row};
                my $saveUrl =
                  TWiki::Func::getScriptUrl($pluginName, 'save', 'rest');
                $line = CGI::start_form(
                    -method=>'POST',
                    -name => 'erp_form_'.$active_table,
                    -action => $saveUrl);
                $line .= CGI::hidden('erp_active_topic', "$web.$topic");
                $line .= CGI::hidden('erp_active_table', $active_table);
                $line .= CGI::hidden('erp_active_row', $active_row);
                my $format = $table->{attrs}->{format};
                # SMELL: Have to double-encode the format param to defend it
                # against the rest of TWiki. We use the escape char '-' as it
                # isn't used by TWiki.
                $format =~ s/([][@\s%!:-])/sprintf('-%02x',ord($1))/ge;
                # it will get encoded again as a URL param
                $line .= CGI::hidden('erp_active_format', $format);
                $line .= "\n".$table->renderForEdit($active_row)."\n";
                $line .= CGI::end_form();
            } else {
                $line = $table->renderForDisplay($displayOnly);
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
        undef, $query->param('erp_active_topic'));

    my ($meta, $text) = TWiki::Func::readTopic($web, $topic);
    my $url;
    if (!TWiki::Func::checkAccessPermission(
        'CHANGE', TWiki::Func::getWikiName(), $text, $topic, $web, $meta)) {

        # SMELL:
        # - can't use TWiki::Func::getOopsUrl() to get an accessdenied url
        #   because it does not pass the def => 'topic_access' parameter
        # - can throw an appropriate exception 
        #   because the rest script does not catch it
        # see Bugs:Item3772

        $url = $TWiki::Plugins::SESSION->getOopsUrl(
          'accessdenied', 
          web => $web,
          topic => $topic,
          def => 'topic_access',
          params => [
            'CHANGE',
            'access not allowed on topic',
          ]
        );

    } else {
        $text =~ s/\\\n//gs;
        require TWiki::Plugins::EditRowPlugin::Table;
        die $@ if $@;
        my $urps = $query->Vars();
        my $content = TWiki::Plugins::EditRowPlugin::Table::parseTables(
            $text, $topic, $web, $meta, $urps);

        my $nlines = '';
        my $table = undef;
        my $active_table = 0;
        my $action = 'cancel';
        my $minor = 0;
        # The submit buttons are image buttons. The only way with IE to tell
        # which one was clicked is by looking at the x coordinate of the
        # press.
        if ($query->param('erp_save.x')) {
            $action = 'change';
        } elsif ($query->param('erp_quietSave.x')) {
            $action = 'change';
            $minor = 1;
        } elsif ($query->param('erp_addRow.x')) {
            $action = 'addRow';
        } elsif ($query->param('erp_deleteRow.x')) {
            $action = 'deleteRow';
        }

        foreach my $line (@$content) {
            if (ref($line) eq 'TWiki::Plugins::EditRowPlugin::Table') {
                $table = $line;
                $active_table++;
                if ($active_table == $urps->{erp_active_table}) {
                    $table->$action($urps);
                }
                $line = $table->stringify();
                $table->finish();
                $nlines .= $line;
            } else {
                $nlines .= "$line\n";
            }
        }
        TWiki::Func::saveTopic($web, $topic, $meta, $nlines,
                                { minor => $minor });

        my $anchor = "erp$urps->{erp_active_table}_$urps->{erp_active_row}";
        if ($TWiki::Plugins::VERSION < 1.11) {
            $url = TWiki::Func::getScriptUrl($web, $topic, 'view')."#$anchor";
        } else {
            $url = TWiki::Func::getScriptUrl(
                $web, $topic, 'view', '#' => $anchor);
        }
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
