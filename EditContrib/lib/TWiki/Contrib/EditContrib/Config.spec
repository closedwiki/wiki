# ---+ Extensions
# ---++ EditContrib
# **PERL H**
# This setting is required to enable executing the addsection
$TWiki::cfg{SwitchBoard}{addsection} = ['TWiki::Contrib::EditContrib', 'addSection', {}];
# **PERL H**
# This setting is required to enable executing the savesection
$TWiki::cfg{SwitchBoard}{savesection} = ['TWiki::Contrib::EditContrib', 'saveSection', {}];

1;
