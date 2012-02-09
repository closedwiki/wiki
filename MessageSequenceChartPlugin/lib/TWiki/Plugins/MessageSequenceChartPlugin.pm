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

=pod

---+ package MessageSequenceChartPlugin

A TWiki plugin for the mscgen utility. Parses message sequence chart (MSC)
descriptions and produces PNG images as the output. MSCs are described using
a simple markup language written between %MSC% and %ENDMSC% tags.

MSC is an interaction diagram from the SDL family very similar to UML's
sequence diagram. MSCs are popular for describing communication behaviour
in real-time systems, telecommunication, protocol software etc.

=cut

use strict;

package TWiki::Plugins::MessageSequenceChartPlugin;

require TWiki::Func;    # The plugins API
require TWiki::Plugins; # For the API version

use Digest::MD5 qw(md5_hex);
use File::Spec qw(tmpdir);
use File::Temp qw(tempfile);
use File::Path qw(mkpath);

use vars qw( $pluginName $VERSION $RELEASE $SHORTDESCRIPTION $NO_PREFS_IN_TOPIC $debug $mscGenCmd $sandbox %hashArray );

our $pluginName = 'MessageSequenceChartPlugin';
our $VERSION = '$Rev$';
our $RELEASE = '2012-02-09';
our $SHORTDESCRIPTION = 'Draw message sequence charts (MSCs) using the mscgen utility';
our $NO_PREFS_IN_TOPIC = 1;

