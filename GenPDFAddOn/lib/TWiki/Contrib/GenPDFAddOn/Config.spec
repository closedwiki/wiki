# ---+ Extensions
# ---++ GenPDFAddOn
# **PATH M**
# Path to the htmldoc executable.
$TWiki::cfg{Extensions}{GenPDFAddOn}{htmldocCmd} = '/usr/bin/htmldoc';

# **PERL H**
# This setting is required to enable executing the genpdf
# script from the bin directory
$TWiki::cfg{SwitchBoard}{genpdf} =
  [ 'TWiki::Contrib::GenPDFAddOn', 'genpdf',
    { 'genpdf' => 1, 'view' => 1 }
  ];

1;
