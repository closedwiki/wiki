# See bottom of file for copyright and license details

=pod

---+ package TWiki::If::Node

Node class for the result of an If statement parse

=cut

package TWiki::If::Node;
use base 'TWiki::Query::Node';

sub newLeaf {
    my( $class, $val, $type ) = @_;
    if( $type == $TWiki::Infix::Node::NAME && $val =~ /^({\w+})+$/) {
        eval '$val = $TWiki::cfg'.$val;
        return $class->SUPER::newLeaf($val, $TWiki::Infix::Node::STRING);
    } else {
        return $class->SUPER::newLeaf($val, $type);
    }
}

sub OP_context {
    my( $this, %domain ) = @_;
    my $a = $this->{params}->[0];
    my $text = $a->evaluate() || '';
    my $session = $domain{tom}->session;
    throw Error::Simple('No context in which to evaluate "'.
                          $a->stringify().'"') unless $session;
    return $session->inContext($text) || 0;
}

sub OP_dollar {
    my( $this, %domain ) = @_;
    my $a = $this->{params}->[0];
    my $session = $domain{tom}->session;
    throw Error::Simple('No context in which to evaluate "'.
                          $a->stringify().'"') unless $session;
    my $text = $a->evaluate() || '';
    if( $text && defined( $session->{cgiQuery}->param( $text ))) {
        return $session->{cgiQuery}->param( $text );
    }
    $text = "%$text%";
    TWiki::expandAllTags($session, \$text,
                         $session->{topicName},
                         $session->{webName});
    return $text || '';
}

sub OP_defined {
    my( $this, %domain ) = @_;
    my $a = $this->{params}->[0];
    my $session = $domain{tom}->{_session};
    throw Error::Simple('No context in which to evaluate "'.
                          $a->stringify().'"') unless $session;
    my $eval =  $a->evaluate();
    return 0 unless $eval;
    return 1 if( defined( $session->{cgiQuery}->param( $eval )));
    return 1 if( defined(
        $session->{prefs}->getPreferencesValue( $eval )));
    return 1 if( defined( $session->{SESSION_TAGS}{$eval} ));
    return 0;
}

1;

__DATA__

Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/

Copyright (C) 2005-2007 TWiki Contributors. All Rights Reserved.
TWiki Contributors are listed in the AUTHORS file in the root of
this distribution. NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.

Author: Crawford Currie http://c-dot.co.uk
