package DOM;

# $Id: DOM.pm 490 2005-06-13 20:39:26Z nodine $

# This package contains routines for DOM objects

# Data structures:
#   _`DOM`: Recursive hash reference with following 
#     keys:
#       ``tag``:      The name of the tag of the DOM object
#       ``attr``:     Reference to hash of attribute/value pairs
#       ``content``:  Reference to array of DOM objects
#       ``text``:     Contains the literal text for #PCDATA
#       ``internal``: Reference to hash of internal attribute/value pairs
#       ``source``:   Optionally contains the source
#       ``lineno``:   Optionally contains the line number
#       ``lit``:      Optionally contains the literal text
#       ``val``:      The value returned by the DOM's handler (added 
#                     during traversal of the writer's handlers)

use strict;

# CLASS METHOD.
# Creates a new DOM object.
# Arguments: (optional) tag, (optional) list of attribute/value pairs
# Returns: DOM object
sub new {
    my ($class, $tag, %attr) = @_;

    my $dom = bless { };
    $dom->{tag} = $tag if defined $tag;
    $dom->{attr} = {%attr} if %attr;
    $dom->{content} = [];
    return $dom;
}

# CLASS METHOD.
# Creates a new DOM object that is a "#PCDATA" type.
# Arguments: text
# Returns: DOM object
sub newPCDATA {
    my ($class, $text) = @_;

    return bless {tag=>'#PCDATA', text=>$text, content=>[] };
}

# INSTANCE METHOD.
# Appends to the contents of a DOM object.
# Arguments: DOM objects to append
# Returns: None
sub append {
    my ($dom, @doms) = @_;

    push (@{$dom->{content}}, @doms);
}

# INSTANCE METHOD.
# Returns the index of a child in the contents (-1 if it does not occur).
# Arguments: child DOM object
# Returns: index number
sub index {
    my ($dom, $child) = @_;
    my $i;
    for ($i=0; $i<@{$dom->{content}}; $i++) {
	return $i if $dom->{content}[$i] == $child;
    }
    return -1;
}

# INSTANCE METHOD.
# Returns the last DOM in the contents of a DOM.
# Arguments: None
# Returns: last DOM object (or undefined)
sub last {
    my ($dom) = @_;

    my $last;
    if (@{$dom->{content}}) {
	$last = $dom->{content}[-1];
    }
    return $last;
}

# INSTANCE METHOD.
# Puts the arguments at the beginning of the contents of a DOM object.
# Arguments: DOM objects to append
# Returns: None
sub prepend {
    my ($dom, @doms) = @_;

    unshift (@{$dom->{content}}, @doms);
}

# INSTANCE METHOD.
# Goes through a DOM object recursively calling a subroutine on every
# element.  It can do either preorder, postorder or bothorder traversal
# (defaults to postorder).  Unlike Reshape, it does not modify the
# children of the nodes it visits.
# Arguments: callback routine, parent, optional 'pre'/'post'/'both',
#            optional additional arguments to be propagated
# Returns: Stop recursion flag
# Callback routine arguments: target DOM, parent, 'pre'/'post',
#                             optional additional arguments
# Callback routine returns: non-zero in 'pre' mode to avoid further recursion.
sub Recurse {
    my($dom, $sub, $parent, $when, @args) = @_;

    $when = 'post' unless defined $when;
    my $stop;
    if ($when =~ /^(pre|both)$/) {
	$stop = eval { &{$sub}($dom, $parent, 'pre', @args) };
	die "Error: $sub: $@" if $@;
    }
    return if $stop;

    my @contents = @{$dom->{content}};
    my $i;
    for ($i=0; $i<@contents; $i++) {
	my $content = $contents[$i];
	$content->Recurse($sub, $dom, $when, @args);
    }

    if ($when ne 'pre') {
	eval { &{$sub}($dom, $parent, 'post', @args) };
	die "Error: $sub: $@" if $@;
    }
}

# INSTANCE METHOD.
# Goes through a DOM object recursively calling a subroutine on every
# element.  It can do either preorder, postorder or bothorder traversal
# (defaults to postorder).
# Arguments: callback routine, parent, optional 'pre'/'post'/'both',
#            optional additional arguments to be propagated
# Returns: Reference to new set of contents for the parent
# Callback routine arguments: target DOM, parent, 'pre'/'post',
#                             optional additional arguments
# Callback routine returns: whatever list of DOM objects are to be 
#                           substituted for the current node (this
#                           list is returned on the 'post' call if
#                           'both' is selected).
sub Reshape {
    my($dom, $sub, $parent, $when, @args) = @_;

    $when = 'post' unless defined $when;
    my @newdom;
    if ($when =~ /^(pre|both)$/) {
	@newdom = eval { &{$sub}($dom, $parent, 'pre', @args) };
	die "Error: $sub: $@" if $@;
    }

    my @contents = @{$dom->{content}};
    my $i;
    my $replace = 0;
    for ($i=0; $i<@contents; $i++) {
	my $content = $contents[$i];
	my @new_contents = grep(defined $_,
				$content->Reshape($sub, $dom, $when, @args));
	splice @{$dom->{content}}, $replace, 1, @new_contents;
	$replace += @new_contents;
    }

    if ($when ne 'pre') {
	@newdom = eval { &{$sub}($dom, $parent, 'post', @args) };
	die "Error: $sub: $@" if $@;
    }

    return @newdom;
}

1;
