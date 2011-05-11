# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2005 Arild Bergh
# Copyright (C) 2008-2011 TWiki Contributors
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
# This is a TWiki plugin which will cache a reference to a webpage
# in a topic to a local file, either as a new topic or as a linked data file
#
# =========================
package TWiki::Plugins::URLCachePlugin;    # change the package name and $pluginName!!!

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $RELEASE $pluginName
        $debug $exampleCfgVar
    );

$VERSION = '$Rev$';
$RELEASE = '2011-05-10';

$pluginName = 'URLCachePlugin';  # Name of this Plugin

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
# Plugin correctly initialized
    TWiki::Func::writeDebug( "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK" ) if $debug;
    return 1;
}

# this function returns (and creates if required) the correct directory inside the pub folder in
# the TWiki folder
sub getDirectory
{
    my ( $web, $topic ) = @_;
# Create web directory "pub/$web" if needed
    my $dir = TWiki::Func::getPubDir() . "/$web";
    unless( -e "$dir" ) {
        umask( 002 );
        mkdir( $dir, 0775 );
    }
# Create topic directory "pub/$web/$topic" if needed
    $dir .= "/$topic";
    unless( -e "$dir" ) {
        umask( 002 );
        mkdir( $dir, 0775 );
    }
    return "$dir";
}

#create a basic text only page
sub HTML2Twiki
{
    my $text = shift;
    my $url = shift;

    my $date = TWiki::Func::formatTime( time(), '$year-$mo-$day $hour:$min', 'servertime' );
    use HTML::FormatText; 
    use HTML::Parse;
    my $x = parse_html($text);
    my $ascii = HTML::FormatText->new->format($x); 
    my( $title ) = $text =~ m/<title.*?>(.*?)<\/title>/ig;
    return "---+ $title\n\n__Note:__ Downloaded from $url on $date\n\n$ascii";
}

#download the page to be cached
sub getPage
{
    my $url = shift;

    my $response = TWiki::Func::getExternalResource( $url );
    return "" if( $response->is_error() );
    return $response->content();
}

#download the url and save to file
sub mirrorUrl
{
    my $url = shift;
    my $file = shift;
    my $content = getPage( $url );
    if( $content ) {
        TWiki::Func::saveFile( $file, $content );
    }
}

# here's the main action which checks for http/https links and downloads them
sub beforeSaveHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead
#quit if this has the no-cache flag set
    if ($_[0] =~ /\Q<!--NOCACHE-->/){return;}
#is this a wiki that is not to be cached?
    my @ignore_webs = split( /, */, TWiki::Func::getPluginPreferencesValue("IGNORE"));
    my @hit = grep /$_[2]/, @ignore_webs;
    if (@hit){return;}

# to avoid recursive cahcing we have a flag, so only the original page that is being saved will be processed
    return if( $ALREADYHERE );
    $ALREADYHERE = 1;

    my $ltrs = '\w';
    my $gunk = '/#~:.?+=&%@!\-,';
    my $punc = '.:?\-';
    my $any  = "${ltrs}${gunk}${punc}";
    $_[0] =~ s/(^|\s)(\+?)(https? : [$any] +? )(?=[$punc]*[^$any]|$)/$1 . _cacheURL( $2, $3, $_[2], $_[1] )/igex;

    #reset the flag
    $ALREADYHERE = 0;
}

sub _cacheURL
{
    my( $plus, $url, $web, $topic ) = @_;

#set some inital variables
    my $twiki_pubdir = getDirectory( $web, $topic );
    my $twiki_url = TWiki::Func::getUrlHost() . TWiki::Func::getPubUrlPath() . "/$web/$topic";
    my $twiki_thisurl = TWiki::Func::getViewUrl($web, $topic );

    if( $plus ) {
#this is a +http url.
#first we do the ones that is to be new topics (i.e. searchable)
#here we strip off the tag, keep the title at top and make a note of where it's come from
        my $page_content = getPage( $url );
        if( $page_content =~ /^(.+)$/s ) {
            my $htmlpage = HTML2Twiki( $1, $url );
#whenever we have a successful download we first save the new topic
# and then do a search and replace and replace the link to the new topic
            my $newTopic = substr( $url, 6 );
            $newTopic =~ s/\W/ /g;
            $newTopic =~ s/(\w*) /\u\L$1/g;
            my $oops = TWiki::Func::saveTopicText( $web, $newTopic, $topic_header . $htmlpage, 1, 1); # save topic text 
            unless( $oops ) {
                return "[[$newTopic][$url]]";
            }
        }

    } else {
#normal http url.
#here we proces the list of files that we want to cahce separately
#we download each page and change the image & stylesheet links in it
        my $htmlpage = getPage( $url );
        if( $htmlpage ) {
            use HTML::LinkExtor;
            my $parser = HTML::LinkExtor->new(undef);
            $parser->parse( $htmlpage );
            my @pagelinks = $parser->links;
            use File::Basename;
            my $img = basename( $url );
            my $imageurl = $url;
            if( $img ) {
                $imageurl =~ s/\Q$img//;
            }
            foreach my $linkarray ( @pagelinks ) {
                my @element = @$linkarray;
                my $elt_type = shift @element;
                while( @element ) {
                    my ($attr_name, $attr_value) = splice(@element, 0, 2);
                    if (($elt_type eq 'img' && $attr_name eq 'src') || ($elt_type eq 'link' && $attr_name eq 'href')) {
                        $img = basename($attr_value);
#check if this image link already has a full URL in it
                        if ($attr_value =~ /^http/){
                            mirrorUrl( $attr_value, "$twiki_pubdir/$img" );
                            $htmlpage =~ s/\Q$attr_value/$img/igx;
                        } else {
                            mirrorUrl( "$imageurl$attr_value", "$twiki_pubdir/$img " );
                            $htmlpage =~ s/\Q$attr_value/$img/igx;
                        }
                    }
                }
            }
#finally we save the modified HTML page
            my $file = substr( $url, 6 );
            $file =~ s/\W//g;
#here we add a line at the top of the page showing that it's cached
            my $date = TWiki::Func::formatTime( time(), '$year-$mo-$day $hour:$min', 'servertime' );
            my $cachedfrom = "<div style='text-align: center;'><pre>Downloaded from <a href='$url'>$url</a> "
                           . "on $date\n<a href='$twiki_thisurl'>Return to TWiki</a></pre></div><hr />";
            $htmlpage =~ s/(<body.*?>)(.*?)/$1$2$cachedfrom/ig;
            TWiki::Func::saveFile( "$twiki_pubdir/$file.html", $htmlpage );
#whenever we have a successful download we do a search and replace and replace the link to the local
#cache rather than the online version [[ToRead][http://abergh.com/webmail]]
            return "[[$twiki_url/$file.html][$url]]";
        }
    }
    return $url;
}

1;
