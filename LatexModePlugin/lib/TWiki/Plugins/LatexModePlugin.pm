# LatexModePlugin.pm
# Copyright (C) 2005 W Scott Hoge, shoge at bwh dot harvard dot edu
# Copyright (C) 2002 Graeme Lufkin, gwl@u.washington.edu
#
# TWiki WikiClone ($wikiversion has version info)
#
# Copyright (C) 2000-2001 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001 Peter Thoeny, Peter@Thoeny.com
#
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
#
# =========================
#
# This is the Math Mode TWiki plugin.  See TWiki.LatexModePlugin for details.
#
# Each plugin is a package that contains the subs:
#
#   initPlugin           ( $topic, $web, $user, $installWeb )
#   commonTagsHandler    ( $text, $topic, $web )
#   outsidePREHandler    ( $text )
#   insidePREHandler     ( $text )
#   postRenderingHandler  ( $text )
#
# initPlugin is required, all other are optional. 
# For increased performance, all handlers except initPlugin are
# disabled. To enable a handler remove the leading DISABLE_ from
# the function name.
# 
# NOTE: To interact with TWiki use the official TWiki functions
# in the &TWiki::Func module. Do not reference any functions or
# variables elsewhere in TWiki!!

# LatexModePlugin: This plugin allows you to include mathematics and
# other Latex markup commands in TWiki pages.  To declare a portion of
# the text as latex, enclose it within any of the available markup tags:
#    %$ ... $%    for in-line equations
#    %\[ ... \]%  or
#    %MATHMODE{ ... }% for own-line equations
#
# For multi-line, or more complex markup, the syntax
# %BEGINLATEX{}% ... %ENDLATEX% is also available.
#
# An image is generated for each latex expression on a page by
# generating an intermediate PostScript file, and then using the
# 'convert' command from ImageMagick.  The rendering is done the first
# time an expression is used.  Subsequent views of the page will not
# require a re-render.  Images from old expressions no longer included
# in the page will be deleted.

# =========================
package TWiki::Plugins::LatexModePlugin;

use strict;

# =========================
use vars qw( $web $topic $user $installWeb $VERSION $RELEASE $debug
             $default_density $default_gamma $default_scale $preamble
             $eqn $fig $tbl $use_color @norender $tweakinline @EXPORT_OK
             );

# number the release version of this plugin
$VERSION = '$Rev$';
$RELEASE = '2.4';

require Exporter;
*import = \&Exporter::import;

@EXPORT_OK = qw($preamble);

#the MD5 hash function is used to uniquely identify a string of math
use Digest::MD5 qw( md5_hex );

#we use the basename() function to determine which script is running
use File::Basename qw( basename );
use File::Copy qw( move copy );
use File::Temp;

# use Image::Info to identify image size.
use Image::Info qw( image_info );

######################################################################
### installation specific variables:

my $pathSep = ($^O =~ m/^Win/i) ? "\\" : '/' ;

my $PATHTOLATEX = $TWiki::cfg{Plugins}{LatexModePlugin}{latex} ||
    '/usr/share/texmf/bin/latex';
my $PATHTODVIPS = $TWiki::cfg{Plugins}{LatexModePlugin}{dvips} ||
    '/usr/share/texmf/bin/dvips';
my $PATHTOCONVERT = $TWiki::cfg{Plugins}{LatexModePlugin}{convert} ||
    '/usr/X11R6/bin/convert';
my $PATHTODVIPNG = $TWiki::cfg{Plugins}{LatexModePlugin}{dvipng} ||
    '/usr/share/texmf/bin/dvipng';

my $DISABLE = $TWiki::cfg{Plugins}{LatexModePlugin}{donotrenderlist} ||
    'input,include';
my @norender = split(',',$DISABLE);

my $tweakinline = $TWiki::cfg{Plugins}{LatexModePlugin}{tweakinline} || 
    0;

my $GREP =  $TWiki::cfg{Plugins}{LatexModePlugin}{fgrep} ||
    $TWiki::fgrepCmd ||
    '/usr/bin/fgrep';

### The variables below this line will likely not need to be changed
######################################################################

# this is the extension of the generated images.  gif or jpg are other
# possibilities.
my $EXT = 'png';

#this is the name of the latex file created by the program.  You shouldn't
#need to change it unless for some bizarre reason you have a file attached to
#a TWiki topic called twiki_math or twiki_math.tex
my $LATEXBASENAME = 'twiki_math';
my $LATEXFILENAME = $LATEXBASENAME . '.tex';


