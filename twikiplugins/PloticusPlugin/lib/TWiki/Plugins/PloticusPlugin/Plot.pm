
package TWiki::Plugins::PloticusPlugin::Plot;

require TWiki::Plugins::PloticusPlugin::PlotSettings;

use strict;
use Assert;

my $debug = 0;

sub new{
    my ($class, $web, $topic, $plotName) = @_;
    $debug = $TWiki::Plugins::PloticusPlugin::debug;
    TWiki::Func::writeDebug( "PloticusPlugin::Plot::new - Creating new Plot with name $plotName" ) if $debug;
    my $self = {};
    $self->{WEB}   = $web;
    $self->{TOPIC} = $topic;
    $self->{NAME}  = $plotName;
    $self->{PATH}  = TWiki::Func::getPubDir() . "/$web/$topic";
    $self->{PLOTICUSFILE} = "$plotName.ploticus";
    $self->{PNGFILE} = "$plotName.png";
    $self->{ERRFILE} = "$plotName.err";
#    $self->{SETTINGS} = [];

    bless ($self, $class);
    return $self;    
}


sub render{
    my $self = shift;    
    TWiki::Func::writeDebug( "PloticusPlugin::Plot::render - Rendering $self->{NAME}" ) if $debug;

    my $renderedText = "<a name=\"ploticusplot" . $self->{NAME} . "\"></a>\n";
    my $ploticusFile = $self->{PATH} . "/" . $self->{PLOTICUSFILE};
    my $ploticusTmpFile = "/tmp/" . $self->{PLOTICUSFILE};
    my $pngFile = $self->{PATH} . "/" . $self->{PNGFILE};
    if (-e $ploticusFile) 
    { 
        parseFile($self, $ploticusFile, $ploticusTmpFile);
        my $errFile = $self->{PATH} . "/" . $self->{ERRFILE};

        # Update $exePath to fit your environment
        my $exePath = "/usr/bin/ploticus";
        my $execCmd = "cd $self->{PATH} && $exePath -f $ploticusTmpFile -png -o $pngFile 2> $errFile ";    
        TWiki::Func::writeDebug( "PloticusPlugin::Plot::render - Exe Path: $exePath" ) if $debug;
        TWiki::Func::writeDebug( "PloticusPlugin::Plot::render - Executing $execCmd" ) if $debug;
	system($execCmd);
        if(-s $pngFile)
        {
            $renderedText .= "%ATTACHURL%/$self->{PNGFILE}\n\n";
        }
        else
        {
            $renderedText .= "*PloticusPlugin Error:* Cannot display the plot because the image file ($self->{PNGFILE}) has zero size. With a bit of luck the reason for this will be shown below.\n---\n"
        }
        if(-s $errFile)
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
        $renderedText .= editPlotSettingsButton($self);
    }
    else
    {
        TWiki::Func::writeDebug( "PloticusPlugin::Plot::render - $ploticusFile does not exist" ) if $debug;
        $renderedText = "No settings found for this plot (<nop>$self->{PLOTICUSFILE} not found). Click on the Edit button below to generate and edit the settings for this plot.\n";
        $renderedText .= "\n" . editPlotSettingsButton($self);
    }
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
