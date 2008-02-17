# ---+ Directed Graph Plugin 
# Settings for the GraphViz interface.  Generates graphs using the &lt;dot&gt; language
# **PATH M**
# Path to the GraphViz executable. (Must include trailing slash)
$TWiki::cfg{DirectedGraphPlugin}{enginePath} = '/usr/bin/';
# **PATH M**
# Path to the ImageMagick convert utility. (Must include trailing slash) <br>
#   -  This is used to support antialias output <br> 
#      (Required if GraphViz doesn't have Cario rendering support.)
$TWiki::cfg{DirectedGraphPlugin}{magickPath} = '/usr/bin/';
# **PATH M**
# Path to the TWiki tools directory .(Must include trailing slash) <br>
# The DirectedGraphPlugin.pl helper script is found in this directory.
# Typically found in the web server root along with bin, data, pub, etc.
$TWiki::cfg{DirectedGraphPlugin}{toolsPath} = '' ;
# **PATH M**
# Perl command used on this system <br>
#  On many systems this can just be the "perl" command
$TWiki::cfg{DirectedGraphPlugin}{perlCmd} = '/usr/bin/perl';
