# LatexModePlugin::Parse.pm
# Copyright (C) 2006 W Scott Hoge, shoge at bwh dot harvard dot edu
# Copyright (C) 2006 Evan Chou, chou86.e at gmail dot com
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
package TWiki::Plugins::LatexModePlugin::Parse;

use strict;

use vars qw( $VERSION $RELEASE );

=head1 The <nop>TWiki <nop>LatexModePlugin<nop>LaTeX Parse module

This module provides the ability to include <nop>LaTeX source files
in TWiki topics.

This module is *very alpha*.  It has successfully rendered a few test
examples.  But no warranty or fitness for a particular purpose is claimed.
Also, the translation syntaxes and processing order are subject to change.

This document describes version $Rev$ of the module.

=cut

$VERSION = '$Rev$';
$RELEASE = 0.1;

# ==========

my %thmhash;
my $thm_autonumber = 0;
my %commands;

# to prevent executing arbitrary code in the 'eval' below, allow
# only registered commands to run.
my @regSubs = ( '&addToTitle', '&formThanks' );

# open(F,"/var/www/twiki/conf/latex2tml.cfg") or die $!;
while (<DATA>) {
    next if ( length($_) == 0 or $_ =~ m/^\s+$/);

    my $s = substr($_,0,1,'');
    my @a = split(/$s/,$_);
    my %h;
    next if ($#a < 0);

    $h{'size'} = $a[1];

    $a[2] = substr($a[2],0,length($a[2])-2)."\n" if ($a[2] =~ m/\\n$/);
    $h{'command'} = $a[2];

    $commands{$a[0]} = \%h;
}
# close(F);
# print STDERR "Keys: ";
# print STDERR map {"$_  "} sort keys %commands;
# print STDERR ":Keys\n";

sub printF {

    my ($t) = @_;
    open(F,">>/tmp/alltex_uH.txt");
    print F $t;
    close(F);

}

=begin twiki

---++ Syntax

To include full <nop>LaTeX source documents in a TWiki topic, insert
the text to be converted inbetween the tags %<nop>BEGINALLTEX% and
%<nop>ENDALLTEX%.


---+++ Example

<verbatim>
%BEGINALLTEX%
\documentclass{article}

\begin{document}

\section{A Brand \emph{New} Day}

\fbox{ \[Ax =b \] }

\begin{itemize}
\item A
\item B
  \begin{enumerate}
  \item 1
  \item 2
    \begin{itemize}
    \item a
    \item b
    \end{itemize}
  \item 3
  \end{enumerate}
\item C
\end{itemize}

\end{document}

%<nop>ENDALLTEX%
</verbatim>

will be converted to

<verbatim>
---+ A Brand  <em>New</em> Day

<table align="left" border="1"><tr><td>
%BEGINLATEX{inline="0"}%\begin{displaymath} Ax =b  \end{displaymath}%ENDLATEX%
</table>

<ul>
<li> A
<li> B
  <ol>
  <li> 1
  <li> 2
    <ul>
    <li> a
    <li> b
    </ul>
  <li> 3
  </ol>
<li> C
</ul>

</verbatim>

=end twiki

=cut

sub handleAlltex
{

    my $txt = '';

    my $math_string = $_[0];
    my $params = $_[1];

    #get rid of comments
    # %  ... \n
    $math_string =~ s!%.*?\n!!gis;

    #everything between \documentclass and \begin{doc..} is preamble
    $math_string =~ m!(\\documentclass\s*(\[.*?\])?\s*\{.*?\})\s*(\[.*?\])?(.*?)\\begin\s*\{document\}\s*(.*?)\s*\\end\s*\{document\}!is;

    my $pre = $4;     # preamble
    my $doc = $5;     # document

    TWiki::Func::getContext()->{'LMPcontext'}->{'preamble'} .= $pre;
    TWiki::Func::getContext()->{'LMPcontext'}->{'docclass'} .= $1;
    printF($1);

    if ( exists(TWiki::Func::getContext()->{'genpdflatex'}) ) {
      # Note: needs improvement
      return('<latex>'.$math_string.'<latex>');
    }

    TWiki::Func::getContext()->{'LMPcontext'}->{'title'} = '';
    TWiki::Func::getContext()->{'LMPcontext'}->{'thanks'} = '';
    TWiki::Func::getContext()->{'LMPcontext'}->{'thankscnt'} = 0;

    unlink("/tmp/alltex_uH.txt");
    # printF("handleAlltex($params)");

=begin twiki

The parsing is done in three stages:
   1. All environments, e.g. =\begin{env} .. \end{env}= are extracted.  Known environments are converted to HTML/TML.  Unknown environments are rendered as images.
   2. All complex commands,  e.g. =\command{ .. }{ .. }=,  are extracted.  Known commands are converted to HTML/TML.  Unknown commands are maked as LATEX, for possible rendering in future version of the module or tranlations list.
   3. All known simple commands remaining in text that falls outside of the previous two types are converted.

=end twiki

=cut

    $doc = extractEnvironments( $doc )
        if ($TWiki::Plugins::LatexModePlugin::Parse::RELEASE > 0.01);

    $doc = extractBlocks( $doc )
        if ($TWiki::Plugins::LatexModePlugin::Parse::RELEASE > 0.01);

    # convert simple commands to TML
    # convertSimple($doc);

=begin twiki

    The output will be rendered in HTML by default.  Alternatively,
    one can render the output in TWiki Markup (TML).  This is achieved
    by declaring 
<verbatim>
   * Set LATEXMODEPLUGIN_ALLTEXMODE = tml
</verbatim>
    as a topic/web/twiki-wide preference setting, or by passing in =tml= as
    the =latex= parameter on view.  e.g. 
    <a href="%TOPIC%?latex=tml">%TOPIC%?latex=tml</a>

    The option of TML output is provided for the following reason: it
    is unlikely that all portions of the .tex to TWiki topic
    conversion will render successfully.  [ The _parser_ in almost
    complete. The _converter_? not so much. ;-) ] With a .tex to TML
    converter in place, one can copy-and-paste the twiki markup to
    another topic to correct the rendering problems.

=end twiki

=cut

    # replace all extracted verbatim blocks
    $doc =~ s/%VERBATIMBLOCK\{(.*?)\}%/&extractVerbatim($1)/ge;

    open(F,">/tmp/after_eB.txt");
    print F $doc;
    print F "\n"; print F 'x'x70; print F "\n";
    close(F);

    $doc = "<verbatim>\n".$doc."\n</verbatim>\n"
    if ( TWiki::Func::getContext()->{'LMPcontext'}->{'alltexmode'} );
    #we are done!
    return($doc);

}


