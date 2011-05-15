# ---+ Extensions
# ---++ ReputationPlugin
# This plugin is used for content rating in TWiki. 
# Plugin maintains also information about the reputation of the users in relation to eachother
# **BOOLEAN**
# This option controls whether reputation information from other users is used or not
$TWiki::cfg{Plugins}{ReputationPlugin}{Recommedations} = 0;
# **BOOLEAN**
# Set this option to 1 if you want other voters' votes affect their reputation
$TWiki::cfg{Plugins}{ReputationPlugin}{Voterreputation} = 0;
# **BOOLEAN EXPERT**
# Turn debug mode on or off 
$TWiki::cfg{Plugins}{ReputationPlugin}{Debug} = 0;
1;
