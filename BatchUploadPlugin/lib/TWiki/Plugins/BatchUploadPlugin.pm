package TWiki::Plugins::BatchUploadPlugin;
# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2004 Peter Thoeny, peter@thoeny.com
# Copyright (C) Vito Miliano, ZacharyHamm, JohannesMartin, DiabJerius
# Copyright (C) 2004 Martin Cleaver, Martin.Cleaver@BCS.org.uk
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
#

# Originally by Vito Miliano EPIC Added 22 Mar 2003
# Modified by ZacharyHamm, JohannesMartin, DiabJerius 
# Converted to a plugin by MartinCleaver 

use Data::Dumper;
use strict;
use Archive::Zip qw(:ERROR_CODES :CONSTANTS :PKZIP_CONSTANTS);
use warnings;
use diagnostics;

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $RELEASE $pluginName
        $debug $pluginEnabled
    );

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

$pluginName = 'ArchiveUploadPlugin';  # Name of this Plugin

# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.021 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    # Get plugin debug flag
    $debug = TWiki::Func::getPluginPreferencesFlag( "DEBUG" );

    $pluginEnabled = TWiki::Func::getPluginPreferencesValue( "ENABLED" ) || 0;

    # Plugin correctly initialized
    TWiki::Func::writeDebug( "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK" ) if $debug;
    return 1;
}

=pod

---++ sub beforeAttachmentSaveHandler ( $attrHashRef, $topic, $web )

| Description: | This code provides Plugins with the opportunity to alter an uploaded attachment between the upload and save-to-s$
| Parameter: =$attrHashRef= | Hash reference of attachment attributes (keys are indicated below) |
| Parameter: =$topic=       | Topic name |
| Parameter: =$web=         | Web name |
| Return:                   | There is no defined return value for this call |

Keys in $attrHashRef:
| *Key*       | *Value* |
| attachment  | Name of the attachment |
| tmpFilename | Name of the local file that stores the upload |
| comment     | Comment to be associated with the upload |
| user        | Login name of the person submitting the attachment, e.g. "jsmith" |

 Note: All keys should be used read-only, except for comment which can be modified.

Example usage:

<pre>
   my( $attrHashRef, $topic, $web ) = @_;
   $$attrHashRef{"comment"} .= " (NOTE: Extracted from blah.tar.gz)";
</pre>

 Note: we don't have access to:
		 $createLink,

=cut

sub beforeAttachmentSaveHandler {
  my( $attrHashRef, $topic, $web ) = @_;

  if ($pluginEnabled) {
    my $createLink = 1;
    updateAttachment($web, $topic, $attrHashRef->{user},
		     $createLink, 
		     $attrHashRef->{attachment},
		     $attrHashRef->{"tmpFilename"},
		     $attrHashRef->{"comment"} );
  }
};

sub updateAttachment
{
#  die "UA".Dumper(\@_);
  my ($webName,
      $topic,
      $userName,

      $createLink,
      $originalZipName, 
      $tmpFilename,               # cgi name
      $fileComment ) = @_;

  my $archivefile = ($originalZipName =~ m/.zip$/);
  unless ($archivefile) {
    return;
  }
  
  my ($zip, %processedFiles, $tmpDir);
  

  $zip = openZipSanityCheck ( $tmpFilename, $webName, $topic, $originalZipName );
  #    die Dumper(\$zip);
    unless (ref $zip) {
      die "Problem with ".$zip;
    }
  ($tmpDir, %processedFiles ) = doUnzip($zip, $tmpFilename, $fileComment);
  #	TWiki::Func::writeDebug( "upload: tmpDir = $tmpDir" );
  

#  die Dumper(\%processedFiles);
  
  # Loop through processed files.
  my $error;
  foreach my $fileNameKey (sort keys %processedFiles) {
    my ($fileName, $fileComment, $filePath ) = @{$processedFiles{$fileNameKey}};
    
    $filePath = $fileName unless defined $filePath ; # for archives
    $fileName =~ /^(.*?)$/goi ; $fileName = $1;
    $tmpFilename = $fileNameKey;
    
    #	TWiki::Func::writeDebug( "upload: fileName=$fileName, fileComment=$fileComment, tmpFilename=$fileNameKey" );
    
    my( $fileSize, $fileUser, $fileDate, $fileVersion ) = "";

    $error .= addAttachment (
			       $webName, $topic, $userName,
			       $filePath, $tmpFilename,
			       "Extracted from $originalZipName" ); 
  }
  die "DONE! ".$error;
}


