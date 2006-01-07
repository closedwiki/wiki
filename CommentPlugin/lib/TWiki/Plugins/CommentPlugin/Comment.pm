# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2004 Crawford Currie
# Copyright (C) 2001-2006 TWiki Contributors.
# All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# For licensing info read LICENSE file in the TWiki root.
#
# Comment TWiki plugin
# Original author David Weller, reimplemented by Peter Masiar
# and again by Crawford Currie
#
# This version is specific to TWiki::Plugins::VERSION > 1.026

use strict;

use TWiki;
use TWiki::Plugins;
use TWiki::Store;
use TWiki::Attrs;
use CGI qw( -any );

package TWiki::Plugins::CommentPlugin::Comment;

# PUBLIC save the given comment.
sub save {
    #my ( $text, $topic, $web ) = @_;

    my $wikiUserName = TWiki::Func::getWikiUserName();
    if( ! TWiki::Func::checkAccessPermission( 'change', $wikiUserName, '',
											  $_[1], $_[2] ) ) {
        # user has no permission to change the topic
        throw TWiki::OopsException( 'accessdenied',
                                    def => 'topic_access',
                                    web => $_[2],
                                    topic => $_[1] );
    } else {
        _buildNewTopic( @_ );
    }
}

# PUBLIC STATIC convert COMMENT statements to form prompts
sub prompt {
    #my ( $previewing, $text, $web, $topic ) = @_;

    my $defaultType = 
      TWiki::Func::getPreferencesValue('COMMENTPLUGIN_DEFAULT_TYPE') ||
          'below';

    my $message = '';
    # Is commenting disabled?
    my $disable = '';
    if ( $_[0] ) {
        # We are in Preview mode
        $message  = "(Edit - Preview)";
        $disable = 'disabled';
    }

    my $idx = 0;
    $_[1] =~ s/%COMMENT({.*?})?%/&_handleInput($1,$_[2],$_[3],\$idx,$message,$disable,$defaultType)/ego;
}

