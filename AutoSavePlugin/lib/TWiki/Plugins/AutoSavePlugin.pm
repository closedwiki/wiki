package TWiki::Plugins::AutoSavePlugin;

use strict;

use vars qw( $VERSION $RELEASE $SHORTDESCRIPTION $debug $pluginName $NO_PREFS_IN_TOPIC );

#use Unicode::MapUTF8();

$VERSION = '$Rev$';
$RELEASE = 'TWiki 1.0.5';
$SHORTDESCRIPTION = 'Saves topics automatically';
$NO_PREFS_IN_TOPIC = 1;

$pluginName = 'AutoSavePlugin';

sub initPlugin {
    my( $topic, $web, $user, $installWeb ) = @_;
	
	TWiki::Func::registerRESTHandler('autoSaveTopic', \&_autoSaveTopic);
	
    return 1;
}

sub beforeEditHandler {
	# do not uncomment, use $_[0], $_[1]... instead
    #my ( $text, $topic, $web ) = @_;
    
    my $language = 'en';
    my $wikiName = TWiki::Func::getWikiName();
    
    my ($meta, $text) = TWiki::Func::readTopic("Main", $wikiName);
    
    my @country_arr = $meta->find('FIELD');
	if(@country_arr) {
		my $arr_len = scalar(@country_arr);
		for(my $i = 0; $i <= $arr_len; $i++) {
			if($country_arr[$i]{'name'} eq "Country") {
				my $country = $country_arr[$i]{'value'};
				if ($country eq 'Germany') {
					$language = 'de';
				}
			} 
		}
	}
    
    my $binPath = TWiki::Func::getScriptUrl();
    TWiki::Func::addToHEAD('AUTOSAVE','<style text="text/css">#autoSaveBox { margin-top:10px; } #autoSaveBox select { margin-right:10px; border:1px solid #a7a7a7; }</style><script type="text/javascript">var userLanguage = "' . $language . '"; var autoSaveBinPath = "' . $binPath . '"; var autoSaveWeb = "' .$_[2]. '"; var autoSaveTopic = "' .$_[1]. '";</script><script type="text/javascript" src="%PUBURL%/%SYSTEMWEB%/AutoSavePlugin/autosave.js" /></script>');
}

sub _autoSaveTopic {
   my( $session, $params, $topic, $web ) = @_;

    my $query = TWiki::Func::getCgiQuery();
	my $topicContent;
    my $currentWeb;
    my $currentTopic;
    my @getTopic;
    
#    $topicContent = Unicode::MapUTF8::from_utf8({ -string => $query->param("text"), -charset => 'ISO-8859-1' });
#    $currentWeb = Unicode::MapUTF8::from_utf8({ -string => $query->param("web"), -charset => 'ISO-8859-1' });
#    $currentTopic = Unicode::MapUTF8::from_utf8({ -string => $query->param("topic"), -charset => 'ISO-8859-1' });
    $topicContent = $query->param("text");
    $currentWeb = $query->param("web");
    $currentTopic = $query->param("topic");
 
    my ($meta, $text) = TWiki::Func::readTopic( $currentWeb, $currentTopic);
    
    @getTopic = split(/\./, $currentTopic);
    $currentTopic = $getTopic[1];
    
    TWiki::Func::saveTopic($currentWeb, $currentTopic, $meta, $topicContent);
}

1;
