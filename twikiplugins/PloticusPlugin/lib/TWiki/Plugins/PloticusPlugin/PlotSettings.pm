
package TWiki::Plugins::PloticusPlugin::PlotSettings;

require TWiki::Plugins::PloticusPlugin;

use strict;
use Assert;

my $debug = 0;

sub fromFile{
    my ($class, $web, $topic, $plotName) = @_;
    $debug = $TWiki::Plugins::PloticusPlugin::debug;
    TWiki::Func::writeDebug( "PloticusPlugin::PlotSettings::fromFile - Creating new PlotSettings Object from file for $web / $topic / $plotName" );
    my $self = {};
    $self->{WEB}   = $web;
    $self->{TOPIC} = $topic;
    $self->{NAME}  = $plotName;
    $self->{TEXT}  = undef;
#    $self->{SETTINGS} = [];

    my $ploticusFile = buildFileName($web, $topic, $plotName);
    $self->{TEXT} = readFile($ploticusFile);
    
    bless ($self, $class);
    return $self;    
}

sub buildFileName{
    my ($web, $topic, $plotName) = @_;
    return TWiki::Func::getPubDir() . "/$web/$topic/$plotName.ploticus";
}
sub readFile {
    my $ploticusFile = $_[0];
    TWiki::Func::writeDebug( "PloticusPlugin::PlotSettings::readFile - Reading settings from $ploticusFile" ) if $debug;
    open (INFILE, $ploticusFile) or return newFile();
    my $content = '';
    while (<INFILE>)
    {
        if (/^\s*$/ or /^\<p\s*\// )
        {
            $content .= " \n";
            next; 
        }
        $content .= $_;
    }
    return $content;
}

sub writeFile{
    my ($web, $topic, $plotName, $text) = @_;
    my $webDir = TWiki::Func::getPubDir() . "/$web";
    unless (-e $webDir) { mkdir $webDir };
    unless (-e "$webDir/$topic") { mkdir "$webDir/$topic" };
    my $ploticusFile =  "$webDir/$topic/$plotName.ploticus";
    TWiki::Func::writeDebug( "PloticusPlugin::PlotSettings::writeFile - Writing ---=$text=--- to $ploticusFile" );# if $debug;
    open (OUTFILE, ">", $ploticusFile) or die "Cannot create new Ploticusplot file!";
    TWiki::Func::writeDebug( "PloticusPlugin::PlotSettings::writeFile - Writing ---=$text=--- to $ploticusFile" );# if $debug;
    print OUTFILE "$text";
    close OUTFILE;
}

sub newFile{
    TWiki::Func::writeDebug( "PloticusPlugin::PlotSettings::newFile - Creating new default settings" ) if $debug;
    my $text = '';
    $text .= "// simple vertical bars example - replace this with your own plot\n";
    $text .= "\n";
    $text .= "#proc areadef\n";
    $text .= "rectangle: 1 1 4 2\n";
    $text .= "xrange: 0 5\n";
    $text .= "yrange: 0 100\n";
    $text .= "\n";
    $text .= "#proc xaxis:\n";
    $text .= "stubs: text\n";
    $text .= "Africa\n";
    $text .= "America\n";
    $text .= "Asia\n";
    $text .= "Europe,\\nAustralia,\\nPacific\n";
    $text .= "\n";
    $text .= "#proc yaxis\n";
    $text .= "label: Growth Rate\n";
    $text .= "stubs: inc 20\n";
    $text .= "minortics: yes\n";
    $text .= "minorticinc: 5\n";
    $text .= "\n";
    $text .= "#proc getdata\n";
    $text .= "data: 76 \n";
    $text .= "54\n";
    $text .= "60\n";
    $text .= "59\n";
    $text .= "\n";
    $text .= "#proc bars\n";
    $text .= "lenfield: 1\n";
    $text .= "color: teal\n";
    $text .= "barwidth: 0.2\n";
    return $text;
}


sub render{
    my $self = shift;
#    $self->{WEB}   
#    $self->{TOPIC}
#    $self->{NAME} 
#    $self->{TEXT}  
    my $text = '';
    $text .= "*Edit Settings for !$self->{NAME}*\n";
    $text .= "<a name=\"ploticusplot" . $self->{NAME} . "\"></a>\n";
    $text .= "<form action=" . TWiki::Func::getScriptUrl( "$self->{WEB}", "$self->{TOPIC}", "view" ) . "\#ploticusplot$self->{NAME}\" method=\"post\">\n";
    $text .= "<table>\n";
    $text .= "  <tr valign=\"middle\">\n";
    $text .= "    <td><textarea  rows=\"10\" cols=\"90\" name=\"ploticusPlotSettingsText\" >$self->{TEXT}</textarea>\n";
    $text .= "    </td>\n";
    $text .= "    <td><input  type=\"submit\" value=\"Save Settings\" class=\"twikiSubmit\" /><br>\n";
    $text .= "        <a target=\"PloticusPlugin\" onclick=\"return launchWindow('TWiki','PloticusPlugin')\" href=\"/twiki/bin/view/TWiki/PloticusPlugin\">PloticusPlugin help</a><br>\n";
    $text .= "        <a target=\"PloticusHelp\" onclick=\"return launchWindow('TWiki','PloticusHelp')\" href=\"/twiki/bin/view/TWiki/PloticusHelp\">Ploticus help</a>\n";
    $text .= "    </td>\n";
    $text .= "  </tr>\n";
    $text .= "</table>\n";
    $text .= "<input type=\"hidden\" name=\"ploticusPlotName\" value=\"$self->{NAME}\" />";
    $text .= "<input type=\"hidden\" name=\"ploticusPlotAction\" value=\"save\" />";
    $text .= "</form>\n";
    return $text;
}


1;
