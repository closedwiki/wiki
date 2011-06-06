# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (c) 2006 by Meredith Lesly, Kenneth Lavrsen
# Copyright (C) 2006-2011 TWiki Contributors. All Rights Reserved.
# TWiki Contributors are listed in the AUTHORS file in the root of
# this distribution.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# For licensing info read LICENSE file in the TWiki root.

package TWiki::Plugins::AttachContentPlugin;

# Always use strict to enforce variable scoping
use strict;

# $VERSION is referred to by TWiki, and is the only global variable that
# *must* exist in this package
our $VERSION = '$Rev$';
our $RELEASE = '2011-06-05';

# Name of this Plugin, only used in this module
our $pluginName = 'AttachContentPlugin';

# Actions needing saving
my $ACTION_VIEW="view";
my $ACTION_SAVE="save";


our $debug;
our $savedAlready;
our $defaultKeepPars;
our $defaultComment;
our $attachonviewglobal;
our $SHORTDESCRIPTION = "Saves dynamic topic text to an attachment";
our $NO_PREFS_IN_TOPIC = 1;

sub initPlugin {
    my( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.026 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    $defaultKeepPars = $TWiki::cfg{Plugins}{AttachContentPlugin}{KeepPars}  || 0;
    $defaultComment = $TWiki::cfg{Plugins}{AttachContentPlugin}{AttachmentComment} || '';
    $attachonviewglobal = $TWiki::cfg{Plugins}{AttachContentPlugin}{AttachOnView} || 0;
    $debug = $TWiki::cfg{Plugins}{AttachContentPlugin}{Debug} || 0;

    # Plugin correctly initialized
    return 1;
}

=pod

---++ commonTagsHandler($text, $topic, $web )
   * =$text= - text to be processed
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$included= - Boolean flag indicating whether the handler is invoked on an included topic
   * =$meta= - meta-data object for the topic MAY BE =undef=
This handler is called by the code that expands %<nop>TAGS% syntax in
the topic body and in form fields. It may be called many times while
a topic is being rendered.

=cut

sub commonTagsHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    ### my ( $text, $topic, $web, $meta ) = @_;

    my $page = $_[0];
     $_[0] =~ s/%STARTATTACH{.*?}%//gs;
     $_[0] =~ s/%ENDATTACH%//gs;
     
    TWiki::Func::writeDebug( "- ${pluginName}::commonTagsHandler( $_[2].$_[1] )" ) if $debug;
    return if $savedAlready;
    $savedAlready = 1;

    $page =~ s/%STARTATTACH{(.*?)}%(.*?)%ENDATTACH%/&handleAttach($ACTION_VIEW, $1, $2, $_[2], $_[1] )/ges;
    $savedAlready = 0;

}

=pod

---++ afterSaveHandler($text, $topic, $web, $error, $meta )
   * =$text= - the text of the topic _excluding meta-data tags_
     (see beforeSaveHandler)
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$error= - any error string returned by the save.
   * =$meta= - the metadata of the saved topic, represented by a TWiki::Meta object 

This handler is called each time a topic is saved.

__NOTE:__ meta-data is embedded in $text (using %META: tags)

=cut

sub afterSaveHandler {
# do not uncomment, use $_[0], $_[1]... instead
    ### my ( $text, $topic, $web, $error, $meta ) = @_;

    my $query = TWiki::Func::getCgiQuery();
    
    # Do not run plugin when managing attachments.
    if( ( $query ) && ( $ENV{'SCRIPT_NAME'} ) && ( $ENV{'SCRIPT_NAME'} =~ /^.*\/upload/ ) ) {
    	return;
    }

    return if $savedAlready;
    $savedAlready = 1;

    TWiki::Func::writeDebug( "- ${pluginName}::afterSaveHandler( $_[2].$_[1] )" ) if $debug;

    $_[0] =~ s/%STARTATTACH{(.*?)}%(.*?)%ENDATTACH%/&handleAttach($ACTION_SAVE, $1, $2, $_[2], $_[1])/ges;
    $savedAlready = 0;
   
}

