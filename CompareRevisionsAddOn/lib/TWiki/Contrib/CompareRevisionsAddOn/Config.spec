# ---+ Extensions
# ---++ CompareRevisionsAddOn
# **PERL H**
# This setting is required to enable executing the compare script from the bin directory
$TWiki::cfg{SwitchBoard}{compare} =
  [ 'TWiki::Contrib::CompareRevisionsAddOn::Compare', 'compare', 
    { 'comparing' => 1, 'diff' => 1 }
  ];
1;
