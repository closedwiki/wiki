use strict;


package TWiki::Plugins::LogsStatisticsPlugin;
require TWiki::Plugins::LogsStatisticsPlugin::Core;

require TWiki::Func;    # The plugins API
require TWiki::Plugins; # For the API version

use vars qw( $topic $installWeb $VERSION $RELEASE $initialised $pluginName $par_base_directory $par_indexedlogs_directory $access_string $cache_results $allow_usage $debug);

$VERSION = '$Rev: 1.001 (10 Aug 2010) $';

$RELEASE = '0.1';
$pluginName = 'LogsStatisticsPlugin';

sub initPlugin {
    #my( $web, $user );
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.026 ) {
        TWiki::Func::writeWarning( 'Version mismatch between LogsStatisticsPlugin and Plugins.pm' );
        return 0;
    }

    my $cgi = TWiki::Func::getCgiQuery();
    return 0 unless $cgi;

    $initialised = 0;
    
    TWiki::Func::registerTagHandler('STATISTICSLOGS', \&TWiki::Plugins::LogsStatisticsPlugin::Core::_logsStatistics);
   	

    return 1;
}


sub preRenderingHandler {
    ### my ( $text, $removed ) = @_;

#    my $sort = TWiki::Func::getPreferencesValue( 'LogsStatisticsPlugin_SORT' );
#    return unless ($sort && $sort =~ /^(all|attachments)$/) ||
#      $_[0] =~ /%TABLE{.*?}%/;

    # on-demand inclusion
#    require TWiki::Plugins::LogsStatisticsPlugin::Core;
#    TWiki::Plugins::LogsStatisticsPlugin::Core::handler( @_ );
}

1;
