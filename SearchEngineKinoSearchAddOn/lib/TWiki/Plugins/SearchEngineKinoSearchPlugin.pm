package TWiki::Plugins::KinoSearchPlugin;

use TWiki::Contrib::SearchEngineKinoSearchAddOn::Search;
use TWiki::Contrib::SearchEngineKinoSearchAddOn::Index;

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $RELEASE $debug
        $exampleCfgVar $webName $topicName
    );

$VERSION = '$Rev: 8749 $';
$RELEASE = 'bodge';
$SHORTDESCRIPTION = 'Kino Search Plugin (mmm not sure if this will work)';
$NO_PREFS_IN_TOPIC = 1;
$pluginName = 'KinoSearch';

sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    if( $TWiki::Plugins::VERSION < 1.026  ) {
        &TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    TWiki::Func::registerTagHandler('KINOSEARCH', \&_KINOSEARCH);

    return 1;
}

sub _KINOSEARCH {
    my($session, $params, $theTopic, $theWeb) = @_;

    my $ret = "";
    my $format = $params->{format}||"\$icon <b>\$match</b> <span class='twikiAlert'>\$locked</span> <br />\$texthead<br /><hr />";
    $format =~ s/\$icon/%ICON%/go;
    $format =~ s/\$match/%MATCH%/go;
    $format =~ s/\$locked/%LOCKED%/go;
    $format =~ s/\$texthead/%TEXTHEAD%/go;

    my $docs = TWiki::Contrib::SearchEngineKinoSearchAddOn::Search->docsForQuery($params->{_DEFAULT});

    while( my $hit = $docs->fetch_hit_hashref ) {
        my $resweb   = $hit->{web};
        my $restopic = $hit->{topic};

        # For partial name search of topics, just hold the first part of the string
        if($restopic =~ m/(\w+)/) { $restopic =~ s/ .*//; }

        # topics moved away maybe are still indexed on old web
        next unless &TWiki::Func::topicExists( $resweb, $restopic );

        my $wikiusername = TWiki::Func::getWikiName();
        if( ! TWiki::Func::checkAccessPermission('VIEW', $wikiusername, undef, $restopic, $resweb, undef) ) {
            next;
        }

        $ret .= TWiki::Contrib::SearchEngineKinoSearchAddOn::Search->renderHtmlStringFor($hit,$format,0,0);
    }

    return "$ret";
}

sub afterSaveHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    ### my ( $text, $topic, $web, $error, $meta ) = @_;
    my $web = $_[2];
    my $topic = $_[1];
    my $indexer = TWiki::Contrib::SearchEngineKinoSearchAddOn::Index->newUpdateIndex();
    my @topicsToUpdate = ($topic);
    $indexer->removeTopics($web, @topicsToUpdate);
    $indexer->addTopics($web, @topicsToUpdate);
}

sub afterRenameHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    ### my ( $oldWeb, $oldTopic, $oldAttachment, $newWeb, $newTopic, $newAttachment ) = @_;
    my $oldweb = $_[0];
    my $oldtopic = $_[1];
    my $newweb = $_[3];
    my $newtopic = $_[4];

    my $indexer = TWiki::Contrib::SearchEngineKinoSearchAddOn::Index->newUpdateIndex();
    my @topicsToUpdate = ($oldtopic);
    $indexer->removeTopics($oldweb, @topicsToUpdate);
    my @topicsToUpdate = ($newtopic);
    $indexer->addTopics($newtopic, @topicsToUpdate);
}

sub afterAttachmentSaveHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    ###   my( $attrHashRef, $topic, $web ) = @_;
    my $web = $_[2];
    my $topic = $_[1];
    my $indexer = TWiki::Contrib::SearchEngineKinoSearchAddOn::Index->newUpdateIndex();
    my @topicsToUpdate = ($topic);
    $indexer->removeTopics($web, @topicsToUpdate);
    $indexer->addTopics($web, @topicsToUpdate);
}

1;