# EPIC
# changed to work around a race condition where a symlink could be made in the temp
# directory pointing to a file writable by the CGI and then a zip uploaded with
# that filename, also solves the problem if two people are uploading zips with
# some identical filenames.
sub doUnzip
{
#  die "DU:". Dumper(\@_);
    my ($zip, $archive, $archiveComment) = @_;
    my $tmpDir = $archive; $tmpDir =~ s/(.*)\/.+/$1/;
    $tmpDir = makeTempName( $tmpDir );

    my (@memberNames, $mName, $member, $buffer, $comment, %good, $zipRet);

    @memberNames = $zip->memberNames();

    mkdir( $tmpDir );

    # on some systems with some versions of Archive::Zip extractMemberWithoutPaths()
    # ignores the path given to it and tries to just write the file to the current directory.
    chdir( $tmpDir );

    foreach $mName (sort @memberNames) {
        $member = $zip->memberNamed($mName);
        next if $member->isDirectory();

        $comment = substr($member->fileComment(), 0, 50);
        $comment = length($comment) ? $comment : $archiveComment;

	$mName =~ /\/?(.*\/)?(.+)/; $mName = $2;

	my $zipRet = $zip->extractMemberWithoutPaths( $member, "$tmpDir/$mName" );
	if ($zipRet == AZ_OK) {
	    $good{"$tmpDir/$mName"} = [ $mName, $comment ];
	} else {
	    # FIXME: oops here
	    TWiki::Func::writeDebug( "upload: zip->extractMemberWithoutPaths = $zipRet" );
	}
    }

    return ( $tmpDir, %good ); # return the $tmpDir here so we can remove it
}

sub zipErrorHandler
{
    TWiki::Func::writeDebug (@_);
}

# EPIC
# Open a zip and perform a sanity check on it.
# Returns the opened zip object (to be passed to doUnzip) on success,
# a string saying the reason for failure.
#
sub openZipSanityCheck
{
#  die "OZSC: ".Dumper(\@_);
    my ( $archive, $webName, $topic, $realname ) = @_;
    my ( $lowerCase, $noSpaces, $noredirect) = (0,0,0);
    my $zip = Archive::Zip->new ();
    my (@memberNames, $mName, $member, %dupCheck, $sizeLimit, $size);

    if ( $zip->read ("$archive") != AZ_OK ) {
         return "Zip read error or not a zip file. ". $archive ;
    }

    my $nonAlphaNum = '[^'.$TWiki::mixedAlphaNum . '\._-]+';

    # Scan for duplicates
    @memberNames = $zip->memberNames (); $size = 0;
#    die Dumper($zip);

    foreach $mName (@memberNames) {
         $member = $zip->memberNamed ($mName);
	 next if $member->isDirectory ();

	 $mName =~ /\/?(.*\/)?(.+)/; $mName = $2;

	 $size += $member->uncompressedSize ();

	 if ( $lowerCase ) { $mName = lc ($mName); }
	 unless ( $noSpaces ) { $mName =~ s/\s/_/go; }

#	 $mName =~ s/$nonAlphaNum//go;   # ----------- SMELL breaks.
	 $mName =~ s/$TWiki::uploadFilter/$1\.txt/goi;

	 ##TWiki::Func::writeDebug( "upload: zip member name: $mName" );
	 if ( defined $dupCheck{"$mName"} ) {
	      return "Duplicate file in archive ".$mName." in ".$archive;
	 } else {
	      $dupCheck{"$mName"} = $mName;
	 }
    }
    return $zip;
}

