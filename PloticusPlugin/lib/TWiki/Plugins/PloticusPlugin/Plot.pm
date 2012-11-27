
package TWiki::Plugins::PloticusPlugin::Plot;

require TWiki::Plugins::PloticusPlugin::PlotSettings;

use strict;
use Assert;

my $debug = 0;
my $pluginName = "";

sub new{
    my ($class, $web, $topic, $plotName, $inlineDataFile, $hashCode) = @_;
    $debug = $TWiki::Plugins::PloticusPlugin::debug;
    $pluginName = $TWiki::Plugins::PloticusPlugin::pluginName;
    TWiki::Func::writeDebug( "PloticusPlugin::Plot::new - Creating new Plot with name $plotName" ) if $debug;
    my $self = {};
    $self->{WEB}   = $web;
    $self->{TOPIC} = $topic;
    $self->{NAME}  = $plotName;
    $self->{PATH}  = TWiki::Func::getPubDir($web) . "/$web/$topic";
    $self->{PLOTICUSFILE} = "$plotName.ploticus";
    $self->{PNGFILE} = "$plotName.png";
    $self->{ERRFILE} = "$plotName.err";
    $self->{HASHFILE} = "$plotName-hash.txt";
    $self->{INLINEDATAFILE} = $inlineDataFile || "";
    $self->{HASHCODE} = $hashCode || "";

    bless ($self, $class);
    return $self;    
}

use File::stat;

sub render{
    my $self = shift;
    TWiki::Func::writeDebug( "PloticusPlugin::Plot::render - Rendering $self->{NAME}" ) if $debug;

    my $web = $self->{WEB};
    my $topic = $self->{TOPIC};
    my $renderedText = "<a name=\"ploticusplot" . $self->{NAME} . "\"></a>\n";
    my $ploticusFile = $self->{PATH} . "/" . $self->{PLOTICUSFILE};
    my $ploticusTmpFile = "/tmp/" . $self->{PLOTICUSFILE};
    my $pngFile = $self->{PATH} . "/" . $self->{PNGFILE};
    my $hashFile = $self->{PATH} . "/" . $self->{HASHFILE};
    my $flattenedWeb = $web;
    $flattenedWeb =~ s:/:.:g;
    my $prefix = "/tmp/$pluginName$flattenedWeb$topic";
    my $errFile = $prefix . $self->{ERRFILE};
    my $tmpPngFile = $prefix . $self->{PNGFILE};
    my $tmpHashFile = $prefix . $self->{HASHFILE};
    my $editable = 0;
    my ($meta, $text) = TWiki::Func::readTopic($web, $topic);

    if (TWiki::Func::checkAccessPermission(
        'CHANGE', TWiki::Func::getWikiName(), $text, $topic, $web, $meta)) {
        $editable = 1;
    }

    if ( defined &TWiki::Func::webWritable ) {
        $editable = 0 unless ( TWiki::Func::webWritable($web) ); 
    }

    if (-e $ploticusFile || $self->{INLINEDATAFILE} ) 
    { 
	if ( $self->{INLINEDATAFILE} ) {
	    $ploticusTmpFile = $self->{INLINEDATAFILE};
	}
	else {
	    if ( my $pngSt = stat($pngFile) ) {
		my $plSt;
		$plSt = stat($ploticusFile) and do {
		    if ( $pngSt->size && $pngSt->mtime > $plSt->mtime ) {
			return $renderedText . 
			    "%ATTACHURL%/$self->{PNGFILE}\n\n" .
			    ($editable ? $self->editPlotSettingsButton() : "");
		    }
		};
	    }
	    parseFile($self, $ploticusFile, $ploticusTmpFile);
	}

        # Update $ploticusPath, $ploticusHelperPath and $execCmd to fit your environment
        my $ploticusPath = $TWiki::cfg{PloticusPath};
        my $ploticusHelperPath = "$TWiki::twikiRoot/tools/ploticus.pl";
        my $execCmd = "$TWiki::cfg{PerlPath} %HELPERSCRIPT|F% %PLOTICUS|F% %WORKDIR|F% %INFILE|F% %FORMAT|S% %OUTFILE|F% %ERRFILE|F% ";
        TWiki::Func::writeDebug( "PloticusPlugin::Plot::render - Ploticus path: $ploticusPath" ) if $debug;
        TWiki::Func::writeDebug( "PloticusPlugin::Plot::render - Ploticus helper path: $ploticusHelperPath" ) if $debug;
        TWiki::Func::writeDebug( "PloticusPlugin::Plot::render - Executing $execCmd in sandbox" ) if $debug;
        TWiki::Func::writeDebug( "PloticusPlugin::Plot::render - errorfile set to $errFile" ) if $debug;
        my $sandbox = new TWiki::Sandbox( $TWiki::cfg{OS}, $TWiki::cfg{DetailedOS} ); 
        $ENV{GDFONTPATH} = '/ms/dist/fsf/PROJ/fonts/incr/microsoft';
        my ($output, $status) = $sandbox->sysCommand(
		  $execCmd,
          HELPERSCRIPT => $ploticusHelperPath,
          PLOTICUS => $ploticusPath,
          WORKDIR => $self->{PATH},
          INFILE => $ploticusTmpFile,
          'FORMAT' => 'png',
          OUTFILE => $tmpPngFile,
          ERRFILE => $errFile
        );
        TWiki::Func::writeDebug("ploticus-sandbox: output $output status $status") if $debug;
        if (-s $tmpPngFile)
        {
            $renderedText .= "%ATTACHURL%/$self->{PNGFILE}\n\n";
	    my $st = stat($tmpPngFile);
            TWiki::Func::saveAttachment(
                $web, $topic,
                $self->{PNGFILE},
                {
                    file     => $tmpPngFile,
                    filesize => $st->size,
                    filedate => $st->mtime,
                    comment  =>
                      '<nop>PloticusPlugin: chart',
                    hide    => 1,
                    dontlog => 1
                }
            );
	    if ( $self->{HASHCODE} ) {
		open(HASH, "> $tmpHashFile");
		print HASH $self->{HASHCODE}, "\n";
		close(HASH);
		my $st = stat($tmpHashFile);
		if ( $st && $st->size ) {
		    TWiki::Func::saveAttachment(
			$web, $topic,
			$self->{HASHFILE},
			{
			    file     => $tmpHashFile,
			    filesize => $st->size,
			    filedate => $st->mtime,
			    comment  =>
			      '<nop>PloticusPlugin: chart data hash value',
			    hide    => 1,
			    dontlog => 1
			}
		    );
		};
	    }
        }
        else
        {
            $renderedText .= "*PloticusPlugin Error:* Cannot display the plot because the image file ($self->{PNGFILE}) has zero size. With a bit of luck the reason for this will be shown below.\n---\n"
        }
        if (-s $errFile)
        {
            open (ERRFILE, $errFile);
            my @errLines = <ERRFILE>;
            for (@errLines)
            {
                if(/($self->{PATH})/)
                {
                    my $maskedPath = $1;
                    $maskedPath =~ tr/[a-z][A-Z][0-9]\//\*/;
                    s/$self->{PATH}/$maskedPath/g;
                }
            }
            $renderedText .= "*Ploticus Error:* <verbatim>" . join("", @errLines) . "</verbatim>";
        }
        $renderedText .= $self->editPlotSettingsButton() if ( $editable );
    }
    else
    {
        TWiki::Func::writeDebug( "PloticusPlugin::Plot::render - $ploticusFile does not exist" ) if $debug;
        $renderedText = "No settings found for this plot (<nop>$self->{PLOTICUSFILE} not found). Click on the Edit button below to generate and edit the settings for this plot.\n";
        $renderedText .= "\n" . $self->editPlotSettingsButton() if ( $editable );
    }
    unlink $ploticusTmpFile, $tmpPngFile, $tmpHashFile, $errFile,
	"$pngFile,v", "$hashFile,v";
    return $renderedText;
}