#this variable gives the length of the hash code.  If you switch to a different
#hash function, you will likely have to change this
my $HASH_CODE_LENGTH = 32;

#this hash table will contain the math strings, indexed by their hash code
my %hashed_math_strings = ();

# this hash table is used to store declared markup options 
# to be used during rendering (e.g. in-line vs. own-line equations)
my %markup_opts = ();

# these store the numbers for the 
my %eqnrefs = ();               # equation back-references 
my %figrefs = ();               # figure back-references 
my %tblrefs = ();               # table back-references 

# a place to store intermediate errors until all latex handling is done.
my $error_catch_all = "";

#the url to the attachment directory for this page
my $pubUrlPath;

# get the name of the script that called us
my $script = basename( $0 );

### the output of each function depends on whether the output is HTML
### based or destined for pdflatex processing.  This flag selects
### between the two.
my $latexout = 0 ;

# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;
	
    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.025 ) { 
        # this version is Dakar and Cairo compatible
        &TWiki::Func::writeWarning( "Version mismatch between LatexModePlugin (Dakar edition) and Plugins.pm" );
        return 0;
    }

    #get the relative URL to the attachment directory for this page
    $pubUrlPath = # &TWiki::Func::getUrlHost() . 
        &TWiki::Func::getPubUrlPath() . "/$web/$topic";
    
    # Get preferences values
    $debug = &TWiki::Func::getPreferencesFlag( "LATEXMODEPLUGIN_DEBUG" );
    $default_density = 
        &TWiki::Func::getPreferencesValue( "DENSITY" ) ||
        &TWiki::Func::getPreferencesValue( "LATEXMODEPLUGIN_DENSITY" ) || 
        116;
    $default_gamma = 
        &TWiki::Func::getPreferencesValue( "GAMMA" ) ||
        &TWiki::Func::getPreferencesValue( "LATEXMODEPLUGIN_GAMMA" ) ||
        0.6;
    $default_scale = 
        &TWiki::Func::getPreferencesValue( "SCALE" ) ||
        &TWiki::Func::getPreferencesValue( "LATEXMODEPLUGIN_SCALE" ) ||
        1.0;

    $preamble = 
        &TWiki::Func::getPreferencesValue( "PREAMBLE" ) ||
        &TWiki::Func::getPreferencesValue( "LATEXMODEPLUGIN_PREAMBLE" ) ||
        '\usepackage{latexsym}'."\n";

    # initialize counters
    # Note, these can be over-written by topic declarations
    $eqn = &TWiki::Func::getPreferencesValue( "EQN" ) || 0;
    $fig = &TWiki::Func::getPreferencesValue( "FIG" ) || 0;
    $tbl = &TWiki::Func::getPreferencesValue( "TBL" ) || 0;

    $use_color = 0;             # initialize color setting.

    $latexout = 1 if ($script =~ m/genpdflatex/);

    # Plugin correctly initialized
    &TWiki::Func::writeDebug( "- TWiki::Plugins::LatexModePlugin::initPlugin( $web.$topic ) is OK" ) if $debug;

    return 1;
}

sub commonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead
    
    TWiki::Func::writeDebug( " TWiki::Plugins::LatexModePlugin::commonTagsHandler( $_[2].$_[1] )" ) if $debug;
      
    # This is the place to define customized tags and variables
    # Called by sub handleCommonTags, after %INCLUDE:"..."%
    
    # handle floats first, in case of latex markup in captions.
    $_[0] =~ s!%BEGINFIGURE{(.*?)}%(.*?)%ENDFIGURE%!&handleFloat($2,$1,'fig')!giseo;
    $_[0] =~ s!%BEGINTABLE{(.*?)}%(.*?)%ENDTABLE%!&handleFloat($2,$1,'tbl')!giseo;

    ### handle the standard syntax next
    $_[0] =~ s/%(\$.*?\$)%/&handleLatex($1,'inline="1"')/gseo;
    $_[0] =~ s/%(\\\[.*?\\\])%/&handleLatex($1,'inline="0"')/gseo;
    $_[0] =~ s/%MATHMODE{(.*?)}%/&handleLatex("\\[".$1."\\]",'inline="0"')/gseo;
    
    # pass everything between the latex BEGIN and END tags to the handler
    # 
    $_[0] =~ s!%BEGINLATEX{(.*?)}%(.*?)%ENDLATEX%!&handleLatex($2,$1)!giseo;
    $_[0] =~ s!%BEGINLATEX%(.*?)%ENDLATEX%!&handleLatex($1,'inline="0"')!giseo;
    $_[0] =~ s!%BEGINLATEXPREAMBLE%(.*?)%ENDLATEXPREAMBLE%!&handlePreamble($1)!giseo;

    # last, but not least, replace the references to equations with hyperlinks
    $_[0] =~ s!%REFLATEX{(.*?)}%!&handleReferences($1)!giseo;
}