sub convertSimple
{
    my %h = ( '~' => '&nbsp;',
              '\\noindent' => '',
              '\\maketitle' => TWiki::Func::getContext()->{'LMPcontext'}->{'title'}."\n<br>\n".TWiki::Func::getContext()->{'LMPcontext'}->{'thanks'}."\n<br>\n",
              '\\\\' => "<br>",
              '\vfill' => '',
              '\newblock' => '',
              '\\sloppy' => '' );

    foreach my $c ( keys %h) {
        my $m = $h{$c};
        # printF( "$c --> $m\n" );
        $_[0] =~ s/\Q$c\E/$m/g;
    }

}

sub convertEmbed
{
    my ($b) = @_;

    my %h = ( '\\em' => [ '<em>', '</em>' ],
              '\\bf' => [ '<strong>', '</strong>' ],
              '\\small' => [ '<font size="-2">','</font>' ],
              '\\tiny' => [ '<font size="-3">','</font>' ],
              '\\footnotesize' => [ '<font size="-4">','</font>' ],
              '\\large' => [ '<font size="+1">','</font>' ],
              '\\centering' => [ '<div align="center">', '</div>' ]
              );

    $b =~ s/^\s*\{(.*)(\\\/)?\}\s*$/$1/gs;

    # open(F,">>/tmp/alltex_uH.txt");
    # print F $b."\n";
    foreach my $c ( keys %h) {
        # print F "$c --> @{$h{'$c'}}\n";
        if ($b =~ s/\Q$c\E//g) {
            $b = $h{$c}[0].$b.$h{$c}[1];
        }
    }

    # close(F);
    return($b);
}

# use base qw( TWiki::Plugins::LatexModePlugin );