sub parseFile {
    my ($self, $ploticusFile, $ploticusTmpFile) = @_;
    TWiki::Func::writeDebug( "PloticusPlugin::Plot::readFile - Reading settings from $ploticusFile" ) if $debug;
    open (INFILE, $ploticusFile) or return newFile();
    open (OUTFILE, ">", $ploticusTmpFile) or die;
    while (<INFILE>) {
        if (/^\s*$/ or /^\<p\s*\//)
        {
            print OUTFILE " \n";
            next; 
        }
        print OUTFILE $_;
    }
    close OUTFILE;
}

sub editPlotSettingsButton {
    my $self = shift;
    my $text = '';
    $text .= "<form action='" . TWiki::Func::getScriptUrl( "$self->{WEB}", "$self->{TOPIC}", "view" ) . "#ploticusplot".$self->{NAME}."' method=\"post\" >\n";
    $text .= "<input type=\"hidden\" name=\"ploticusPlotName\" value=\"$self->{NAME}\" />\n";
    $text .= "<input type=\"hidden\" name=\"ploticusPlotAction\" value=\"edit\" />\n";
    $text .= "<input type=\"submit\" value=\"Edit Plot Settings\" class=\"twikiSubmit\"></input>\n";
    $text .= "</form>\n";
    return $text;
}





sub buildPlotString {
    my $self = shift;
    my $plotString = shift;
    my @inPlots = split(/,/, $plotString);
    my @outPlots = ();
    foreach (@inPlots)
    {
        if (/('.*')/)
        {
            my $plotSpec = $_;
            my $dataFile = substr($1,1);
            chop($dataFile);
            my $fullPathToDataFile = $self->{PATH} . "/" . $dataFile;
            $plotSpec =~ s/$dataFile/$fullPathToDataFile/;
            unless ($plotSpec =~ /title/)
            {
                $plotSpec .= " title \"" . $dataFile . "\"";
            }
            if(-e $fullPathToDataFile)
            {
                push(@outPlots,  $plotSpec );
            }
        }
        else
        {
             push(@outPlots, $_);
        }
    }
    return join(", ", @outPlots);
}
1;
