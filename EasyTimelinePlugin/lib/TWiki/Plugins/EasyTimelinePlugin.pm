# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2006-2010 TWiki Contributors
# Copyright (C) 2009-2010 Andrew Jones, http://andrew-jones.com
# Copyright (C) 2006 Mike Marion
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
# =========================
#
# This plugin creates a png file by using the ploticus graph utility.
# See http://meta.wikimedia.org/wiki/EasyTimeline for more information.

package TWiki::Plugins::EasyTimelinePlugin;

# =========================
use vars qw(
 $VERSION $RELEASE $pluginName $NO_PREFS_IN_TOPIC $SHORTDESCRIPTION $sandbox
);

use Digest::MD5 qw( md5_hex );

#the MD5 and hash table are used to create a unique name for each timeline
use File::Path;

our $VERSION = '$Rev$';
our $RELEASE = '1.2';
our $SHORTDESCRIPTION = 'Generate graphical timeline diagrams from markup text';
our $NO_PREFS_IN_TOPIC = 1;
our $pluginName = 'EasyTimelinePlugin';


# =========================
sub initPlugin {
    my ( $topic, $web ) = @_;
    
    # need a path to script in tool directory
    unless( $TWiki::cfg{Plugins}{$pluginName}{EasyTimelineScript} ){
        # throw error, do not init
        logWarning(
            "$pluginName cant find EasyTimeline.pl - Try running configure");
        return 0;
    }
    # need a path to Ploticus
    unless( $TWiki::cfg{Plugins}{$pluginName}{PloticusCmd} ){
        # throw error, do not init
        logWarning(
            "$pluginName cant find Ploticus (pl) - Try running configure");
        return 0;
    }

    # Plugin correctly initialized
    writeDebug(
        "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK");

    $sandbox = undef;

    return 1;
}

# =========================
sub commonTagsHandler {
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug("- ${pluginName}::commonTagsHandler( $_[2].$_[1] )")
      if $TWiki::cfg{Plugins}{$pluginName}{Debug};

    # Old syntax, using <easytimeline>.....</easytimeline>
    #$_[0] =~ s/<easytimeline>(.*?)<\/easytimeline>/&handleTimeline($1, $_[2], $_[1])/giseo;
    
    # New syntax, using %TIMELINE%.....%ENDTIMELINE%
    $_[0] =~ s/%TIMELINE%\s*(.*?)%ENDTIMELINE%/&handleTimeline($1, $_[2], $_[1])/egs;
}

