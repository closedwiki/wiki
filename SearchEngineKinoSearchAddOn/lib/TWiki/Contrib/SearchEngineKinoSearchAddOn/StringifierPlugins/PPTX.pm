# For licensing info read LICENSE file in the TWiki root.
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
##########################################################################
#
# This work was created  by TWIKI.NET (http://www.twiki.net)
# Contact sales@twiki.net for any information
#
##########################################################################




package TWiki::Contrib::SearchEngineKinoSearchAddOn::StringifyPlugins::PPTX;
use base 'TWiki::Contrib::SearchEngineKinoSearchAddOn::StringifyBase';
use TWiki::Contrib::SearchEngineKinoSearchAddOn::Stringifier;
use File::Temp qw/tmpnam/;
use Encode;
use CharsetDetector;



# Only if ppthtml exists, I register myself.
if (__PACKAGE__->_programExists("pptx2txt.pl")){
    __PACKAGE__->register_handler("text/pptx", ".pptx");
}

sub stringForFile {
    my ($self, $filename) = @_;
    my $tmp_file = tmpnam();

    my $cmd = "pptx2txt.pl '$filename' $tmp_file 2>/dev/null";
    return "" unless ((system($cmd) == 0) && (-f $tmp_file));
  
    my $in;
    open $in, $tmp_file or return "";
    my $text = "";
   
     while (<$in>) {
        chomp;

        my $charset = CharsetDetector::detect1($_);
        my $aux_text = "";
        if ($charset =~ "utf") {
            $aux_text = encode("iso-8859-15", decode($charset, $_));
            $aux_text = $_ unless($aux_text);
        } else {
            $aux_text = $_;
        }
        $text .= " " . $aux_text;
    }

    close($in);
    unlink($tmp_file);
    
    return $text;
}

1;
