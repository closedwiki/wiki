# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2004 Martin Cleaver, Martin.Cleaver@BCS.org.uk
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2004 Peter Thoeny, peter@thoeny.com
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
# This is the Adverts TWiki plugin.
# It interfaces to phpAdsNew (http://p

# =========================
package TWiki::Plugins::AdvertsPlugin;


# =========================
use vars qw(
  $web $topic $user $installWeb $VERSION $pluginName
  $debug $phpAdsNewBase;
);

$VERSION    = '0.1';
$pluginName = 'AdvertsPlugin';    # Name of this Plugin

# =========================
sub initPlugin {
 ( $topic, $web, $user, $installWeb ) = @_;

 # check for Plugins.pm versions
 if ( $TWiki::Plugins::VERSION < 1.021 ) {
  TWiki::Func::writeWarning(
   "Version mismatch between $pluginName and Plugins.pm");
  return 0;
 }

 # Get plugin debug flag
 $debug = TWiki::Func::getPluginPreferencesFlag("DEBUG");

 # Get plugin preferences, the variable defined by:          * Set EXAMPLE = ...
 $phpAdsNewBase = TWiki::Func::getPluginPreferencesValue("ADVERTSCRIPTBASE")
   || "http://testwiki.mrjc.com/phpAdsNew-2.0/";

 # Plugin correctly initialized
 TWiki::Func::writeDebug(
  "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK")
   if $debug;
 return 1;
}

# =========================
sub commonTagsHandler {
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

 TWiki::Func::writeDebug("- ${pluginName}::commonTagsHandler( $_[2].$_[1] )")
   if $debug;

 # This is the place to define customized tags and variables
 # Called by sub handleCommonTags, after %INCLUDE:"..."%

 # do custom extension rule, like for example:
 $_[0] =~ s/%ADVERT%/&handleAdvert()/ge;

 # $_[0] =~ s/%XYZ{(.*?)}%/&handleXyz($1)/ge;
}

# =========================

=pod
<script language='JavaScript' type='text/javascript'>
<!--
   if (!document.phpAds_used) document.phpAds_used = ',';
   phpAds_random = new String (Math.random()); phpAds_random = phpAds_random.substring(2,11);
   
   document.write ("<" + "script language='JavaScript' type='text/javascript' src='");
   document.write ("http://testwiki.mrjc.com/phpAdsNew-2.0/adjs.php?n=" + phpAds_random);
   document.write ("&amp;what=Foobar&amp;clientid=2");
   document.write ("&amp;exclude=" + document.phpAds_used);
   if (document.referer)
      document.write ("&amp;referer=" + escape(document.referer));
   document.write ("'><" + "/script>");
//-->
</script><noscript><a href='http://testwiki.mrjc.com/phpAdsNew-2.0/adclick.php?n=ad13c123' target='_blank'><img src='http://testwiki.mrjc.com/phpAdsNew-2.0/adview.php?what=Foobar&amp;clientid=2&amp;n=ad13c123' border='0' alt=''></a></noscript>

=cut

sub handleAdvert {
 my $ans = getTemplateAdvert();
 $what          = "Foobar&amp;clientid=2";
 $random        = "ad13c123";
 $serverUrlBase = "http://testwiki.mrjc.com/phpAdsNew-2.0/";

 $ans =~ s/%WHAT%/$what/g;
 $ans =~ s/%RANDOM%/$random/g;
 $ans =~ s/%SERVERURLBASE%/$serverUrlBase/g;

}

sub getTemplateAdvert {
 my $ans = <<EOM;
<script language='JavaScript' type='text/javascript'>
<!--
   if (!document.phpAds_used) document.phpAds_used = ',';
   phpAds_random = new String (Math.random()); phpAds_random = phpAds_random.substring(2,11);
   
   document.write ("<" + "script language='JavaScript' type='text/javascript' src='");
   document.write ("%SERVERURLBASE/adjs.php%n=" + phpAds_random);
   document.write ("&amp;what=%WHAT%");
   document.write ("&amp;exclude=" + document.phpAds_used);
   if (document.referer)
      document.write ("&amp;referer=" + escape(document.referer));
   document.write ("'><" + "/script>");
//-->
</script><noscript><a href='%SERVERURLBASE%?n=%RANDOM%' target='_blank'><img src='%SERVERURLDIR%/adview.php?what=%WHAT%;%RANDOM%' border='0' alt=''></a></noscript>
   
EOM
 return $ans;

}

1;