# =========================
sub handlePreamble
{
    my $text = $_[0];	

    $preamble .= $text;

    return('');
}


# =========================
sub handleReferences
{
# This function converts references to defined
# equations/figures/tables and replaces them with the Eqn/Fig/Tbl
# number
### my ( $math_string ) = @_;   # do not uncomment, use $_[0], $_[1] instead

    my $ref = $_[0];	
    my ($backref,$txt) = ("",""); 

    if ($latexout) {
        $txt = '<latex>\ref{'.$ref.'}</latex>';

    } else {

    if ($ref=~m/^tbl\:/) {
        $backref = exists($tblrefs{$ref}) ? $tblrefs{$ref} : "?? REFLATEX{$ref} not defined in table list ??";
    } elsif ($ref=~m/^fig\:/) {
        $backref = exists($figrefs{$ref}) ? $figrefs{$ref} : "?? REFLATEX{$ref} not defined in fig list ??";
        $txt = '<a href="#'.$ref.'">'.$backref.'</a>';
    } else {
        if (exists($eqnrefs{$ref})) {
            $backref = $eqnrefs{$ref}; }
        elsif (exists($eqnrefs{ "eqn:".$ref })) {
            $backref = $eqnrefs{ "eqn:".$ref }; }
        else { $backref = "?? REFLATEX{$ref} not defined in eqn list ??"; }
        $txt = '(<a href="#'.$ref.'">'.$backref.'</a>)';
    }
    }

    return($txt);
}

# =========================
sub handleFloat
{
# This function mimics the construction of float environments in latex,
# producing a back-reference list for Figures and Tables.

### my ( $input ) = @_;   # do not uncomment, use $_[0], $_[1] instead

    my $input = $_[0];	
    my $prefs = $_[1];

    my @a=('0'..'9','a'..'z','A'..'Z');
    my $str = map{ $a[ int rand @a ] } (0..7);
    my %opts = ( 'label' => $str,
                 'span'  => 'onecol',
                 'caption' => ' ' );

    my %opts2 = TWiki::Func::extractParameters( $prefs );
    map { $opts{$_} = $opts2{$_} } keys %opts2;
    # while ( $prefs=~ m/(.*?)=\"(.*?)\"/g ) {
    #     my ($a,$b) = ($1,$2);
    #     # remove leading/trailing whitespace from key names
    #     $a =~ s/^\s*|\s*$//;    
    # 
    #     $opts{$a} = $b;
    # }

    my $env = ($_[2] eq 'fig') ? "Figure" : "Table" ;
    my $tc  = ($opts{'span'} =~ m/^twoc/) ? '*' : '' ;

    # ensure that the first 4 chars of the label conform to 
    # 'fig:' or 'tbl:' or ...
    ( $opts{'label'} = $_[2].":".$opts{'label'} )
        unless ( substr($opts{'label'},0,4) eq $_[2].':' );
        
    my $txt2 = "";
    if( $latexout ) {           ## for genpdflatex
        # in Cairo (at least) latex new-lines, '\\', get translated to 
        # spaces, '\', but if they appear at the end of the line. 
        # So pad in a few spaces to protect them...
        $input =~ s!\n!  \n!g;

        $txt2 = '<latex>';
        $txt2 .= "\n\\begin{".lc($env).$tc."}\\centering\n";
        $txt2 .= $input."\n\\caption{".$opts{'caption'}."}\n";
        $txt2 .= '\label{'.$opts{'label'}."}\n\\end{".lc($env).$tc."}";
        $txt2 .= '</latex>';
        
    } else {
        ## otherwise, generate HTML ...
        my $infrmt = '<tr><td align="center">%s</td></tr>';
        my $cpfrmt = '<tr><td align="center" style="lmp-caption"> *%s %d*: %s</td></tr>';

        if ($_[2] eq 'fig') {
            $fig++;
            
            $txt2 .= sprintf($infrmt."\n",$input).
                sprintf($cpfrmt."\n",$env,$fig,$opts{'caption'});
                
            my $key = $opts{'label'};
            $figrefs{$key} = $fig;
            
        } elsif ($_[2] eq 'tbl') {
            $tbl++;
            
            $txt2 .= sprintf($cpfrmt."\n",$env,$fig,$opts{'caption'}).
                sprintf($infrmt."\n",$input);
            
            my $key = $opts{'label'};
            $tblrefs{$key} = $tbl;
        } else {
            $txt2 .= $input;
        }
        $txt2 = '<a name="'.$opts{'label'}.'"></a>' .
            '<table width="100%" border=0>'."\n" .
            $txt2 .
            '</table>';
        
    } # end. if !($latexout)

    return($txt2);
}

