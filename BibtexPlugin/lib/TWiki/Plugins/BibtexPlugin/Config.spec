# ---+ Extensions
# ---++ BibtexPlugin
# **PERL H**
# This setting is required to enable executing the bibsearch
# script from the bin directory
$TWiki::cfg{SwitchBoard}{bibsearch} =
  [ 'TWiki::Plugins::BibtexPlugin::BibSearch', 'bibsearch',
    { 'bibsearch' => 1, 'view' => 1 }
  ];

# **PATH M**
# Full path to render.sh script, located in twiki/tools directory
$TWiki::cfg{Plugins}{BibtexPlugin}{render} = '/var/www/twiki/tools/render.sh';

1;