# =========================
sub handleTimeline {
    
    my( $text, $web, $topic ) = @_;
    
    my $tmpDir  = TWiki::Func::getWorkArea( $pluginName ) . '/tmp/' . $pluginName . "$$";
    my $tmpFile = $tmpDir . '/' . $pluginName . "$$";
    my %hashed_math_strings = ();

    # Create topic directory "pub/$web/$topic" if needed
    my $dir = TWiki::Func::getPubDir() . "/$web/$topic";
    unless ( -e "$dir" ) {
        umask(002);
        mkpath( $dir, 0, 0755 )
          or return
          "!$pluginName Error: *folder $dir could not be created*";
    }

    # compute the MD5 hash of this string
    my $hash_code = md5_hex("EASYTIMELINE$text");

    # store the string in a hash table, indexed by the MD5 hash
    $hashed_math_strings{"$hash_code"} = $text;

    my $image = "${dir}/graph${hash_code}.png";

    # don't do anything if it already exists
    if ( open TMP, "$image" ) {
        close TMP;
    }
    else {

        # Create tmp dir
        unless ( -e "$tmpDir" ) {
            umask(002);
            mkpath( $tmpDir, 0, 0755 )
              or return "!$pluginName Error: *tmp folder $tmpDir could not be created*";
        }

        # convert links
        $text =~ s/\[\[([$TWiki::regex{mixedAlphaNum}\._\:\/-]*)\]\[([$TWiki::regex{mixedAlphaNum} \/&\._-]*)\]\]/&renderLink($1, $2, $web, $topic)/egs;
        
        # output the timeline text into the tmp file
        open OUTFILE, ">$tmpFile.txt"
          or return "!$pluginName Error: could not create file";
        print OUTFILE $text;
        close OUTFILE;

        # run the command and create the png
        my $cmd =
            'perl ' .
            $TWiki::cfg{Plugins}{$pluginName}{EasyTimelineScript} . # /var/www/twiki/tools/EasyTimeline.pl
            ' -i %INFILE|F% -m -P ' .
            $TWiki::cfg{Plugins}{$pluginName}{PloticusCmd} . # /usr/local/bin/pl
            ' -T %TMPDIR|F% -A ' .
            $TWiki::cfg{ScriptUrlPath} . 'view' . $TWiki::cfg{ScriptSuffix}; # /bin/view/
        &writeDebug("Command: $cmd");
        unless( $sandbox ) {
            if( $TWiki::Plugins::VERSION >= 1.1 ) {
            # Dakar provides a sandbox
            $sandbox = $TWiki::sharedSandbox ||
                $TWiki::sandbox;    # for TWiki 4.2
            } else {
                # in Cairo, must use the contrib package
                eval("use TWiki::Contrib::DakarContrib;");
                $sandbox = new TWiki::Sandbox();
            }
        }
        my ( $output, $status ) = $sandbox->sysCommand(
            $cmd,
            INFILE => $tmpFile . '.txt',
            TMPDIR => $tmpDir,
        );
        &writeDebug("$pluginName: output $output status $status");
        if ($status) {
            
            my @errLines;
            cleanTmp($tmpDir) unless $TWiki::cfg{Plugins}{$pluginName}{Debug};
            
            return &showError( $status, $output,
                $hashed_math_strings{"$hash_code"} );
        }
        if ( -e "$tmpFile.err" ) {

            # errors in rendering so remove created files
            open( ERRFILE, "$tmpFile.err" );
            my @errLines = <ERRFILE>;
            close(ERRFILE);
            cleanTmp($tmpDir) unless $TWiki::cfg{Plugins}{$pluginName}{Debug};
            return &showError( $status, $output, join( "", @errLines ) );
        }

        # Attach created png file to topic, but hide it pr. default.
        my @stats = stat "$tmpFile.png";
        TWiki::Func::saveAttachment(
            $web, $topic,
            "graph$hash_code.png",
            {
                file     => "$tmpFile.png",
                filesize => $stats[7],
                filedate => $stats[9],
                comment  => "!$pluginName: Timeline graphic",
                hide     => 1,
                dontlog  => 1
            }
        );

        if ( -e "$tmpFile.map" ) {

            # Attach created map file to topic, but hide it pr. default.
            my @stats = stat "$tmpFile.map";
            TWiki::Func::saveAttachment(
                $web, $topic,
                "graph$hash_code.map",
                {
                    file     => "$tmpFile.map",
                    filesize => $stats[7],
                    filedate => $stats[9],
                    comment  =>
                      "!$pluginName: Timeline clientside map file",
                    hide    => 1,
                    dontlog => 1
                }
            );

        }
        # Clean up temporary files
        cleanTmp($tmpDir) unless $TWiki::cfg{Plugins}{$pluginName}{Debug};
    }

    if ( -e "${dir}/graph${hash_code}.map" ) {

        open( MAP, "${dir}/graph${hash_code}.map" )
          || logWarning(
            "map ${dir}/graph${hash_code}.map exists but read failed");
        my $mapinfo = "";
        while (<MAP>) {
            $mapinfo .= $_;
        }
        close(MAP);
        $html = "<map name=\"${hash_code}\">$mapinfo</map>\n";
        $html .=
            "<img usemap=\"#${hash_code}\" src=\""
          . TWiki::Func::getPubUrlPath()
          . "/$web/$topic/"
          . "graph${hash_code}.png\">\n";
    }
    else {
        $html =
            "<img src=\""
          . TWiki::Func::getPubUrlPath()
          . "/$web/$topic/"
          . "graph${hash_code}.png\">\n";
    }
}

# converts TWiki style links into absolute Mediawiki style links that work with the EasyTimelne.pl script
sub renderLink {
    # [[$link][$title]]
    my ($link, $title, $web, $topic) = @_;
    
    if( $link =~ m!^http://! ){
        return "[[$link|$title]]"
    } else {
        my ( $linkedWeb, $linkedTopic ) = TWiki::Func::normalizeWebTopicName( '', $link );
        my $url = TWiki::Func::getScriptUrl( $linkedWeb, $linkedTopic, 'view' );
        return "[[$url|$title]]";
    }
}

# =========================
sub cleanTmp {
    my $dir    = shift;
    my $rmfile = "";
    if ( $dir =~ /^([-\@\w\/.]+)$/ ) {
        $dir = $1;
    }
    else {
        die "Couldn't untaint $dir";
    }
    opendir( DIR, $dir );
    my @files = readdir(DIR);
    while ( my $file = pop @files ) {
        if ( "$dir/$file" =~ /^([-\@\w\/.]+)$/ ) {
            $rmfile = $1;
        }
        else {
            die "Couldn't untaint $rmfile";
        }
        if ( ( $file !~ /^\./ ) && ( -f "$rmfile" ) ) {
            unlink("$rmfile");
        }
    }
    close(DIR);
    rmdir("$dir");
}

# =========================
sub showError {
    my ( $status, $output, $text ) = @_;

    $output =~ s/^.*: (.*)/$1/;
    my $line = 1;
    $text =~ s/\n/sprintf("\n%02d: ", $line++)/ges;
    $output .= "<pre>$text\n</pre>";
    return "<noautolink><span class='twikiAlert'>!$pluginName Error ($status): $output</span></noautolink>";
}

sub writeDebug {
    &TWiki::Func::writeDebug( "$pluginName - " . $_[0] ) if $TWiki::cfg{Plugins}{$pluginName}{Debug};
}

sub logWarning {
    TWiki::Func::writeWarning(@_);
}

1;