sub extractBlocks {

    my $doc = $_[0];

    my($pre,$block);
    my $txt = '';
    #resuse $pre for beginning    

    my @a;

    printF('-'x70); printF("\n");
    printF($doc);
    printF('-'x70); printF("\n");

    ## parse once through to collect all nested braces
    do {
	($pre,$block,$doc) = umbrellaHook( $doc,
                                       '\{',
                                       '\}');

        if ($pre =~ m/^(.*)(\\[\w\*]+?)$/s) {
            push(@a,$1);
            push(@a,$2);
        } elsif ( ($pre =~ m/[A-Z]+$/) || 
                  ($doc =~ m/^\%/) ){
            # printF("++ $pre ++ $block ++ $doc\n");
            # protect twiki commands, like %BEGINFIGURE{ ... }%
            $block = $pre.$block.substr($doc,0,1,'');
            printF("protecting '$block'\n");
        } else {
            push(@a,$pre);
        }
        push(@a,$block);
	# $txt .= $pre;
        # $txt .= "\n>>>> \n";
        # $txt .= $block;
        # $txt .= "\n<<<< \n";

    } while ($block ne '');

    #### Convert the found blocks
    my $b = '';
    do {
        $b = shift(@a);

        ## lump the BEGINLATEX .. ENDLATEX blocks together:
        my $cnt = 0; 
        while ($b=~m/(BEGIN|END)LATEX/g) { 
            ($1 eq 'BEGIN') ? $cnt++ : $cnt--;
        }
        # printF( "\n-- ".scalar(@a)."  $cnt\n".$b );
        while ( ($cnt !=0) and (scalar(@a) >0) ) {
            my $c = shift(@a);
            if ($c =~ s/^(.*?ENDLATEX%)//s) {
                $b .= $1;
                unshift(@a,$c);
                # printF( "\n***** $a[0]\n" );
                # printF( "\nxx ".scalar(@a)."\n".$b );
                $cnt = 0;
            } else {
                $b .= $c;
            }
        }
        printF( "\n++ ".scalar(@a)."\n".$b );
        ## BEGINLATEX .. ENDLATEX blocks are now grouped, proceed to treat
        ## remaining tex commands of the form '\cmd{}' and '\cmd'

        my ($cmd,$star,$opts) = ('','','');
        ($cmd,$star,$opts) = ($1,$2,$3) if
            ($b =~ m!(\\\w+)\b(\*?)(\[
                                  ([\\\w\d\.\=\,\s]+?)
                                  \])?$!xs); # test for a latex command;
        printF( "\nFound command: \n$cmd$star ") if ($cmd ne '');
        defined($opts) ? printF(" opts = $opts \n") : printF("\n");
        if ($cmd ne '') {
            if ( exists( $commands{$cmd} ) ) {
                my $sz = 0;
                my $str = $commands{$cmd}{'command'};
                # print F $b." ";
                do {
                    my $t = shift(@a);
                    if (length($t) > 0) {
                        $t = substr($t,1,length($t)-2);
                        printF( "  :".$t.": " );

                        if ($t =~ m/([\d\.]+)\\linewidth/) {
                            $t = sprintf("%4.2f",($1/1)*100)."\%";
                        }
                        $sz++;
                        $str =~ s/\$$sz/$t/gs;
                    }
                } while ($sz < $commands{$cmd}{'size'});
                $str =~ s/\$o/$opts/;
                printF("\n$str\n---\n");

                if ($cmd eq '\label') {
                    my $t = ' %SECLABEL{'.$str.'}% ';
                    $txt =~ s/(---\++\!?\s+)([\w\s\$\%\\]+)$/$1$t$2/s;
                } else {

                    my $cmd = $1 if ($str =~ s/^(&\w+)\((.*)\)$/$2/s);

                    $str = extractBlocks($str) if ($str =~ m/\\/); 
                    convertSimple($str);

                    if (defined($cmd)) {
                        $str =~ s/^(\"|\')|(\"|\')$//g;
                        printF("Try dynamic command: $cmd($str)\n");
                        my @z = grep(@regSubs,$cmd);

                        if ($cmd eq $z[0]) {
                            my $t;
                            eval('$t = '.$cmd.'($str);'); 
                            printF(" ".$@) if $@;
                            $txt .= $t;
                        }
                    } else {
                        $txt .= convertEmbed( $str );
                    }
                }
                printF( "\n" );
            } else {
                my $lngth = length($b)-length($cmd);
                $lngth = $lngth - length($opts) if defined($opts);
                my $pre = substr($b,0,$lngth);

                &convertSimple($pre);
                $opts .= shift(@a) if ($a[0]=~m/^\{/);

                $txt .= convertEmbed( $pre.' %<nop>BEGINLATEX% '.$cmd.$opts.' %ENDLATEX% ' );
            } 
        # } elsif ( $b =~ m/^\s*\\/ ) {
        #     if ( $a[0] =~ m/\{/) {
        #         $b .= shift(@a);
        #     }
        #     $txt .= '%BEGINLATEX%'.$b.'%ENDLATEX%';
        } else {
            #my $t = shift(@a);
            #if ($t =~ m/^\s*\{/) {
            #    print F "\ntesting: $b$t \n";
            #}
            # unshift(@a,$t);

            if ($b =~ m/^(.*?)%BEGINLATEX.*?ENDLATEX%/s)  {
                my $g = $b;
                my ($o2,$n2) = (undef,undef);
                do {
                    # printF( "====".$g."=====\n" );
                    my $o1 = $1; $o2 = $2;
                    my $n1 = $o1; $n2 = $o2;
                    if ($n1=~m/\\\w+/) {
                        $n1 = extractBlocks($n1);
                        convertSimple($n1);
                    }
                    # printF( "==__".$n1."__===\n" );
                    $b =~ s/\Q$o1\E/$n1/;
                } while ($g =~ s/\G(.*?)%BEGINLATEX.*?ENDLATEX%(.*)/$2/sg);

                if (length($o2)>0) {
                    # if ($n2=~m/\\\w+/) {
                        $n2 = extractBlocks($n2);
                        convertSimple($n2);
                    # }
                    # printF( "\n=+=+".$b."+=+= $o2\n" );
                    $b =~ s/\Q$o2\E/$n2/;
                    # printF( "\n=-=-".$b."-=-=\n" );
                }
            } else {
                convertSimple($b);
            }

            $b = convertEmbed($b); # if ($b =~ m/\\/);
            $txt .= $b;
        }
    } while (scalar(@a)>0);

    #there is still some $doc left:
    $txt .= $doc;

    return($txt);
}

sub mathShortToLong {

    $_[0] =~ s!\\\[(.*?)\\\]!\\begin\{displaymath\} $1 \\end\{displaymath\}!gis;
    $_[0] =~ s!\$\$(.*?)\$\$!\\begin\{displaymath\} $1 \\end\{displaymath\}!gis;
    $_[0] =~ s!\$(.*?)\$!\\begin\{math\} $1 \\end\{math\}!gis;

}

sub extractEnvironments {

    my $doc = $_[0];

    my($pre,$block);
    my $txt = '';
    do {
	($pre,$block,$doc) = umbrellaHook( $doc,
                                           '\\\\begin\s*\{.*?\}',
                                           '\\\\end\s*\{.*?\}');
        &mathShortToLong($pre);
        $pre = extractEnvironments($pre) if ($pre =~ m/\\begin\{.*?math\}/);
	$txt .= $pre;

        if ($block =~ m/^\\begin\{verbatim\}/) {
            $txt .= '%VERBATIMBLOCK{'.storeVerbatim($block).'}%';
        } else {
            #change all $$'s to begin maths!
            ### warning: can't do this within verbatim blocks!
            &mathShortToLong($block);
            $txt .= convertEnvironment($block) if ($block ne '');
        }
    } while ($block ne '');

    #there is still some $doc left:
    &mathShortToLong($doc);
    $doc = extractEnvironments($doc) if ($doc =~ m/\\begin\{.*?math\}/);
    $txt .= $doc;

    return($txt);
}

=begin twiki

---++ Supported Environments

   * $ .. $, $$ .. $$, \[ .. \], math, displaymath, equation, eqnarray
   * itemize, enumerate, description
   * table, figure
   * abstract, bibliography, keywords

<nop>LaTeX enviroments that are _not supported_ are passed to the TWiki
<nop>LaTeX rendering engine to generate an image.  For nested
environments, image rendering occurs at the first unrecognized enviroment.

=end  twiki

=cut

sub convertEnvironment
{
    my ($block) = @_;

    printF("\n"); printF('-'x70); printF("\n");
    printF($block);
    printF("\n"); printF('-'x70); printF("\n");

    #now process the block!
    $block =~ m!^\\begin\{(.*?)\}!si;
    my $bname = $1;

    my $txt = '';
    my $label = '';
    $label = 'label="'.$1.'"' if ($block=~s!\\label\{(.*?)\}\s*!!);

    if ($bname eq 'math') {
        $txt .= '%BEGINLATEX{inline="1"}%'.$block.'%ENDLATEX%';
    }
    elsif ( ($bname eq 'displaymath') ||
            ($bname eq 'eqnarray*') ){
        $txt .= '%BEGINLATEX{inline="0"}%'.$block.'%ENDLATEX%';
    }
    elsif ($bname eq 'eqnarray') {
        $block =~ s!(\\\\|\\end\{eqnarray\})!\\nonumber $1!g;
        $txt .= '%BEGINLATEX{inline="0" '.$label.'}%'.$block.'%ENDLATEX%';
    }
    elsif ($bname eq 'center') {
        $block =~ s!\\(begin|end)\{center\}!!g;
        $block =  extractEnvironments($block);
        $block =  extractBlocks($block);

        $txt .= '<div align="center">'.$block.'</div>';
    } 
    elsif ($bname eq 'equation') {
        $block =~ s/\n\s*\n/\n/g;
        $block =~ s!\\(begin|end)\{equation\}!\\$1\{displaymath\}!g;
        # print STDERR $block."\n";
        $txt .= '%BEGINLATEX{inline="0" '.$label.'}%'.$block.'%ENDLATEX%';
    }
    elsif ( ($bname eq 'quotation') || ($bname eq 'quote') ) {
        $block =~ s!^\\begin\{$bname\}!<blockquote>!;
        $block =~ s!\\end\{$bname\}$!</blockquote>!;

        $block = extractEnvironments($block);
        $block = extractBlocks( $block );
    }
    # elsif ($bname eq 'verbatim') {
    #     $block =~ s!^\\begin\{$bname\}!<verbatim>!;
    #     $block =~ s!\\end\{$bname\}$!</verbatim>!;
    #     $block =~ s/\\(begin|end){math}/\$/g;
    #     $txt .= $block;
    # }
    elsif ( ($bname =~ m/(itemize|enumerate|description)/ ) ) {
        my $tag = 'ul>';
        $tag = 'ol>' if ($1 eq 'enumerate');
        $tag = 'dl>' if ($1 eq 'description');

        $block =~ s!^\\begin\{$bname\}!\<$tag!;
        $block =~ s!\\end\{$bname\}$!\</$tag!;
        while ($block =~ m/\\(.+?)\b/g) {
            my $match = $1;
            my $pos = (pos $block) - length($match) - 1;
            $txt .= substr($block,0,$pos,'');

            if ($match eq 'item') {
              if ($tag eq 'dl>') {
                $block =~ s/^\\item\[(.*?)\]/<dt> *$1* <\/dt><dd>/;
                $block =~ s!^\\item!<dt></dt><dd>!;
              } else {
                $block =~ s/^\\item\[(.*?)\]/<li value="$1">/;
                $block =~ s/^\\item/<li>/;
              }
            }
            elsif ($match eq 'begin') {
                my ($pre,$blk2,$post);
                ($pre,$block,$post) = umbrellaHook( $block, 
                                                    '\\\\begin\s*\{.*?\}',
                                                    '\\\\end\s*\{.*?\}');
                $txt .= $pre.convertEnvironment($block);
                $block = $post;
            } else {            # ignore it...
                $txt .= substr($block,0,length($match)+2,'');
            }
        }
        $txt .= $block;
    }
    elsif ($bname =~ /(figure|table)(\*?)/) {
        my $type = uc($1);
        my $span = ($2 eq '*') ? ' span="twoc" ' : '';
        $block =~ s!^\\begin\{$bname\*?\}(\[\w+\])?!!;
        $block =~ s!\\end\{$bname\*?\}$!!; 

        $block =~ s/(.+)\\caption//s;
        my $env = $1;

        my ($pre,$caption) = ('','');
	($pre,$caption,$block) = umbrellaHook( $block,
                                               '\{',
                                               '\}');
        $env .= $block;
        if (length($caption) > 0) {
            $caption = substr($caption,1,length($caption)-2);
            if ($caption =~ m/\\/) {
                $caption = extractEnvironments($caption);
                $caption = extractBlocks( $caption );
                $caption =~ s/\"/\\\"/g;
            }
            $caption = 'caption="'.$caption.'"';
        }
        $txt .= '%BEGIN'.$type.'{'.$label.' '.$caption.' '.$span.'}%';

        $env = extractEnvironments($env);

        $txt .= $env;
        $txt .= '%END'.$type.'%';
    }
    elsif ($bname =~ /abstract|keywords/) {
        my $env = $block;
        $env =~ s!\\begin\{$bname\*?\}!!;
        $env =~ s!\\end\{$bname\*?\}!!; 

        $env = extractEnvironments($env);

        $txt .= "<blockquote>\n*".ucfirst($bname).":* ".$env."</blockquote>\n";

    }
    elsif ($bname =~ /bibliography/) {
        # for this to work, the LatexModePlugin must precede the BibtexPlugin
        # i.e. in LocalSite.cfg: $TWiki::cfg{PluginsOrder} = 'SpreadSheetPlugin,LatexModePlugin,BibtexPlugin';
        my $env = $block;
        $env =~ s!\\begin\{$bname\*?\}(\{\d+\})?!!;
        $env =~ s!\\end\{$bname\*?\}!!;
        $txt .= "\n<h1>References</h1>\n<div class=\"bibtex\"><table><tr>";
        my $cnt = 1;
        while ($env =~ m!\\bibitem\{(.*?)\}!g) {
            my $t = "<tr valign=\"top\"><td>[<a name=\"$1\">".$cnt."</a>] </td>\n<td> ";
            $env =~ s!\\bibitem\{$1\}!$t!;
            $cnt++;
        }
        $env =~ s/\~/&nbsp;/g;
        while ($env =~ m!\{(.*?)\}!g) {
            my $t = $1;
            $env =~ s/\{$t\}/$t/ unless ($env =~ m!\\[^\s]+\{$t\}!);
        }
        $txt .= $env."</table></div>\n";
    }
    else {
        # $txt .= "<br><blockquote>\n---- \n";
         # $block =~ s/$env/convertEnvironment($env)/e if ($env=~m/\begin\{/);
        # $txt .= $block;
        $txt .= "%BEGINLATEX%\n".$block."%ENDLATEX%\n";
        # $txt .= "<br>\n---- <br></blockquote>\n";
        # $text .= LaTeX2TML($block);
    }

    return($txt);
}


## derived from code contributed by TWiki:EvanChou 
#
#
#helper function that grabs the right tag (no need for weird divtree)
#do not give regex delimiteres that match!
#
sub umbrellaHook
{
    #pass in the process text, and delimiters (in regex)
    #returns list (before,umbrella,after) (first one it sees)
    my $txt = $_[0]; 
    my $delim_l = $_[1];
    my $delim_r = $_[2];

    # open(F,">>/tmp/alltex_uH.txt");
    # print F $txt;
    # print F "\n"; print F '-'x70; print F "\n";
    # close(F);

    my $nleft = 0;
    my $nright = 0;
    my $umb = '';
    my $front;

    my $before = '';

    if($txt =~ m!$delim_l!is) {
	$nleft++;
	$before = $`;
	$umb = $&;
	$txt = "$'";

#	return ($before, $umb,$txt);
#	my $pl = -1;
#	my $pr = -1;

	while($nright < $nleft) {

	    if($txt =~ m!$delim_r!is) {
		$nright++;
	    }
	    else {
		#mismatch!	       		
		$txt = $before . $umb . $txt;
		$before = '';
		$umb = '';
		last;
	    }


	    $front = $`;
	    $umb .= $` . $&;
	    $txt = "$'";

	    #count how many left's are before this right
	    while($front =~ m!$delim_l!is) {
		$nleft++;
		$front = "$'";
	    }
#	    if($pl == $nleft && $pr == $nright) {
#		die("Delimiter mismatch!");
#	    }

#	    $pl = $nleft;
#	    $pr = $nright;
	}
    }
    else {
    }
    return ($before, $umb, $txt);

}

sub handleNewTheorem {

    my $pre = $_[0];

    #parse preamble and set up theorem numbering
    #first find the section-linked thm (\newtheorem{$envname}{$type}[section])
    if($pre =~ m!\\newtheorem\{(.*?)\}\{(.*?)\}\[section\]!i) {
	#$1 = theorem env name
	#$2 = theorem type
	my $thm_envname = $1;
	my $thm_type = $2;
	my $thm_maintype = $1;

	$thmhash{$thm_envname} = $thm_type;
	$thm_autonumber = 1;

	#now find everything else that is associated with it
	# \newtheorem{$envname}[$thm_maintype]{$type}
	$thm_maintype = quotemeta($thm_maintype);

#	$txt .= "$thm_maintype \n $pre \n";
	while ($pre =~ m!\\newtheorem\s*\{(.*?)\}\[$thm_maintype\]\{(.*?)\}!i) {
	    #$1 = env name
	    #$2 = thm type
	    $thm_envname = $1;
	    $thm_type = $2;
	    $thmhash{$thm_envname} = $thm_type;

	    $thm_envname = quotemeta($thm_envname);
	    $thm_type = quotemeta($thm_type);
	    $pre =~ s!\\newtheorem\{$thm_envname\}\[$thm_maintype\]\{$thm_type\}!!i;

#	    $txt .= "$thm_envname => $thm_type\n";
	}
    }
}

1;

=begin twiki

---++ Supported simple and complex commands

   * commands with reasonably complete support (.tex --> HTML/TML)
      * section, subsection, subsubsection
      * cite, ref
      * parbox, fbox
      * emph, em, centering, bf
      * large, small, tiny, footnotesize

   * commands with limited support
      * includegraphics, 
      * label (works with equations and sections) 
      * title, address, name, maketitle (these work, but don't match the latex class output of the original document)

   * commands that are ignored
      * vspace, hspace, vfill, noindent, sloppy

All mathmode commands are supported, as all mathmode enviroments are
rendered as an image using the background =latex= engine.  Commands
that are not recognized are tagged as LATEX.  In future versions of
the module, these may be passed off to the rendering engine as well.
Error handling needs to be improved before this will be useful,
however.

---++ Installation

For now, the TWiki::Plugins::LatexModePlugin::Parse module is only
available on the TWiki SVN development tree, <a
href="http://svn.twiki.org:8181/svn/twiki/branches/TWikiRelease04x00/twikiplugins/LatexModePlugin/lib/TWiki/Plugins/LatexModePlugin">here</a>.
Download the Parse.pm file and copy it to the
=lib/TWiki/Plugins/LatexModePlugin/= directory of your TWiki
installation.  Documentation for the module is provided in 
=pod= format, and can be view using the TWiki:PerlDocPlugin.


---++ Translation syntax

Here is a description of the syntax used to define <nop>LaTeX to
HTML/TML translations in the module.

Environments are currently handled by code chunks.  See the
=convertEnvironment= subroutine for examples.

The syntax for complex commands is a mash-up between <nop>LaTeX and
Perl.  In a single line, the command and its replacement are
described.  This first character is the array seperator, used in the
Parse =split= command.

   * The first array element is the latex command.
   * The second element is the number of bracketed blocks the command uses
   * The third array element is the replacement command.

The numbered strings, =$1, $2, ...= etc., are used to declare the
placement of the bracketed blocks in the replacement.  Command
options, =\cmd[ _opts_ ]{ .. }= can be included with an =$o= string in
the replacement.

An example:
<verbatim>
!\parbox!2!<table align="left" width="$1"><tr><td>$2</table>!
</verbatim>

If one needs greater flexibility, the replacement command can be a
function call.  The function call needs to start with an apersand,
=&=, and the full function name needs to be regestered in the global
=regSubs= array.  See the lines for =\author=, =\title=, and
=\address= for examples.


Feel free to submit code patches to expand the list of known commands
and environments!



---++ Caveat Emptor

This is what it is.  And it is not a replacement for more complete
<nop>LaTeX2HTML translators like
[[http://www.latex2html.org/][latex2html]],
[[http://pauillac.inria.fr/~maranget/hevea/index.html][helvea]]
or [[http://www.ccs.neu.edu/home/dorai/tex2page/tex2page-doc.html][tex2page]].
It may eventually grow to become something close to those, but it's
not there yet.

---++ Dev Notes

---+++ Rendering Weirdness.

It turns out that the idea of passing off unwieldy markup to the
rendering engine is dicey at best.  This was attempted with
=\maketitle=, and =dvipng= complained about missing fonts.  It's
probably better to have custom rountines to produce HTML/TML where
possible.

Switching between =dvips+convert= and =dvipng= can get around this
problem to render all of the images.  But this is not a serious
solution.

---+++ Including Graphics

There are many ways to include graphics in latex files.  So, I figured the most reasonable way to support them all is to render them using the backend image rendering.  This actually works OK, but introduces some minor complications.   For parsing and rendering raw latex files, the orginal _graphics_ files needs to be in .eps format in order to be understood by the =latex= command used during background rendering.  However, the =genpdflatex= script uses =pdflatex= instead, which works better with .pdf or .png image files.  One solution is to store .eps files and use =epstopdf= from the <nop>teTeX distribution to convert them to .pdf when using =genpdflatex=.   Alternatively, one can write a custom TWiki macro to handle attached .pdf images (e.g. %<nop>SHOWPDF{image.pdf}%), and then use a translation declaration to render the image (e.g. =:\includegraphics:1:%<nop>SHOWPDF{$1}:=).


---++ Acknowledgements

Thanks to <a href="http://twiki.org/cgi-bin/view/Main/EvanChou">EvanChou</a> for the inspiration for taking this on, and for
providing the core parsing routines.


=end twiki

=cut

sub storeVerbatim {

    push( @{ TWiki::Func::getContext()->{'LMPcontext'}->{'verb'} }, $_[0] );
    return( scalar( @{ TWiki::Func::getContext()->{'LMPcontext'}->{'verb'} } ) );
}

sub extractVerbatim {

    my @a = @{ TWiki::Func::getContext()->{'LMPcontext'}->{'verb'} };

    my $block = $a[ $_[0] ];
    $block =~ s!^\\begin\{verbatim\}!<verbatim>!;
    $block =~ s!\\end\{verbatim\}$!</verbatim>!;

    return( $block );
}

sub addToTitle {

    my ($str) = @_;   

    TWiki::Func::getContext()->{'LMPcontext'}->{'title'} .= $str."\n";
    return('');
}

sub formThanks {
    my ($str) = @_;

    my $cnt =   TWiki::Func::getContext()->{'LMPcontext'}->{'thankscnt'};
    $cnt = $cnt + 1;

    $str =~ s/(ENDLATEX%)(.*)$/$1/s;

    TWiki::Func::getContext()->{'LMPcontext'}->{'thanks'} .=
        $cnt.'. '.$2."<br>\n";

    $str =~ s/\$c/$cnt/;

    TWiki::Func::getContext()->{'LMPcontext'}->{'thankscnt'} = $cnt;

    return($str);
}

# :\includegraphics:1:%SHOWPDF{$1}%:
#
# :\title:1: <h1 align="center">$1</h1> :

__DATA__
:\section:1:---+ $1 \n:
:\subsection:1:---++ $1 \n::
:\subsubsection:1:---+++ $1 \n::
:\cite:1:%CITE{$1}%:
!\ref!1!%REFLATEX{$1}%!
!\eqref!1!%REFLATEX{$1}%!
!\parbox!2!<table align="left" width="$1"><tr><td>$2</table>!
!\fbox!1!<table align="left" border="1"><tr><td>$1</table>!
:\emph:1: <em>$1</em>:
:\vspace*:1::
:\vspace:1::
:\hspace*:1::
:\hspace:1::
:\name:1:&addToTitle('<div align="center">$1</div>'):
:\includegraphics:1:%BEGINLATEX{attachment="$1"}% \includegraphics$o{$1} %ENDLATEX%:
:\label:1:$1:  # modifies a past-parsed string to insert %SECLABEL% above
:\bibliography:1:%<nop>BIBTEXREF{file="$1"}%
:\maketitle:0: \maketitle :
:\thanks:1:&formThanks('%BEGINLATEX{inline="1"}% $^$c$ %ENDLATEX% $1'):
!\footnote!1! <br><hr style="height:1px;width:90%"><font size="-3"> $1 </font><hr  style="height:1px;width:90%">!
:\runningtitle:2: :
:\title:1:&addToTitle(<h1 align="center">$1</h1>):
:\author:1:&addToTitle(<div align="center"><font size="+1">$1</font></div>):
!\address!1!&addToTitle(<table align="center"><tr><td valign="top">Address correspondence to:<td valign="top">$1</table>)!
:\url:1:$1:
