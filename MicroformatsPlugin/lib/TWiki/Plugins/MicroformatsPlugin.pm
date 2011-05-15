# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2008 TWiki:Main.SvenDowideit
# Copyright (C) 2008-2011 TWiki Contributors
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 3
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html

=pod

---+ package TWiki::Plugins::MicroformatsPlugin

=cut


package TWiki::Plugins::MicroformatsPlugin;

require TWiki::Func;    # The plugins API
require TWiki::Plugins; # For the API version
use Time::ParseDate;

use vars qw( $VERSION $RELEASE $SHORTDESCRIPTION $debug $pluginName $NO_PREFS_IN_TOPIC 
    $enablehCardOnUserTopic %isUserTopic);

$VERSION = '$Rev$';
$RELEASE = '2011-05-14';
$SHORTDESCRIPTION = 'Microformat support for TWiki';
$NO_PREFS_IN_TOPIC = 1;
$pluginName = 'MicroformatsPlugin';

=pod

---++ initPlugin($topic, $web, $user, $installWeb) -> $boolean
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$user= - the login name of the user
   * =$installWeb= - the name of the web the plugin is installed in

=cut

sub initPlugin {
    my( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.026 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }
    
    #TODO: should reset $isUserTopic{$key} in _finish()

    $debug = $TWiki::cfg{Plugins}{MicroformatsPlugin}{Debug} || 0;
    TWiki::Func::registerTagHandler( 'HCARD', \&_HCARD );
    TWiki::Func::registerTagHandler( 'HEVENT', \&_HEVENT );
    #TWiki::Func::registerRESTHandler('example', \&restExample);
    
    my $enableMicroIds = $TWiki::cfg{Plugins}{MicroformatsPlugin}{enableMicroIds} || 1;
    $enablehCardOnUserTopic = $TWiki::cfg{Plugins}{MicroformatsPlugin}{enablehCardOnUserTopic} || 1;
    if (($enableMicroIds) && (_isUserTopic($web, $topic))) {
        addMicroIDToHEAD($web, $topic);
    }
    if ($enablehCardOnUserTopic && _isUserTopic($web, $topic)) {
        #yes, this is woeful
        #TODO: find a repliable way to addd arbitary content to a topic view.
        $enablehCardOnUserTopic = 0;
        #$_[0] = "%HCARD{'$web.$topic'}%".$_[0];
        #TWiki::Func::addToHEAD('hCard', 
        #    "<div type='hcard' style='display:none;'>%HCARD{\"$web.$topic\"}%</div>");
    }

    # Plugin correctly initialized
    return 1;
}

sub addMicroIDToHEAD {
    my $web = shift;
    my $topic = shift;
    #code here adapted from Web::MicroID - not using it yet
    my $algorithm = $TWiki::cfg{Plugins}{MicroformatsPlugin}{MicroIdAlgol} || 'sha1';

    my $algor;
    if ($algorithm eq 'md5')  {
        require Digest::MD5;
        $algor = Digest::MD5->new;
    } else {
        require Digest::SHA1;
        $algor = Digest::SHA1->new;
    }

    # Hash the ID's
    my @emails = TWiki::Func::wikinameToEmails($topic);
    #TODO: maybe make one microid per known email?
    if (scalar(@emails) > 0) {
        my $indv = $algor->add($emails[0])->hexdigest();
        $algor->reset();
        my $serv = $algor->add(TWiki::Func::getViewUrl( $web, $topic))->hexdigest();
        $algor->reset();

        # Hash the ID's together and set as the legacy MicroID token
        my $hash = $algor->add($indv . $serv)->hexdigest();

        #TODO: need to extract the mailto and http from the id's
        #TODO: watch out, the + will soon be replaced, due to html validation errors
        my $microid = 'mailto+http:'.$algorithm.':'.$hash;
        my $header = '<meta name="microid" content="'.$microid.'"/>';

        TWiki::Func::addToHEAD('http://microid.org', $header);
    }

    return;
}

sub _isUserTopic {
    my $web = shift;
    my $topic = shift;
    
    my $key = "$web.$topic";

    return $isUserTopic{$key} if defined($isUserTopic{$key});
    $isUserTopic{$key} = 0;
    if (
        ($web eq TWiki::Func::getMainWebname()) &&
        (TWiki::Func::topicExists($web, $topic)) &&
        (defined(TWiki::Func::wikiToUserName("$web.$topic")))
        ) {
        $isUserTopic{$key} = 1;
    }
    return $isUserTopic{$key};
}

