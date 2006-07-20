package TWiki::Plugins::GoogleAjaxSearchPlugin;

use strict;

use vars qw( $VERSION $RELEASE $pluginName $debug $googleSiteKey $searchSite $searchWeb);

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

$pluginName = 'GoogleAjaxSearchPlugin';

#there is no need to document this.
sub initPlugin {
    my( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.1 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    # Get plugin preferences, variables defined by:
    #   * Set EXAMPLE = ...
    $debug = TWiki::Func::getPluginPreferencesFlag( "DEBUG" );
	$googleSiteKey = TWiki::Func::getPluginPreferencesValue( "GOOGLEKEY" );
	$searchSite = TWiki::Func::getPluginPreferencesValue( "GOOGLESEARCHSITE" ) || '';
	$searchWeb = TWiki::Func::getPluginPreferencesValue( "GOOGLESEARCHWEB" ) || '';
	
	_addToHead();
	
    return 1;
}

sub _addToHead {

    my $header = '<script src="http://www.google.com/uds/api?file=uds.js&amp;v=0.1&amp;key='.$googleSiteKey.'" type="text/javascript"></script>';
    $header .= '
    <style type="text/css" media="all">
@import url("http://www.google.com/uds/css/gsearch.css");
@import url("%PUBURL%/%TWIKIWEB%/GoogleAjaxSearchPlugin/googleAjaxSearch.css");
</style>
<script type="text/javascript" src="%PUBURL%/%TWIKIWEB%/GoogleAjaxSearchPlugin/googleAjaxSearch.js"></script>
<script type="text/javascript">
//<![CDATA[
GoogleAjaxSearch.getSearchSite = function () {
	return "'.$searchSite.'" + GoogleAjaxSearch.getSearchWeb();
}
GoogleAjaxSearch.getSearchWeb = function () {
	return "'.$searchWeb.'";
}
GoogleAjaxSearch.getUrlParam = function () {
	return "%URLPARAM{"googleAjaxQuery" default=""}%";
}
//]]>
</script>
';
	TWiki::Func::addToHEAD('GOOGLEAJAXSEARCHPLUGIN',$header)
}

1;