# PRIVATE generate an input form for a %COMMENT tag
sub _handleInput {
    my ( $attributes, $web, $topic, $pidx, $message,
         $disable, $defaultType ) = @_;

    $attributes =~ s/^{(.*)}$/$1/o if ( $attributes );
    my $attrs = new TWiki::Attrs( $attributes, 1 );
    my $type =
      $attrs->remove( 'type' ) || $attrs->remove( 'mode' ) || $defaultType;
    my $silent = $attrs->remove( 'nonotify' );
    my $location = $attrs->remove( 'location' );

    # clean off whitespace
    $type =~ m/(\S*)/o;
    $type = $1;

    # Expand the template in the context of the web where the comment
    # box is (not the target of the comment!)
    my $input = _getTemplate( "PROMPT:$type", $topic, $web ) || '';

    return $input if $input =~ m/^%RED%/so;

    # Expand special attributes as required
    $input =~ s/%([a-z]\w+)\|(.*?)%/&_expandPromptParams($1, $2, $attrs)/iego;

    # see if this comment is targeted at a different topic, and
    # change the url if it is.
    my $anchor = undef;
    my $target = $attrs->remove( 'target' );
    if ( $target ) {
        # extract web and anchor
        if ( $target =~ s/^(\w+)\.//o ) {
            $web = $1;
        }
        if ( $target =~ s/(#\w+)$//o ) {
            $anchor = $1;
        }
        if ( $target ne '' ) {
            $topic = $target;
        }
    }

    my $url = '';
    if ( $disable eq '' ) {
        $url = TWiki::Func::getScriptUrl( $web, $topic, 'save' );
    }

    my $noform = $attrs->remove('noform') || '';

    if ( $input !~ m/^%RED%/o ) {
        $input =~ s/%DISABLED%/$disable/go;
        $input =~ s/%MESSAGE%/$message/g;
        my $n = $$pidx + 0;

        if ( $disable eq '' ) {
            $input .= CGI::hidden( -name=>'comment_action', -value=>'save' );
            $input .= CGI::hidden( -name=>'comment_type', -value=>$type );
            if( defined( $silent )) {
                $input .= CGI::hidden( -name=>'comment_quietly', value=>1 );
            }
            if ( $location ) {
                $input .= CGI::hidden( -name=>'comment_location', -value=>$location );
            } elsif ( $anchor ) {
                $input .= CGI::hidden( -name=>'comment_anchor', -value=>$anchor );
            } else {
                $input .= CGI::hidden( -name=>'comment_index', -value=>$$pidx );
            }
        }
        unless ($noform eq 'on') {
            $input = CGI::start_form( -name => $type.$n, -action=>$url,
                                      -method=>'post' ).$input.CGI::end_form();
        }
    }
    $$pidx++;
    return $input;
}

# PRIVATE get the given template and do standard expansions
sub _getTemplate {
    my ( $name, $topic, $web ) = @_;

    # Get the templates.
    my $templateFile =
      TWiki::Func::getPreferencesValue('COMMENTPLUGIN_TEMPLATES') ||
          'comments';

    my $templates =
      TWiki::Func::loadTemplate( $templateFile );

    if (! $templates ) {
        TWiki::Func::writeWarning("Could not read template file '$templateFile'");
        return;
    }

    my $t = TWiki::Func::expandTemplate( $name );
    return "%RED%No such template def TMPL:DEF{$name}%ENDCOLOR%"
      unless ( defined($t) && $t ne '' );

    return $t;
}

# PRIVATE expand special %param|default% parameters in PROMPT template
sub _expandPromptParams {
    my ( $name, $default, $attrs ) = @_;

    my $val = $attrs->{$name};
    return $val if defined( $val );
    return $default;
}

# PRIVATE STATIC Performs comment insertion in the topic.
sub _buildNewTopic {
    #my ( $text, $topic, $web ) = @_;
    my ( $topic, $web ) = ( $_[1], $_[2] );

    my $query = TWiki::Func::getCgiQuery();
    return unless $query;

    my $type = $query->param( 'comment_type' );
    my $index = $query->param( 'comment_index' );
    my $anchor = $query->param( 'comment_anchor' );
    my $location = $query->param( 'comment_location' );
    my $silent = $query->param( 'comment_quietly' );
    my $output = _getTemplate( "OUTPUT:$type", $topic, $web );
    if ( $output =~ m/^%RED%/o ) {
        die $output;
    }

    # Expand the template
    my $position = 'AFTER';
    if( $output =~ s/%POS:(.*?)%//go ) {
        $position = $1;
    }

    # Expand common variables in the template, but don't expand other
    # tags.
    $output = TWiki::Func::expandVariablesOnTopicCreation($output);

    # SMELL: Reverse the process that inserts meta-data just performed
    # by the TWiki core, but this time without the support of the
    # methods in the core. Firtunately this will work even if there is
    # no embedded meta-data.
    # Note: because this is Dakar, and has sensible semantics for handling
    # the =text= parameter to =save=, there is no longer any need to re-read
    # the topic. The text is automatically defaulted to the existing topic
    # text if the =text= parameter isn't specified - which for comments,
    # it isn't.
    my $premeta = '';
    my $postmeta = '';
    my $inpost = 0;
    my $text = '';
    foreach my $line ( split( /\r?\n/, $_[0] )) {
        if( $line =~ /^%META:[^{]+{[^}]*}%/ ) {
            if ( $inpost) {
                $postmeta .= $line."\n";
            } else {
                $premeta .= $line."\n";
            }
        } else {
            $text .= $line."\n";
            $inpost = 1;
        }
    }

    if ( $position eq 'TOP' ) {
        $text = $output.$text;
    } elsif ( $position eq 'BOTTOM' ) {
        # Awkward newlines here, to avoid running into meta-data.
        # This should _not_ be a problem.
        $text =~ s/[\r\n]+$//;
        $text .= "\n" unless $output =~ m/^\n/s;
        $text .= $output;
        $text .= "\n" unless $text =~ m/\n$/s;
    } else {
        if ( $location ) {
            if ( $position eq 'BEFORE' ) {
                $text =~ s/($location)/$output$1/m;
            } else { # AFTER
                $text =~ s/($location)/$1$output/m;
            }
        } elsif ( $anchor ) {
            # position relative to anchor
            if ( $position eq 'BEFORE' ) {
                $output =~ s/\n$//;
                $text =~ s/^($anchor)\b/$output\n$1/m;
            } else { # AFTER
                $output =~ s/^\n+//;
                $text =~ s/^($anchor)\b/$1\n$output/m;
            }
        } else {
            # Position relative to index'th comment
            my $idx = 0;
            unless( $text =~ s((%COMMENT({.*?})?%.*\n))
                    (&_nth($1,\$idx,$position,$index,$output))eg ) {
                # If there was a problem adding relative to the comment,
                # add to the end of the topic
                $text .= $output;
            };
        }
    }
    $_[0] = $premeta . $text . $postmeta;
}

# PRIVATE embed output if this comment is the interesting one
sub _nth {
    my ( $tag, $pidx, $position, $index, $output ) = @_;

    if ( $$pidx == $index) {
        if ( $position eq 'BEFORE' ) {
            $tag = $output.$tag;
        } else { # AFTER
            $tag .= $output;
        }
    }
    $$pidx++;
    return $tag;
}

1;
