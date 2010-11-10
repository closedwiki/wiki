#
# TWiki WikiClone ($wikiversion has version info)
#
# Copyright (C) 2000-2001 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001 Peter Thoeny, Peter[at]Thoeny.org
# Copyright (C) 2006 TWiki:Main.JeffCrawford
# Copyright (C) 2006-2010 TWiki Contributors. All Rights Reserved.
# TWiki Contributors are listed in the AUTHORS file in the root of
# this distribution. NOTE: Please extend that file, not this notice.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at 
# http://www.gnu.org/copyleft/gpl.html

# =========================
package TWiki::Plugins::TopicReferencePlugin;

use strict;

# =========================
use vars qw( $VERSION $RELEASE $debug $pluginName );

$VERSION = '1.002';
$RELEASE = '2010-11-09';
$pluginName= 'TopicReferencePlugin';

# =========================
sub initPlugin
{
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1 ) {
        &TWiki::Func::writeWarning( "Version mismatch between TopicReferencePlugin and Plugins.pm" );
        return 0;
    }

    # Get plugin debug flag
    $debug = &TWiki::Func::getPreferencesFlag( "TOPICREFERENCEPLUGIN_DEBUG" );

    # Plugin correctly initialized
    &TWiki::Func::writeDebug( "- TWiki::Plugins::TopicReferencePlugin::initPlugin( $web.$topic ) is OK" ) if $debug;
    return 1;
}

# =========================
sub commonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    &TWiki::Func::writeDebug( "- ${pluginName}::commonTagsHandler( $_[2].$_[1] )" ) if $debug;

    # This is the place to define customized tags and variables
    # Called by sub handleCommonTags, after %INCLUDE:"..."%

    # Find code tag and replace
    $_[0] =~ s/%TOPICREFERENCELIST{(.*?)}%/&handleTopicRefList($_[2], $1)/ge;

}
# =========================
sub handleTopicRefList
{
    my $currweb = shift;
    my $tag = shift;
    my $type = "orphans";
    my $web = $currweb;
    my %params;
    my $out = "";
    my $key;
    my $topic;

    %params = TWiki::Func::extractParameters( $tag );

    if(exists($params{_DEFAULT}))
    {
        $type = $params{_DEFAULT}; 
    }

    $type =~ s/['"]//g;

    if(exists($params{web}))
    {
        $web = $params{web};
    }
    $web =~ s/['"]//g;

    if(!TWiki::Func::webExists($web))
    {
        $out = "Web does not exist. Can't create reference list.";
        return $out;
    }

    # get list of topics in the web
    my @topics = TWiki::Func::getTopicList($web);
    my %topicrefs;

    # init the reference counts
    foreach $topic (@topics)
    {
        $topicrefs{$topic} = 0;
    }

    # count the references
    foreach $topic (@topics)
    {
        my $topictext = TWiki::Func::readTopicText($web, $topic, "", 1);

        foreach $key (keys(%topicrefs))
        {
            if($key ne $topic)
            {
                if($topictext =~ /$key/gs)
                {
                    $topicrefs{$key} += 1;
                }
            }
        }
    }

    my $text = 'return "   * [[$key]] ($topicrefs{$key})\n"';
    if($web ne $currweb)
    {
        $text = 'return "   * [[$web.$key]] ($topicrefs{$key})\n"';
    }

    # print the results
    if($type eq "all")
    {
        foreach $key (keys(%topicrefs))
        {
             $out .=  eval $text ;
        }
    }
    elsif($type eq "orphans")
    {
        foreach $key (keys(%topicrefs))
        {
            if($topicrefs{$key} == 0)
            {
                 $out .=  eval $text ;
            }
        }
    }
    elsif($type eq "hasref")
    {
        foreach $key (keys(%topicrefs))
        {
            if($topicrefs{$key} > 0)
            {
                 $out .=  eval $text ;
            }
        }
    }
    else
    {
        $out = "Unsupported type: '$type'\n";
    }

    return $out;
}


# =========================
1;

