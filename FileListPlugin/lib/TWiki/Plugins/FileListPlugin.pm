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

package TWiki::Plugins::FileListPlugin;

use strict;
use TWiki::Plugins::FileListPlugin::FileData;

use vars qw($VERSION $RELEASE $web $topic $user $installWeb $pluginName
  $debug $renderingWeb $defaultFormat
);

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = '0.9.2';

$pluginName = 'FileListPlugin';    # Name of this Plugin

sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1.026 ) {
        TWiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    $defaultFormat = '   * [[$fileUrl][$fileName]] $fileComment';

    # Get plugin preferences
    $defaultFormat = TWiki::Func::getPreferencesValue('FORMAT')
      || TWiki::Func::getPluginPreferencesValue('FORMAT')
      || $defaultFormat;

    $defaultFormat =~ s/^[\\n]+//;    # Strip off leading \n
    
    # Get plugin debug flag
    $debug = TWiki::Func::getPluginPreferencesFlag("DEBUG");

    # Plugin correctly initialized
    TWiki::Func::writeDebug(
        "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK")
      if $debug;
    return 1;
}

sub _handleFileList {
    my ( $args, $theWeb, $theTopic ) = @_;
    my %params = TWiki::Func::extractParameters($args);

    my $web   = $params{'web'}   || $theWeb   || '';
    my $topic = $params{'topic'} || $theTopic || '';

    # check if the user has permissions to view the topic
    my $user = TWiki::Func::getWikiName();
    my $wikiUserName = TWiki::Func::userToWikiName( $user, 1 );
    if (
        !TWiki::Func::checkAccessPermission(
            'VIEW', $wikiUserName, undef, $topic, $web
        )
      )
    {
        return '';
    }

    my $outtext = "";

    my $format    = $params{'format'}    || $defaultFormat;
    my $header    = $params{'header'}    || '';
    my $footer    = $params{'footer'}    || '';
    my $alttext   = $params{'alt'}       || '';
    my $fileCount = $params{'fileCount'} || '';
    my $separator = $params{'separator'} || '';

    # filters
    my $excludeTopics          = $params{'excludetopic'}     || '';
    my $excludeWebs          = $params{'excludeweb'}     || '';
    my $excludeFiles           = $params{'excludefile'}      || '';
    my $excludeExtensionsParam = $params{'excludeextension'} || '';
    my $extensionsParam        = $params{"extension"}
      || $params{"filter"};    # "abc, def" syntax. Substring match will be used
                               # param filter is deprecated
    my %extensions        = makeHashFromString($extensionsParam);
    my %excludeExtensions = makeHashFromString($excludeExtensionsParam);

    my $hideHidden = '';
    if ( defined $params{"hide"} ) {
        $hideHidden =
          ( grep { $_ eq $params{"hide"} } ( 'on', 'yes', '1' ) )
          ? 1
          : 0;                 # don't hide by default
    }

    my %hiddenFiles = makeHashFromString($excludeFiles);

    my @files = createAttachmentList( $topic, $web, $excludeTopics, $excludeWebs );

    # store once for re-use in loop
    my $pubUrl = TWiki::Func::getUrlHost() . TWiki::Func::getPubUrlPath();

    my $count = 0;
    foreach my $fileData (@files) {

        my $attachmentTopic    = $fileData->{'topic'};
        my $attachmentTopicWeb = $fileData->{'web'};
        my $attachment         = $fileData->{'attachment'};

        # do not show file if user has no permission to view this topic
		next if (!TWiki::Func::checkAccessPermission(
				'VIEW', $wikiUserName, undef, $attachmentTopic, $attachmentTopicWeb));
		
        my $filename = $attachment->{name};

        my $fileExtension = getFileExtension($filename);

        if (   ( keys %extensions && !$extensions{$fileExtension} )
            || ( $excludeExtensions{$fileExtension} ) )
        {
            next;
        }
        next if ( $hiddenFiles{$filename} );

        my $attrSize    = $attachment->{size};
        my $attrUser    = $attachment->{user};
        my $attrComment = $attachment->{comment};
        my $attrAttr    = $attachment->{attr};

        # skip if the attachment is hidden
        next if ( $attrAttr =~ /h/i && $hideHidden );

     # I18N: To support attachments via UTF-8 URLs to attachment
     # directories/files that use non-UTF-8 character sets, go through viewfile.
     # If using %PUBURL%, must URL-encode explicitly to site character set.

        # Go direct to file where possible, for efficiency
        # TODO: more flexible size formatting
        # also take MB into account
        my $attrSizeStr;
        $attrSizeStr = $attrSize . 'b' if ( $attrSize < 100 );
        $attrSizeStr = sprintf( "%1.1fK", $attrSize / 1024 )
          if ( $attrSize >= 100 );
        $attrComment = $attrComment || "";
        my $s = "$format";
        $s =~ s/\$fileName/$filename/g;

        if ( $s =~ /fileIcon/ ) {
            ## To find the File Extention..
            my @bits     = ( split( /\./, $filename ) );
            my $ext      = lc $bits[$#bits];
            my $fileIcon = '%ICON{"' . $ext . '"}%';
            $s =~ s/\$fileIcon/$fileIcon/g;
        }
        $s =~ s/\$fileSize/$attrSizeStr/g;
        $s =~ s/\$fileComment/$attrComment/g;
        if ( $s =~ /fileDate/ ) {
            my $attrDate = TWiki::Time::formatTime( $attachment->{"date"} );
            $s =~ s/\$fileDate/$attrDate/g;
        }
        $s =~ s/\$fileUser/$attrUser/g;

        #replace stubs
        $s =~ s/\$n/\n/g;
        $s =~ s/\$br/\<br \/\>/g;

        if ( $s =~ /fileActionUrl/ ) {
            my $fileActionUrl =
              TWiki::Func::getScriptUrl( $attachmentTopicWeb, $attachmentTopic,
                "attach" )
              . "?filename=$filename&revInfo=1";
            $s =~ s/\$fileActionUrl/$fileActionUrl/;
        }

        if ( $s =~ /viewfileUrl/ ) {
            my $attrVersion = $attachment->{Version};
            my $viewfileUrl =
              TWiki::Func::getScriptUrl( $attachmentTopicWeb, $attachmentTopic,
                "viewfile" )
              . "?rev=$attrVersion&filename=$filename";
            $s =~ s/\$viewfileUrl/$viewfileUrl/;
        }

        if ( $s =~ /\$hidden/ ) {
            my $hidden = ( $attrAttr =~ /h/i ) ? 'hidden' : '';
            $s =~ s/\$hidden/$hidden/g;
        }

        my $fileUrl =
          $pubUrl . "/$attachmentTopicWeb/$attachmentTopic/$filename";

        $s =~ s/\$fileUrl/$fileUrl/;

        my $sep = $separator || "\n";
        $outtext .= $s . $sep;

        $count++;
    }

    # remove last separator
    $outtext =~ s/$separator$//go;

    if ( $outtext eq "" ) {
        $outtext = $alttext;
    }
    else {
        $footer =~ s/\$fileCount/$count/go;
        $outtext = $header . "\n" . $outtext . $footer;
    }

    return $outtext;
}

sub getFileExtension {
    my ($filename) = @_;

    my $extension = $filename;
    $extension =~ s/^.*?\.(.*?)$/$1/go;
    return $extension;
}

=pod

Goes through the topics in $topicString, f.e. '%TOPIC%, WebHome'
or all topics in case of a wildcard '*'.

Returns a list of FileData objects.

=cut

sub createAttachmentList {
    my ( $topicString, $webString, $excludeTopicsString, $excludeWebssString ) = @_;

    my @files = ();
    my %excludeTopics = makeHashFromString($excludeTopicsString);
    my %excludeWebs = makeHashFromString($excludeWebssString);

    my @webs = ();
	my @topics = ();
	if ( $webString eq '*' ) {
		@webs = TWiki::Func::getListOfWebs();
	}
	else {
		@webs = split( /[\s,]+/, $webString );
	}
	foreach my $web (@webs) {
		next if ( $excludeWebs{$web} );
		my @topics = ();
		if ( $topicString eq '*' ) {
			@topics = TWiki::Func::getTopicList($web);
		}
		else {
			@topics = split( /[\s,]+/, $topicString );
		}
		
		foreach my $attachmentTopic (@topics) {
			next if ( $excludeTopics{$attachmentTopic} );
			my @topicFiles = createAttachmentListForTopic( $attachmentTopic, $web );
			foreach my $attachment (@topicFiles) {
				my $fd =
				  TWiki::Plugins::FileListPlugin::FileData->new( $attachmentTopic,
					$web, $attachment );
				push @files, $fd;
			}
		}
	}
    return @files;
}

sub createAttachmentListForTopic {
    my ( $topic, $web ) = @_;

    my ( $meta, $text ) = TWiki::Func::readTopic( $web, $topic );
    return $meta->find("FILEATTACHMENT");
}

sub makeHashFromString {
    my ($text) = @_;

    my %hash = ();

    return %hash if !defined $text || !$text;

    my $re = '\b[\w\._\-\+\s]*\b';
    my @elems = split( /\s*($re)\s*/, $text );
    foreach (@elems) {
        $hash{$_} = 1;
    }
    return %hash;

}

sub commonTagsHandler {
    TWiki::Func::writeDebug("- ${pluginName}::commonTagsHandler( $_[2].$_[1] )")
      if $debug;

    # This is the place to define customized tags and variables
    # Called by TWiki::handleCommonTags, after %INCLUDE:"..."%

    $_[0] =~ s/%FILELIST%/&_handleFileList($defaultFormat, $web, $topic)/ge;
    $_[0] =~ s/%FILELIST{(.*?)}%/&_handleFileList($1, $web, $topic)/ge;
}

1;