sub makeTempName
{
    my $baseDir = shift;
    my $tempName = sprintf( "%d-%d.%d", $$, time(), rand( 10000 ) );
    return $baseDir ? $baseDir . "/" . $tempName : $tempName;
}

#thanks to forcer on #wiki for this.
sub makeWikiWord {
  my $w = $_[0];
  $w =~ s/[^A-Za-z0-9]//g;
  $w =~ tr/A-Z/a-z/;
  $w =~ s/^(.)(.)(.)/\U$1\E$2\U$3/;
  return $w
}

sub findTopicForPicture {
  my ($fileName, $topic) = @_;
  my $template = "";

  my $newTopic;
  if ($fileName =~ m/.jpg$/) {
    $newTopic =~ s/img/poster/;
    $newTopic = makeWikiWord($fileName);
    $template = "$web.WebPosterTemplate";
  } else {
    $newTopic = $topic; # Can't move it.
  }

  unless (TWiki::Func::topicExists($web, $newTopic)) {
    my ( $meta, $text ) = TWiki::Store::readTemplateTopic($template);
    my $err = TWiki::Store::saveTopic($web, $newTopic, $text, $meta, "",  1 );
  }
  return $newTopic;
}


=pod 
SMELL I break TWiki::Func encapsulation because this is by far the best routine to call

Update an attachment, file or properties or both. This may also be used to
create an attachment.
| =$webName= | Web containing topic |
| =$topic= | Topic |
| =$userName= | Username of user doing upload/change - username, *not* wikiName |
| =$createLink= | 1 if a link is to be created in the topic text |
| =$filePath= | if !propsOnly, gives the remote path name of the file to upload. This is used to derive the attName. |
| =$localFile= | Name of local file to replace attachment |
| =$attName= | If propsOnly, the name of the attachment. Ignored if !propsOnly. |
| =$comment= | (property) comment associated with file |
| return | on error, a list of parameters to the TWiki::UI::oops function, not including the webName and topic. |
|               |  If the first element in the list is the empty string, an error has already been printed to the browser, and no oops call is necessary. |

=cut 

sub addAttachment {
  my ( $webName,
       $topic, 
       $userName,
       $fileName,
       $localFile,
       $comment ) = @_;

  my $propsOnly = 0;
  my $hideFile = 0;
  my $createLink = 0;
  my $attName = "";
  $fileName = lc $fileName;

  # $topic = findTopicForPicture($fileName, $topic);


#  die Dumper(\@_);
  use TWiki::UI::Upload;
  my $res = TWiki::UI::Upload::updateAttachment( $webName,
						 $topic,
						 $userName, 
						 $createLink, # constant = 0
						 $propsOnly, # constant = 0
						 $fileName,
						 $localFile,
						 $attName,
						 $hideFile, # constant = 0
						 $comment );
#  die Dumper(\@_);
  return $res;
}




######################
# This is stuff I deleted from here that probably needs 
# to be in TWiki::UI::Upload

# =========================
#  pngsize : gets the width & height (in pixels) of a png file
#  cor this program is on the cutting edge of technology! (pity it's blunt!)
#  GRR 970619:  fixed bytesex assumption
#  source: http://www.la-grange.net/2000/05/04-png.html
# sub pngsize {


# =========================
# sub addLinkToEndOfTopic
#    if( $fileName =~ /\.(gif|jpg|jpeg|png)$/i ) {


# =========================
# sub handleError


# EPIC
# Translates shorthand into actual bytes.
# 1[Kk] is 1024 bytes, 1[Mm] is 1024K.
# sub limitTranslate






1;
# EOF