# =========================
sub handleLatex
{
# This function takes a string of math, computes its hash code, and returns a
# link to what will be the image representing this math.
### my ( $math_string ) = @_;   # do not uncomment, use $_[0], $_[1] instead

    my $math_string = $_[0];	
    my $escaped = $_[0];
    my $prefs = $_[1];

    # remove latex-common HTML entities from within math env
    $math_string =~ s/&amp;/&/og;
    $math_string =~ s/&lt;/\</og;    
    $math_string =~ s/&gt;/\>/og;    

    # set default rendering parameters
    my %opts = ( 'inline' => 0, 
                 'density' => $default_density, 
                 'gamma' => $default_gamma, 
                 'scale' => $default_scale,
                 'color' => 'black' );

    my %opts2 = TWiki::Func::extractParameters( $prefs );
    # map { $opts{$_} = $opts2{$_} } keys %opts2;
    foreach my $k (keys %opts2) {
        my $b = $opts2{$k};

        # remove leading/trailing whitespace from key names
        (my $a = $k) =~ s/^\s*|\s*$//;

        # scrub the inputs, since this gets passed to 'convert' (in
        # particular, sheild against 'density=166|cat%20/etc/passwd'
        # type inputs). alpha-numeric OK. slash, space, and brackets
        # are valid in preamble. need semi-colon in eqn lables!
        # allow '-' and '_' in eqn labels too.
        $b =~ m/([\.\\\w\s\:\-\_\{\}]+)/; 
        $b = $1;

        $opts{$a} = $b;

        $use_color = 1 if ($a eq 'color');
    }
    if ( ($use_color == 1) and !( $preamble =~ m/ackage\{color/) ) {
        $preamble = "\\RequirePackage{color}\n".$preamble;
    }
    if ( ( $preamble =~ m/package\{color/i) and 
         !($preamble =~ m/definecolor\{Red/) ) {

        $preamble .= <<'COLORS';

        \definecolor{Red}{rgb}{1,0,0}
        \definecolor{Blue}{rgb}{0,0,1}
        \definecolor{Yellow}{rgb}{1,1,0}
        \definecolor{Orange}{rgb}{1,0.4,0}
        \definecolor{Pink}{rgb}{1,0,1}
        \definecolor{Purple}{rgb}{0.5,0,0.5}
        \definecolor{Teal}{rgb}{0,0.5,0.5}
        \definecolor{Navy}{rgb}{0,0,0.5}
        \definecolor{Aqua}{rgb}{0,1,1}
        \definecolor{Lime}{rgb}{0,1,0}
        \definecolor{Green}{rgb}{0,0.5,0}
        \definecolor{Olive}{rgb}{0.5,0.5,0}
        \definecolor{Maroon}{rgb}{0.5,0,0}
        \definecolor{Brown}{rgb}{0.6,0.4,0.2}
        \definecolor{Black}{gray}{0}
        \definecolor{Gray}{gray}{0.5}
        \definecolor{Silver}{gray}{0.75}
        \definecolor{White}{gray}{1}

COLORS
    }

    &TWiki::Func::writeDebug( "- LatexModePlugin::handleLatex( ".
                              $math_string . " :: ". 
                              join('; ',map{"$_ => $opts{$_}"}keys(%opts)). 
                              " )" ) if $debug;

    my $txt;

    if( exists($opts{'label'}) ) {
        ( $opts{'label'} = "eqn:".$opts{'label'} )
            unless ( substr($opts{'label'},0,4) eq 'eqn:' );
    }

    if ($latexout) {

        if( exists($opts{'label'}) ) {
            # strip off any 'displaymath' calls
            $math_string =~ s!\\\[|\\\]!!g; 
            $math_string =~ s!\\(begin|end)\{displaymath\}!!g;

            if ($math_string =~ m/eqnarray(\*?)/) {

                # try to handle equation arrays.
                if ($1 eq '*') {
                    $math_string =~ s/eqnarray\*/eqnarray/g;
                    
                    # leave no numbers ...
                    $math_string =~ s!\\\\!\\nonumber \\\\!g;
                    # except for the last one
                }
                # slip the label in..
                my $lbl = '\label{'.$opts{'label'}.'}';
                $math_string =~ s/(begin\{.*?\})/$1$lbl/;

            } else {
                $math_string = "\n\\begin{equation}\n".
                    '    \label{'.$opts{'label'}."}"."\n".
                    "    ".$math_string."\n".
                    "\\end{equation}\n";
            }
        }
        # in Cairo (at least) latex new-lines, '\\', get translated to 
        # spaces, '\', if they appear at the end of the line.
        # So protect them here...
        $math_string =~ s!\n!  \n!g;
        $txt = '<latex>'.$math_string.'</latex>';

        
    } else {

        # compute the MD5 hash of this string, using both the markup text
        # and the declared options.
        my $hash_code = md5_hex( $math_string . 
                                 join('; ', map{"$_=>$opts{$_}"} keys(%opts)) );

        if ( ($opts{'inline'} eq 1) and ($tweakinline) ) {
            $math_string = '\fbox{ ' . $math_string . 
                '\vphantom{$\sqrt{\{ \}^{T^T}}$} }'; 
        }
        #store the string in a hash table, indexed by the MD5 hash
        $hashed_math_strings{$hash_code} = $math_string;
        
        
        ### store the declared options for the rendering later...
        $markup_opts{$hash_code} = \%opts;
        
        #remove any quotes in the string, so the alt tag doesn't break
        $escaped =~ s/\"/&quot;/gso;
        $escaped =~ s/\n/ /gso;
        $escaped =~ s!(\u\w\l\w+\u\w)!<nop>$1!g;

        my $image_name = "$pubUrlPath/latex$hash_code.$EXT";
        
        # if image currently exists, get its dimensions
        my $outimg = &TWiki::Func::getPubDir() . "/$web/$topic/"."latex$hash_code.$EXT";
        my $str = "";
        if (-f $outimg) {
            my $img = image_info($outimg);
            $str = sprintf("width=\"%d\" height=\"%d\"",
                           ($opts{'scale'} * $img->{width} ),
                           ($opts{'scale'} * $img->{height})  );
            undef($img);
        }
        
        #return a link to an attached image, which we will create later
        if( ($opts{'inline'} eq 1) or 
            ($opts{'inline'} eq "on") or 
            ($opts{'inline'} eq "true") ) {

            my $algn;
            if ($tweakinline) {
                $algn = 'middle';
            } else {
                $algn = ($escaped =~ m/[\_\}\{]|[yjgpq]/) ? 'middle' : 'bottom' ;
            }
            $txt = "<img style=\"vertical-align:$algn;\" align=\"$algn\" $str src=\"$image_name\" alt=\"$escaped\" />"; 

        } elsif( exists($opts{'label'}) ) {
            $eqn++;
            
            $txt = '<a name="'.$opts{'label'}.'"></a>'.
                '<table width="100%" border=0><tr>'."\n".
                '<td width=10>&nbsp;</td>'.
                '<td width="100%" align="center">'.
                "<img src=\"$image_name\" $str alt=\"$escaped\" /></td>".
                "<td width=10>($eqn)</dt></tr></table>\n";
            
            if ( exists( $eqnrefs{ $opts{'label'} } ) ) {
                $error_catch_all .= 
                    "&nbsp;&nbsp;&nbsp;Error! multiple equation labels '$opts{'label'}' defined.\n".
                    "(Eqns. $eqnrefs{$opts{'label'}} and $eqn)<br>\n";
            } else {
                $eqnrefs{ $opts{'label'} } = $eqn;
            }
            
        } else {
            $txt = "<div align=\"center\"><img src=\"$image_name\" $str alt=\"$escaped\" /></div>";
        }
    }  # end 'if !$latexout';

    return($txt);
}

# =========================
sub endRenderingHandler
{
    # for backwards compatibility with Cairo
    postRenderingHandler($_[0]);
}
	
# =========================
sub postRenderingHandler
{
# Here we check if we saw any math, try to delete old files, render new math, and clean up
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead

    my $path;

    &TWiki::Func::writeDebug( "- LatexModePlugin::postRenderingHandler( $web.$topic )" ) if $debug;
	
    #my @revinfo = &TWiki::Func::getRevisionInfo($web, $topic, "", 0);
    #&TWiki::Func::writeDebug( "- LatexModePlugin: @revinfo" ) if $debug;
    
    #check if there was any math in this document
    return unless scalar( keys( %hashed_math_strings ) );

    $_[0] .= "\n<hr>Twiki LatexModePlugin error messages:<br>\n".
        $error_catch_all if ( length($error_catch_all) > 0 );


    #if this is a view script, then we will try to delete old files
    my $delete_files = ( $script =~ m/^view/ );

    my @extfiles;
    if( $TWiki::Plugins::VERSION >= 1.1 ) { 
        # Dakar interface
        my ( $meta, undef ) = TWiki::Func::readTopic( $web, $topic );
        my %h2 = %{$meta};
        @extfiles = @{$h2{FILEATTACHMENT}} if defined($h2{FILEATTACHMENT});
    } else {
        # Cairo interface
        $path = &TWiki::Func::getPubDir() . "/$web/$topic";
        opendir(D,$path);
        @extfiles = grep(/\.$EXT$/,readdir(D));
        closedir(D);
    }
    &TWiki::Func::writeDebug( "Scanning file attachments" ) if $debug;
    foreach my $a ( @extfiles ) {
        my $fn = ( $TWiki::Plugins::VERSION >= 1.1 ) ? $a->{name} : $a;

        # print STDERR "\n----\n";
        # print STDERR map {"$_ -> $h{$_}\n"} keys %h;
        
        # was the image likely generated by this plugin?
        if( $fn =~ m/^latex[0-9a-f]+\.$EXT$/ ) {

            my $hash_code = substr( $fn, 5, $HASH_CODE_LENGTH );
            #is the image still used in the document?
            if( exists( $hashed_math_strings{$hash_code} ) ) {
                #if the image is already there, we don't need to re-render
                delete( $hashed_math_strings{$hash_code} );
                next;
            }

            if( $delete_files ) {
                #delete the old image
                &TWiki::Func::writeDebug( "Deleting old image that I think belongs to me: $fn" ) if $debug;
                if ( $fn =~ /^([-\@\w.]+)$/ ) { # untaint filename
                    $fn = $1;
                    
                    if ( $TWiki::Plugins::VERSION >= 1.1 ) { 
                        # Dakar interface
                        TWiki::Func::moveAttachment( $web, $topic, $fn, 
                                                     $TWiki::cfg{TrashWebName},
                                                     'TrashAttachment', $fn )
                            if (-f $fn);
                    } else {
                        # Cairo interface
                        unlink( $path.$pathSep.$fn ) if (-f $fn);
                    }                }
            }
        }
    }

    #check if there are any new images to render
    return unless scalar( keys( %hashed_math_strings ) );

    # create a temporary working directory
    my $LATEXWDIR = File::Temp::tempdir();

    &TWiki::Func::writeDebug( "LatexModePlugin working directory: $LATEXWDIR" ) if $debug;

    ### create the temporary Latex Working Directory...
    #does the topic's attachment directory exist?
    if( -e $LATEXWDIR ) {
        #if it's not really a directory, we can't do anything        
        return unless ( -d $LATEXWDIR );

        # FIXME: this section should never be called, but should
        # report an error in the event that it does
        &TWiki::Func::writeDebug( "Directory already exists." ) if $debug;
    } else {
        #create the directory if it didn't exist
        return unless mkdir( $LATEXWDIR );
        &TWiki::Func::writeDebug( " Directory $LATEXWDIR does not exist" ) if $debug;
    }
    # move into the temprorary working directory
    # use Cwd 'cwd';
    # (my $saveddir = cwd) =~ s/^([-\@\w.]+)$/$1/; 
    # $saveddir now untainted

    my $LATEXLOG = File::Temp::tempnam( $LATEXWDIR, 'latexlog' );

    do { $_[0] .= "<BR>unable to access latex working directory.";
         return; } unless chdir( $LATEXWDIR );
    system("echo \"$LATEXWDIR\n^O\n\" > $LATEXLOG");

    my $image_number = 0;   # initialize the image count
    #this hash table maps the digest strings to the output filenames
    my %hash_code_mapping = ();

    #create the intermediate latex file
    do { $_[0] .= "<BR>can't write $LATEXFILENAME: $!\n"; 
         return; } unless open( MATHOUT, ">$LATEXFILENAME" );

    # disable commands flagged as 'do not render'
    # e.g. lock-out the inclusion of other files via input/include
    foreach my $c (@norender) {
        $preamble =~ s!\\$c\b!\\verb-\\-$c!g;
    }

    print MATHOUT "\\documentclass{article}\n".$preamble."\n\\begin{document}\n\\pagestyle{empty}\n";
    while( (my $key, my $value) = each( %hashed_math_strings ) ) {
        
        # restore the declared rendering options
        my %opts = %{$markup_opts{$key}};

        # disable commands flagged as 'do not render'
        # e.g. lock-out the inclusion of other files via input/include
        foreach my $c (@norender) {
            $value =~ s!\\$c\b!\\verb-\\-$c!g;
        }

        &TWiki::Func::writeDebug( "LatexModePlugin: ".
                                  $value . " :: " .
                                  join('; ', map{"$_=>$opts{$_}"} keys(%opts))
                                  ) if ($debug);
        
        print MATHOUT "\\clearpage\n";
        print MATHOUT "% $LATEXBASENAME.$EXT.$image_number --> $key \n";
        print MATHOUT '\textcolor{'.$opts{'color'}.'}{'
            unless ($opts{'color'} eq 'black');
        print MATHOUT " $value ";
        print MATHOUT '}'
            unless ($opts{'color'} eq 'black');

        $hash_code_mapping{$key} = $image_number + 1;
        $image_number++;
    }
    print MATHOUT "\\clearpage\n(end)\\end{document}\n";
    close( MATHOUT );

    # generate the output images by running latex-dvips-convert on the file
    system("$PATHTOLATEX $LATEXFILENAME >> $LATEXLOG 2>&1");

    ### report errors on 'preview' and 'save'
    if ( ( $script eq 'preview' ) || ( $script eq 'save' ) ) {
        my $resp = `$GREP -A 3 -i "!" $LATEXLOG`;
        $_[0] .= "\n<hr>Latex rendering error messages:<pre>$resp</pre>\n" if ( length($resp) > 0 );
    }

    if ( -f $LATEXBASENAME.".dvi" ) {

	#generate image files based on the hash code
	while( (my $key, my $value) = each( %hash_code_mapping ) ) {
	    # restore (again) the rendering options
	    my %opts = %{$markup_opts{$key}};

            # calculate point-to-pixel mapping (1pt/72dpi*density) 
            # == 1.61 for density=116
            my $ptsz = ($opts{'density'}/72); 
	    
	    my $num = $hash_code_mapping{$key};

            my $outimg = "latex$key.$EXT";
            
            if (-x $PATHTODVIPNG) {
                # if dvipng is installed ...
                $EXT = lc($EXT);
                my $cmd = "$PATHTODVIPNG -D ".$opts{'density'}." -T tight".
                    " --".$EXT.
                    " -gamma ".($opts{'gamma'}+1.0).
                    " -bg transparent ".
                    " -pp $num -o $outimg ".$LATEXBASENAME.".dvi >> $LATEXLOG 2>&1";
                system($cmd);
            } else {
                # OTW, use dvips/convert ...

	    system("$PATHTODVIPS -E -pp $num -o $LATEXBASENAME.$num.eps $LATEXBASENAME.dvi >> $LATEXLOG 2>&1 ");
	    
	    my $cmd = "-density $opts{'density'} $LATEXBASENAME.$num.eps ";
            $cmd .= "-antialias -trim -gamma ".$opts{'gamma'}." ";
            $cmd .= " -transparent white " 
                unless ( ($markup_opts{$key}{'inline'} ne 0) and
                         ($tweakinline ne 0) );
            $cmd .= $outimg;

	    system("echo \"$PATHTOCONVERT $cmd\" >> $LATEXLOG");
	    system("$PATHTOCONVERT $cmd");
            }
            if (-f $outimg) {
                
                if ( ($markup_opts{$key}{'inline'} ne 0) 
                     and ($tweakinline) 
                     and (-x $PATHTOCONVERT) 
                     ) {
                    my $tmpfile = File::Temp::tempnam( $LATEXWDIR, 'tmp' ).".$EXT";
                    move($outimg,$tmpfile);

                    system("$PATHTOCONVERT $tmpfile -shave ".
                           round(1*$ptsz)."x".round(1*$ptsz)." ".
                           $outimg);
                    
                    my $img2 = image_info($outimg);

                    my ($nw,$nh) = ( $img2->{width}-round(8*$ptsz), 
                                      $img2->{height} );
                    $nw = $1 if ($nw =~ m/(\d+)/); # untaint
                    $nh = $1 if ($nh =~ m/(\d+)/); # untaint
                    $nh = round(15*$ptsz)
                        if ($nh < round(15*$ptsz) ); # set a minimum height

                    my ($sh,$sh2) = ( round(3.1*$ptsz), round(2.25*$ptsz) );
                    $sh = $1 if ($sh =~ m/(\d+)/); # untaint
                    $sh2 = $1 if ($sh2 =~ m/(\d+)/); # untaint
                     
                    my $cmd = " -crop ".$nw."x".$nh."+$sh+$sh2 -transparent white $outimg";
                    
                    move($outimg,$tmpfile);
                    system("$PATHTOCONVERT $tmpfile $cmd");
                    unlink("$tmpfile") unless ($debug);

                    ## Another strategy: trim gives better horizontal
                    ## results but is too aggressive vertically.
                    ##    * convert eps --> 1.png (with a border)
                    ##    * shave 1.png by border size 
                    ##    * copy 1.png --> 2.png
                    ##    * trim 2.png
                    ##    * extract off image and page size using identify
                    ##      (this gives crop coordinates).
                    ##      UPDATE: unfortunately, this is not robust.
                    ##    * crop 1.png, using width-coordinates from
                    ##      trim and hieght coordinates from shave

### EXAMPLE:
# /usr/X11R6/bin/convert -density 116 twiki_math.4.ps  -antialias -trim -gamma 0.6 -transparent white  t1.png
# cp t1.png t2.png
# mogrify -shave 2x2 t2.png
# identify t2.png
# "t2.png PNG 35x24+2+2 PseudoClass 256c 8-bit 365.0 0.000u 0:01"
# mogrify -trim t2.png
# identify t2.png
# "tmp.png PNG 11x11+8+6 PseudoClass 256c 8-bit 306.0 0.000u 0:01"
# mogrify -crop 11x24+10+3 t1.png
# 
                }

                my $img = image_info($outimg);

                my $str = sprintf("width=\"%d.0\" height=\"%d.0\"",
                                  ($opts{'scale'} * $img->{width}),
                                  ($opts{'scale'} * $img->{height}) );
                $_[0] =~ s/($outimg\")/$1 $str/;

                
                if( $TWiki::Plugins::VERSION >= 1.1 ) 
                { 
                    # Dakar interface
                    TWiki::Func::saveAttachment( $web, $topic, $outimg,
                                                 { file => $outimg,
                                                   comment => '',
                                                   hide => 1 } );
                    unlink($outimg) unless $debug; # delete working copy
                } else {
                    # Cairo interface
                    
                    mkdir( $path.$pathSep )unless (-e $path.$pathSep);
                    
                    move($outimg,$path.$pathSep.$outimg) or 
                        $_[0] .= "<br> LatexModePlugin error: Move of $outimg failed: $!";
                }
                
                undef($img);
            }
        }
    } else {
	$_[0] .= "<br>Latex rendering error!! DVI file was not created.<br>";
    }

    #clean up the intermediate files
    unless ($debug) {
        opendir(D,$LATEXWDIR);
        my @files = grep(/$LATEXBASENAME/,readdir(D));
        close(D);

	foreach my $fn ( @files ) { 
            #again, we need to untaint the globbed filenames
            # next if ($fn =~ /index/);
            if( $fn =~ /^([-\@\w.]+)$/ ) {
                $fn = $1; # $fn now untainted
                unlink( "$fn" );
            } else {
                &TWiki::Func::writeDebug( "Bizzare error.  match of \$fn failed? $fn" ) if $debug;
            }
	}
    }

    #clear the hash table of math strings
    %hashed_math_strings = ();
    %markup_opts = ();
    &TWiki::Func::writeDebug( "Math strings reset, done." ) if $debug;

    # remove the log file
    unlink($LATEXLOG) unless ($debug);

    # remove the temporary working directory
    rmdir($LATEXWDIR);
    $LATEXWDIR = undef;
    # move back to the previous directory.
    # chdir($saveddir) if ( $saveddir );
}

sub round {
    
    my ($i) = @_;
    
    # my $a = ( ($i - int($i)) > 0.5 ) ? int($i) : int($i) + 1;
    my $a = int($i);
    $a = $a + 1 if ( ($i - int($i)) > 0.5 );

    return($a);
}

# =========================

1;


__DATA__
