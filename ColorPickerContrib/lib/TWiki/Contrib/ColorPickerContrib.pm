#
#ColorPickerContrib - TWiki Contrib, Copyright (c) 2006 Flavio Curti
#colorpicker.js - Copyright (c) 2004, 2005 Norman Timmler (inlet media e.K., Hamburg, Germany)
#All rights reserved.
#
#Redistribution and use in source and binary forms, with or without
#modification, are permitted provided that the following conditions
#are met:
#1. Redistributions of source code must retain the above copyright
#   notice, this list of conditions and the following disclaimer.
#2. Redistributions in binary form must reproduce the above copyright
#   notice, this list of conditions and the following disclaimer in the
#   documentation and/or other materials provided with the distribution.
#3. The name of the author may not be used to endorse or promote products
#   derived from this software without specific prior written permission.
#
#THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
#IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
#OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
#IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
#INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
#NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
#DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
#THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
#(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
#THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
#colorpicker.js was taken from http://blog.inlet-media.de/colorpicker/

package TWiki::Contrib::ColorPickerContrib;

use vars qw( $VERSION $RELEASE );

use TWiki;

$VERSION = 0.1;

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';


# Helper for plugins, to add the requisite bits of the Color-Picker
# to the header
sub addHEAD {
    my $base = '%PUBURLPATH%/%TWIKIWEB%/ColorPicker/';
    my $head = <<HERE;
<script type='text/javascript'>
  cp_basepath='%PUBURLPATH%/%TWIKIWEB%/ColorPicker/';
</script>
<script type='text/javascript' src='$base/colorpicker.js'></script>
HERE
    TWiki::Func::addToHEAD( 'COLORPICKER', $head );
}

1;
