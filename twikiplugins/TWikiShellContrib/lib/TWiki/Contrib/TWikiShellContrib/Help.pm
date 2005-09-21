package TWiki::Contrib::TWikiShellContrib::Help;

use Exporter;

@ISA=(Exporter);
@EXPORT=qw(assembleHelp);

use strict;
sub assembleHelp {
   my $doco=shift;
   my @order=@_;
   my $help='';
   foreach my $section (@order) {
      $help.=_section($section,$doco->{$section});
   }
   return $help;

}

sub _section {
   my ($section,$text)=@_;
   return '' unless $text;
   $section=uc $section;
   $text=join("\n",map {"    ".$_;} split("\n",$text));
   return "
$section
$text
";

}

1;