sub initPlugin {
    my( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.1 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    # read plugin settings
    $mscGenCmd = $TWiki::cfg{Plugins}{$pluginName}{mscGenCmd} || '/usr/bin/mscgen';
    $debug = $TWiki::cfg{Plugins}{$pluginName}{Debug} || 0;

    # Plugin correctly initialized
    writeDebug("${pluginName}::initPlugin( $web.$topic ) is OK" );

    # Hash array of the created/used attachments (PNG filenames). Existing
    # attachments are removed if they become unused (the corresponding mscgen
    # markup does not exist anymore in the topic).
    %hashArray = ();

    $sandbox = undef;

    return 1;
}

sub commonTagsHandler {
#    # do not uncomment, use $_[0], $_[1]... instead
#    ### my ( $text, $topic, $web, $included, $meta ) = @_;

    return if $_[3];    # Called in an include; do not process MSC macros

    writeDebug("${pluginName}::commonTagsHandler( $_[2].$_[1] )");

    # Pass everything within %MSC% ... %ENDMSC% tags to handleMsc function
    $_[0] =~ s/%MSC%\s*(.*?)%ENDMSC%/&_handleMsc($1, $_[2], $_[1])/egs;

    if (%hashArray) {
        _removeUnusedAttachments($_[2], $_[1]);
        %hashArray = ();
    }
}

sub _handleMsc {
    my( $text, $web, $topic ) = @_;

    writeDebug("${pluginName}::_handleMsc( $web.$topic )");

    my $tmpDir = '';
    if ( defined $TWiki::cfg{TempfileDir} ) {
        $tmpDir = $TWiki::cfg{TempfileDir};
    }
    else {
        $tmpDir = tmpdir();
    }

    my (undef, $tmpTxtFile) = tempfile("tmp${pluginName}XXXXXXXX",
                                        DIR => $tmpDir,
                                        SUFFIX => '.txt');
    my (undef, $tmpPngFile) = tempfile("tmp${pluginName}XXXXXXXX",
                                        DIR => $tmpDir,
                                        SUFFIX => '.png');

    # Create topic directory "pub/$web/$topic" if needed
    my $dir = TWiki::Func::getPubDir() . "/$web/$topic";
    unless ( -e "$dir" ) {
        umask(002);
        mkpath( $dir, 0, 0755 )
          or return
          "<nop>$pluginName Error: *folder $dir could not be created*";
    }

    # Compute the MD5 hash of this string (mscgen markup) -> unique identifier
    my $hashCode = md5_hex("MESSAGESEQUENCECHART$text");
    my $pngFileName = "MessageSequenceChartPlugin_${hashCode}.png";

    # Mark this attachment as in use (corresponding mscgen input exists)
    $hashArray{$pngFileName} = 1;

    # If attachment already exist, don't do anything
    if ( open TMP, "${dir}/${pngFileName}" ) {
        writeDebug("$pluginName: $pngFileName: Attachment exists already");
        close TMP;
    }
    else {
        writeDebug("$pluginName: $pngFileName: Generating new attachment");

        # Output the mscgen markup text into the tmp file
        open OUTFILE, ">$tmpTxtFile"
            or return "<nop>$pluginName Error: could not create file";
        print OUTFILE $text;
        close OUTFILE;

        # Run the command and create the png
        my $cmd =
            $mscGenCmd .
            ' -T png' .
            ' -i %INFILE|F%' .
            ' -o %OUTFILE|F%';

        writeDebug("$pluginName: Command: $cmd");
        writeDebug("$pluginName: Infile: $tmpTxtFile");
        writeDebug("$pluginName: Outfile: $tmpPngFile");

        unless ( $sandbox ) {
            if ( $TWiki::Plugins::VERSION >= 1.1 ) {
                # Dakar provides a sandbox
                $sandbox = $TWiki::sharedSandbox
                    || $TWiki::sandbox; # for TWiki 4.2
            } else {
                # in Cairo, must use the contrib package
                eval("use TWiki::Contrib::DakarContrib;");
                $sandbox = new TWiki::Sandbox();
            }
        }

        my ($output, $status) = $sandbox->sysCommand(
            $cmd,
            INFILE => $tmpTxtFile,
            OUTFILE => $tmpPngFile,
        );

        writeDebug("$pluginName: Output: $output Status $status");

        if ($status) {
            unlink $tmpTxtFile unless $debug;
            unlink $tmpPngFile unless $debug;
            return &_showError($status, $output, $text);
        }

        # Attach created png file to topic, but hide it pr. default.
        my @stats = stat $tmpPngFile;
        TWiki::Func::saveAttachment($web, $topic, $pngFileName,
            {
            file     => $tmpPngFile,
            filesize => $stats[7],
            filedate => $stats[9],
            comment  => "MSC graphic generated by <nop>$pluginName",
            hide     => 1,
            dontlog  => 1
            }
        );

        # Clean up temporary files
        unlink $tmpTxtFile unless $debug;
        unlink $tmpPngFile unless $debug;
    }

    my $imgTag = "<img src=\"" .
                 TWiki::Func::getPubUrlPath() .
                 "/$web/$topic/$pngFileName\" />\n";
    return $imgTag;
}

sub _removeUnusedAttachments {
    my( $web, $topic ) = @_;

    writeDebug("${pluginName}::_removeUnusedAttachments( $web.$topic )");

    # Loop through the attachments included in topic and remove unused
    my( $meta, $text ) = TWiki::Func::readTopic($web, $topic);
    my @attachments = $meta->find( 'FILEATTACHMENT' );
    foreach my $a ( @attachments ) {
        my $filename = $a->{name};

        # If it starts with "MessageSequenceChart_", contains 32 hexadecimal
        # digits and .png suffix, then it must be our stuff
        if ($filename =~ /MessageSequenceChartPlugin_[0-9a-f]{32}\.png/) {

            # Hash array of the created/used attachments (PNG filenames)
            if ($hashArray{$filename}) {
                writeDebug("$pluginName: $filename is in use in $web.$topic");
            }
            else {
                writeDebug("$pluginName: $filename is not use in $web.$topic");
                _removeAttachment($web, $topic, $filename);
            }
        }
    }
}

sub _removeAttachment {
    my( $web, $topic, $filename ) = @_;

    writeDebug("${pluginName}::_removeAttachment( $web.$topic, $filename )");

    if ($TWiki::cfg{TrashWebName}) {
        if (!TWiki::Func::topicExists($TWiki::cfg{TrashWebName},
                                      'TrashAttachment')) {
            writeDebug("$pluginName: Creating missing topic " .
                       $TWiki::cfg{TrashWebName} . '.TrashAttachment');
            my $text =
                "---+ %MAKETEXT{\"Placeholder for trashed attachments\"}%\n";
            TWiki::Func::saveTopic( $TWiki::cfg{TrashWebName},
                                    'TrashAttachment', undef, $text, undef );
        }

        my $i  = 0;
        my $trashFilename = "$web.$topic.$filename";
        while ( TWiki::Func::attachmentExists( $TWiki::cfg{TrashWebName},
                                               'TrashAttachment',
                                               $trashFilename ) ) {
            writeDebug("$pluginName: Duplicate in trash $trashFilename");
            $i++;
            $trashFilename = "$web.$topic.$filename.$i";
        }
        TWiki::Func::moveAttachment(
            $web, $topic, $filename,
            $TWiki::cfg{TrashWebName}, 'TrashAttachment', $trashFilename);
    }
}

sub _showError {
    my ( $status, $output, $text ) = @_;

    my $line = 1;
    $text =~ s/\n/sprintf("\n%02d: ", $line++)/ges;
    $output .= "<pre>$text\n</pre>";
    return "<noautolink><span class='twikiAlert'><nop>$pluginName " .
           "Error ($status): $output</span></noautolink>";
}

sub writeDebug {
    &TWiki::Func::writeDebug($_[0]) if $debug;
}

1;