=pod

---++ handleAttach($action, $inAttr, $inContent, $inWeb, $inTopic)

inweb	''
intopic WebHome

inweb Main
intopic WebHome

inweb ''
intopic ''

=cut

sub handleAttach {

    my ($action, $inAttr, $inContent, $inWeb, $inTopic) = @_;

    my $attrs = TWiki::Func::expandCommonVariables($inAttr, $inTopic, $inWeb);
    my %params = TWiki::Func::extractParameters($attrs);

    my $attrFileName = $params{_DEFAULT};
    
    return '' unless $attrFileName;
    
    # If we are in "view" mode, then do not save unless it is globally enabled, or overridden
    if ($action eq 'view') {
      my $attachonview = $params{'attachonview'} || $attachonviewglobal ; # default = global setting
      return '' unless $attachonview;
    }
    
    my $web = $params{'web'} || $inWeb;
    my $topic = $params{'topic'} || $inTopic;
    my $comment = $defaultComment;
    $comment = $params{'comment'} if defined($params{'comment'});
    my $hide = defined($params{'hide'}) && ( $params{'hide'} eq 'on' );
    my $keepPars = $params{'keeppars'};
    if ( defined($keepPars) ) {
        $keepPars = $keepPars eq 'on';
    } else {
        $keepPars = $defaultKeepPars;
    }
    TWiki::Func::writeDebug( "- ${pluginName}::handleAttach( attrs = $attrs, web = $web, topic = $topic, hide= $hide )" ) if $debug;
    
    my $workArea = TWiki::Func::getWorkArea($pluginName);

    # Protect against evil filenames - especially for out temp file.
    # In a future release we can use TWiki::Func::sanitizeAttachmentName
    # e.g. my ( $fileName, $orgName ) = TWiki::Func::sanitizeAttachmentName( $attrFileName );
    # For now we will stick to handcrafted code
    
    my $fileName = $attrFileName;
    $fileName =~ /\.*([ \w_.\-]+)$/go;
    $fileName = $1;
    
    # Change spaces to underscore
    $fileName =~ s/ /_/go;
    # Strip dots and slashes at start
    # untaint at the same time
    $fileName =~ s/^([\.\/\\]*)*(.*?)$/$2/go;
    # Remove problematic chars
    $fileName =~ s/$TWiki::cfg{NameFilter}//goi;
    # Append .txt to files like we do to normal attachments
    $fileName =~ s/$TWiki::cfg{UploadFilter}/$1\.txt/goi;
        
    # Temp file in workarea - Filename + 9 digits to avoid race condition 
    my $tempName = $workArea . '/' . $fileName . int(rand(1000000000));

    # Turn most TML to text
    my $content = TWiki::Func::expandCommonVariables($inContent, $topic, $web);

    # Turn paragraphs, nops, and bracket links into plain text
    unless ($keepPars) {
	    $content =~ s/<p\s*\/>/\n/go;
	    $content =~ s/<nop>//goi;
	    $content =~ s/\[\[.+?\]\[(.+?)\]\]/$1/go;
	    $content =~ s/\[\[(.+?)\]\]/$1/go;
    }
      # Change twiki mangling of % back
      $content =~ s/&#37;/%/go;

    TWiki::Func::writeDebug("${pluginName}::handleAttach, tempName: $tempName") if $debug;
    
    # Saving temporary file
    TWiki::Func::saveFile($tempName, $content);

    my @stats = stat $tempName;
    my $fileSize = $stats[7];
    my $fileDate = $stats[9];
    
    TWiki::Func::saveAttachment($web, $topic, $fileName, { file => $tempName,
                                                           filedate => $fileDate,
                                                           filesize => $fileSize,
                                                           filepath => $fileName,
                                                           comment => $comment,
                                                           hide => $hide
                                                         });

    # Delete temporary file
    unlink($tempName) if( $tempName && -e $tempName );
    
    return "";
}

1;
