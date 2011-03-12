# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2003 Peter Thoeny, peter@thoeny.com
# Copyright (C) 2003 TWiki:Main.DonnyKurniawan
# Copyright (C) 2008-2011 TWiki Contributors. All Rights Reserved.
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

# =========================
package TWiki::Plugins::EmbedBibPlugin;

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $RELEASE $pluginName $debug
    );

$VERSION = '$Rev$';
$RELEASE = '2011-03-12';

$pluginName = 'EmbedBibPlugin';  # Name of this Plugin

# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.1 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    # Get plugin debug flag
    $debug = TWiki::Func::getPreferencesFlag( "\U$pluginName\E_DEBUG" );

    # Plugin correctly initialized
    TWiki::Func::writeDebug( "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK" ) if $debug;
    return 1;
}

# =========================
sub commonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- ${pluginName}::commonTagsHandler( $_[2].$_[1] )" ) if $debug;

    $_[0] =~ s/%EMBEDBIB{(.*?)}%/&handleEmbedBib($1)/ge;

}

# =========================
sub handleEmbedBib
{
    my $defaultWebName = TWiki::Func::getPreferencesValue( "EMBEDBIBPLUGIN_DEFAULTWEBNAME" );
    my $defaultTopic = TWiki::Func::getPreferencesValue( "EMBEDBIBPLUGIN_DEFAULTTOPICNAME" );
    my $defaultStyle = TWiki::Func::getPreferencesValue( "EMBEDBIBPLUGIN_DEFAULTSTYLE" );
    my $defaultSort = TWiki::Func::getPreferencesValue( "EMBEDBIBPLUGIN_DEFAULTSORT" );

    my ( $theAttributes ) = @_;
    my $BibSelect1 = &TWiki::Func::extractNameValuePair($theAttributes, "select1");
    my $BibSelect2 = &TWiki::Func::extractNameValuePair($theAttributes, "select2");
    my $BibSelect3 = &TWiki::Func::extractNameValuePair($theAttributes, "select3");
    my $BibSelect4 = &TWiki::Func::extractNameValuePair($theAttributes, "select4");
    my $BibFile = &TWiki::Func::extractNameValuePair($theAttributes, "bibfile"); 
    my $WebName = &TWiki::Func::extractNameValuePair($theAttributes, "webname"); 
    my $Topic = &TWiki::Func::extractNameValuePair($theAttributes, "topic"); 
    my $Style = &TWiki::Func::extractNameValuePair($theAttributes, "style"); 
    my $Sort = &TWiki::Func::extractNameValuePair($theAttributes, "sort"); 

    $WebName = $defaultWebName if $WebName eq "";
    $Topic = $defaultTopic if $Topic eq "";
    $Style = $defaultStyle if $Style eq "";
    $Sort = $defaultSort if $Sort eq "";

    # Check for error
    return "EMBEDBIB Error: missing parameters" if ($BibFile eq '' or $BibSelect1 eq '');
    return "EMBEDBIB Error: Web $WebName not found"  unless( TWiki::Func::webExists( $WebName ));
    return "EMBEDBIB Error: Topic $Topic not found"  unless( TWiki::Func::topicExists( $WebName, $Topic ));
    return "EMBEDBIB Error: File $BibFile not found" unless( TWiki::Func::topicExists( $WebName, $Topic, $BibFile ));

    # Translate '(' and ')' to ' " '
    # Translate '|' to '\|'
    foreach my $sel ($BibSelect1, $BibSelect2, $BibSelect3, $BibSelect4)
    {
	$sel =~ s/(\(|\))/\"/g;
	$sel =~ s/\|/\\\|/g;
    }

    # BibTool command for BibSelect1
    my $bibtoolPath = '/usr/local/bin/bibtool';
    my $bibtoolargs = "-- select\'{$BibSelect1}\'";
    my $bibtoolfile = TWiki::Func::getPubDir() . "/${WebName}/${Topic}/${BibFile}";
    my $bibtoolcommand = "$bibtoolPath $bibtoolargs $bibtoolfile";

    # BibTool command for BibSelect2, BibSelect3, and BibSelect4
    foreach my $sel ($BibSelect2, $BibSelect3, $BibSelect4)
    {
	if ($sel ne '')
	{
		$bibtoolcommand .= " | $bibtoolPath -- select\'{$sel}\'";
	}
    }

    if ( $Style eq "bibtex" )
    {
    	return `$bibtoolcommand`;
    }
    elsif ( $Style eq "html" )
    {
    	my $tmpBibFile = '/tmp/twiki.bib';
	my $bibtex2htmlPath = '/usr/local/bin/bibtex2html';
	my $bibtex2htmlArgs = "-output - -sort $Sort";

	# This is the configuration string for bibtex2html to format 
	# the output nicely
	my $bibtex2htmlConf = <<'EOF';
@string{ file_tag.start = " " }
@string{ file_tag.end = " " }
@string{ head_tag.start = " " }
@string{ head_tag.end = " " }
@string{ file_title_tag.start = " " }
@string{ file_title_tag.end = " " }
@string{ body_tag.start = " " }
@string{ body_tag.end = " " }
@string{ single_output_file_title = " " }
@string{ single_output_page_title = " " }
@string{ single_output_write_disclaimer = 0 }
@string{ single_output_write_date = 0 }
@string{ single_output_write_author = 0 }
@string{ single_output_write_credits = 0 }
@string{ single_output_header_of_body = " " }
@string{ page_title_tag.start = " " }
@string{ page_title_tag.end = " " }
@string{ page_subtitle_tag.start = " " }
@string{ page_subtitle_tag.end = " " }
@string{ item_tag.end = "</li>\n" }
EOF

	# We need to use a temporary file since bibtex2html does not accept
        # input from stdin
	open(TMPFILE, ">$tmpBibFile") or return "EMBEDBIB Error: fatal error";
	my $tmpOut = `$bibtoolcommand`;
	print TMPFILE $tmpOut;
	print TMPFILE $bibtex2htmlConf;

    	return `$bibtex2htmlPath $tmpBibFile $bibtex2htmlArgs `;
    }
}

1;