sub _HCARD {
    my($session, $params, $theTopic, $theWeb) = @_;

    my $wikiName;
    if (defined($params->{_DEFAULT}) &&
        (_isUserTopic(TWiki::Func::normalizeWebTopicName(TWiki::Func::getMainWebname(), $params->{_DEFAULT})))) {
        $wikiName = $params->{_DEFAULT}
    } else {
        $wikiName = TWiki::Func::getWikiName();
    }
    my $hCardTmpl = TWiki::Func::readTemplate('hcard');

    $hCardTmpl =~ s/%HCARDUSER%/$wikiName/ge;
    $hCardTmpl =~ s/%HCARDNAME%/$wikiName/ge;
    
    my $hCardCss = TWiki::Func::readTemplate('hcardcss');
    TWiki::Func::addToHEAD('hCardCss', $hCardCss);

    return "$hCardTmpl";
}

sub _HEVENT {
    my($session, $params, $theTopic, $theWeb) = @_;

    my $start = $params->{start} || '';
    my $end = $params->{end} || '';
    my $url = $params->{url} || '';
    my $location = $params->{location} || '';
    my $description = $params->{description} || '';
    my $summary = $params->{summary} || $description || $start;
    
    my $hCalendarTmpl = TWiki::Func::readTemplate('hevent');

    $hCalendarTmpl =~ s/%HSTART%/$start/ge;
    $hCalendarTmpl =~ s/%HEND%/$end/ge;
    $hCalendarTmpl =~ s/%HURL%/$url/ge;
    $hCalendarTmpl =~ s/%HLOCATION%/$location/ge;
    $hCalendarTmpl =~ s/%HSUMMARY%/$summary/ge;
    $hCalendarTmpl =~ s/%HDESCRIPTION%/$description/ge;
    
    my $calname = $summary;
    $calname =~ s/[^\d]//;
    $hCalendarTmpl =~ s/%HCALNAME%/$calname/ge;
    $hCalendarTmpl =~ s/\n//g;
    
#print STDERR "HEVENT> $start - $summary\n";

    my $hCalendarCss = TWiki::Func::readTemplate('hcardcss');
    TWiki::Func::addToHEAD('hCardCss', $hCalendarCss);

    return "$hCalendarTmpl";
}

=pod

---++ preRenderingHandler( $text, \%map )
   * =$text= - text, with the head, verbatim and pre blocks replaced with placeholders
   * =\%removed= - reference to a hash that maps the placeholders to the removed blocks.

Handler called immediately before TWiki syntax structures (such as lists) are
processed, but after all variables have been expanded. Use this handler to 
process special syntax only recognised by your plugin.

Placeholders are text strings constructed using the tag name and a 
sequence number e.g. 'pre1', "verbatim6", "head1" etc. Placeholders are 
inserted into the text inside &lt;!--!marker!--&gt; characters so the 
text will contain &lt;!--!pre1!--&gt; for placeholder pre1.

Each removed block is represented by the block text and the parameters 
passed to the tag (usually empty) e.g. for
<verbatim>
<pre class='slobadob'>
XYZ
</pre>
the map will contain:
<pre>
$removed->{'pre1'}{text}:   XYZ
$removed->{'pre1'}{params}: class="slobadob"
</pre>
Iterating over blocks for a single tag is easy. For example, to prepend a 
line number to every line of every pre block you might use this code:
<verbatim>
foreach my $placeholder ( keys %$map ) {
    if( $placeholder =~ /^pre/i ) {
       my $n = 1;
       $map->{$placeholder}{text} =~ s/^/$n++/gem;
    }
}
</verbatim>

__NOTE__: This handler is called once for each rendered block of text i.e. 
it may be called several times during the rendering of a topic.

__NOTE:__ meta-data is _not_ embedded in the text passed to this
handler.

Since TWiki::Plugins::VERSION = '1.026'

=cut

sub beforeCommonTagsHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    #my( $text, $pMap ) = @_;
    
return unless (TWiki::Func::getContext()->{'view'});

    my $foundTime=0;
    my @processedText;
    my @lines = split( /([\n\r]+)/, $_[0] );
    foreach my $line (@lines) {
        my $bullet = '';
        my $recurring = '';
        if ($line =~ s/^(\s+[*\d]\s+)//) {        #CalendarPlugin style - bullets.
            $bullet = $1;
            if ($line =~ s/([wLAE]\s+)//) {
                $recurring = $1;
            }
        }
        #NOTE: parsedate needs the date to be at the begining of the string
        my ($seconds, $remaining) = parsedate($line, FUZZY => 1);
        if (defined($seconds) && ($seconds ne '')) {
            #print STDERR "> ".TWiki::Func::formatTime($seconds)." : $remaining ($line)\n";
            
            my $newline = ($bullet).($recurring)."\%HEVENT{start=\"".TWiki::Func::formatTime($seconds, '$iso')."\" summary=\"$remaining\"}\%";
            print STDERR ">>> $newline\n";
            push(@processedText, $newline);
            $foundTime++;
        } else {
            #print STDERR "ERROR : $remaining  ($line)\n";
            push(@processedText, $line);
        }
    }
    if ($foundTime>0) {
        $_[0] = join('', @processedText);
    }
}

1;
