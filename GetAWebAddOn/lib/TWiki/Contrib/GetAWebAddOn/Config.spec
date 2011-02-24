# ---+ Extensions
# ---++ GetAWebAddOn

# **PERL H**
# This setting is required to enable executing the get-a-web
# script from the bin directory
$TWiki::cfg{SwitchBoard}{getaweb} =
  [ 'TWiki::Contrib::GetAWebAddOn', 'getaweb',
    { 'getaweb' => 1, 'view' => 1 }
  ];

1;
