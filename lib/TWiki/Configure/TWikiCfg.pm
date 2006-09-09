#
# TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2006 TWiki Contributors.
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
# As per the GPL, removal of this notice is prohibited.
#
# This is a both parser for configuration declaration files, such as
# TWikiCfg.spec, and a serialisation visitor for writing out changes
# to LocalSite.cfg
#
# The supported syntax in declaration files is as follows:
#
# cfg ::= ( setting | section | extension )* ;
# setting ::= BOL typespec EOL comment* BOL def ;
# typespec ::= "# **" id options "**" ;
# def ::= "$" ["TWiki::"] "cfg" keys "=" value ";" ;
# keys ::= ( "{" id "}" )+ ;
# value is any perl value not including ";"
# comment ::= BOL "#" string EOL ;
# section ::= BOL "#--++" string EOL comment* ;
# extension ::= BOL " *" id "*"
# EOL ::= end of line
# BOL ::= beginning of line
# id ::= a \w+ word (legal Perl bareword)
#
# * A *section* is simply a divider used to create foldable blocks. It can
#   have varying depth depending on the number of + signs
# * A *setting* is the sugar required for the setting of a single
#   configuration value.
# * An *extension* is a pluggable UI extension that supports some extra UI
#   functionality, such as the menu of languages or the menu of plugins.
#
# Each *setting* has a *typespec* and a *def*.
#
# The typespec consists of a type id and some options. Types are loaded by
# type id from the TWiki::Configure::Types hierachy - for example, type
# BOOLEAN is defined by TWiki::Configure::Types::BOOLEAN. Each type is a
# subclass of TWiki::Configure::Type - see that class for more details of
# what is supported.
#
# A *def* is a specification of a field in the $TWiki::cfg hash, together with
# a perl value for that hash. Each field can have an associated *Checker*
# which is loaded from the TWiki::Configure::Checkers hierarchy. Checkers
# are responsible for specific checks on the value of that variable. For
# example, the checker for $TWiki::cfg{Banana}{Republic} will be expected
# to be found in TWiki::Configure::Checkers::Banana::Republic.
# Checkers are subclasses of TWiki::Configure::Checker. See that class for
# more details.
#
# An *extension* is a placeholder for a pluggable UI module.
#
package TWiki::Configure::TWikiCfg;

use strict;
use Data::Dumper;
use FileHandle;

use TWiki::Configure::Section;
use TWiki::Configure::Checker;
use TWiki::Configure::Value;
use TWiki::Configure::Pluggable;
use TWiki::Configure::Item;

# Used in saving, when we need a callback. Otherwise the methods here are
# all static.
sub new {
    my $class = shift;

    return bless({}, $class);
}

# Load the configuration declarations. The core set is defined in
# TWiki.spec, which must be found on the @INC path and is always loaded
# first. Other .spec files are read after this.
sub load {
    my $root = shift;
    my %read;

    my $file = TWiki::findFileOnPath('TWiki.spec');
    if ($file) {
        _parse($file, $root);
        $read{'TWiki.spec'} = $file;
    }
    foreach my $dir (@INC) {
        opendir(D, $dir) || next;
        foreach $file (grep { /\.spec$/ } readdir D) {
            # Only read the first occurrence of each .spec file
            next if $read{$file};
            _parse("$dir/$file", $root);
            $read{$file} = "$dir/$file";
        }
    }
}

###########################################################################
## INPUT
###########################################################################
{
    # Inner class that represents section headings temporarily during the
    # parse. They are expanded to section blocks at the end.
    package SectionMarker;

    use base 'TWiki::Configure::Item';

    sub new {
        my ($class, $depth, $head) = @_;
        my $this = bless({}, $class);
        $this->{depth} = $depth + 1;
        $this->{head} = $head;
        return $this;
    }

    sub getValueObject { return undef; }
}

# Process the config array and add section objects
sub _extractSections {
    my ($settings, $root) = @_;

    my $section = $root;
    my $depth = 0;

    foreach my $item (@$settings) {
        if ($item->isa('SectionMarker')) {
            my $ns = $root->getSectionObject($item->{head}, $item->{depth}+1);
            if ($ns) {
                $depth = $item->{depth};
            } else {
                while ($depth > $item->{depth} - 1) {
                    $section = $section->{parent};
                    $depth--;
                }
                while ($depth < $item->{depth} - 1) {
                    my $ns = new TWiki::Configure::Section('');
                    $section->addChild($ns);
                    $section = $ns;
                    $depth++;
                }
                $ns = new TWiki::Configure::Section($item->{head});
                $ns->{desc} = $item->{desc};
                $section->addChild($ns);
                $depth++;
            }
            $section = $ns;
        } elsif ($item->isa('TWiki::Configure::Value')) {
            # Skip it if we already have a settings object for these
            # keys (first loaded always takes precedence, irrespective
            # of which section it is in)
            my $vo = $root->getValueObject($item->getKeys());
            next if ($vo);
            $section->addChild($item);
        } else {
            $section->addChild($item);
        }
    }
}

# See if we have already build a value object for these keys
sub _getValueObject {
    my ($keys, $settings) = @_;
    foreach my $item (@$settings) {
        my $i = $item->getValueObject($keys);
        return $i if $i;
    }
    return undef;
}

# Parse the config declaration file and return a root node for the
# configuration it describes
sub _parse {
    my ($file, $root) = @_;

    open(F, "<$file") || return '';
    local $/ = "\n";
    my $open = undef;
    my @settings;

    foreach my $l (<F>) {
        if( $l =~ /^#\s*\*\*\s*([A-Z]+)\s*(.*?)\s*\*\*\s*$/ ) {
            pusht(\@settings, $open) if $open;
            $open = new TWiki::Configure::Value(typename=>$1, opts=>$2);
        } elsif ($l =~ /^#?\s*\$(TWiki::)?cfg([^=\s]*)\s*=/) {
            my $keys = $2;
            if ($open && $open->isa('SectionMarker')) {
                pusht(\@settings, $open);
                $open = undef;
            }
            # If there is already a UI object for
            # these keys, we don't need to add another. But if there
            # isn't, we do.
            if (!$open) {
                next if $root->getValueObject($keys);
                next if (_getValueObject($keys, \@settings));
                # This is an untyped value
                $open = new TWiki::Configure::Value();
            }
            $open->set(keys => $keys);
            pusht(\@settings, $open);
            $open = undef;
        } elsif( $l =~ /^#\s*\*([A-Z]+)\*/ ) {
            my $pluggable = $1;
            my $p = TWiki::Configure::Pluggable::load($pluggable);
            if ($p) {
                pusht(\@settings, $open) if $open;
                $open = $p;
            } elsif ($open) {
                $l =~ s/^#\s?//;
                $open->addToDesc($l);
            }
        } elsif( $l =~ /^#\s*---\+(\+*) *(.*?)$/ ) {
            pusht(\@settings, $open) if $open;
            $open = new SectionMarker(length($1), $2);
        } elsif( $l =~ /^#\s?(.*)$/ ) {
            $open->addToDesc($1) if $open;
        }
    }
    close(F);
    pusht(\@settings, $open) if $open;
    _extractSections(\@settings, $root);
}

sub pusht {
    my ($a, $n) = @_;
    foreach my $v (@$a) {
        Carp::confess "$n" if $v eq $n;
    }
    push(@$a,$n);
}

###########################################################################
## OUTPUT
###########################################################################

# Generate .cfg file format output
sub save {
    my ($ui, $root, $valuer, $logger) = @_;

    # Object used to act as a visitor to hold the output
    my $this = new TWiki::Configure::TWikiCfg();
    $this->{logger} = $logger;
    $this->{valuer} = $valuer;

    my $lsc = TWiki::findFileOnPath('LocalSite.cfg');
    unless ($lsc) {
        # If not found on the path, park it beside TWiki.cfg
        $lsc = TWiki::findFileOnPath('TWiki.cfg') || '';
        $lsc =~ s/TWiki\.cfg/LocalSite.cfg/;
    }

    if (open(F, '<'.$lsc)) {
        local $/ = undef;
        $this->{content} = <F>;
        close(F);
    } else {
        $this->{content} = <<'HERE';
# Local site settings for TWiki. This file is managed by the 'configure'
# CGI script, though you can also make (careful!) manual changes with a
# text editor.
HERE
    }
    $this->{content} =~ s/\s*1;\s*$//sg;

    $root->visit($this);

    $this->{content} .= "1;\n";

    open(F, '>'.$lsc) ||
      return $this->ERROR("Could not open $lsc for write: $!");
    print F $this->{content};
    close(F);
}

# Visitor method called by node traversal during save. Incrementally modify
# values, unless a value is reverting to the default in which case remove it.
sub startVisit {
    my ($this, $visitee) = @_;

    if ($visitee->isa('TWiki::Configure::Value')) {
        my $keys = $visitee->getKeys();
        my $warble = $this->{valuer}->currentValue($visitee);
        next unless defined $warble;
        my $txt = Data::Dumper->Dump([$warble],
                                     ['$TWiki::cfg'.$keys]);
        if ($this->{logger}) {
            $this->{logger}->logChange($visitee->getKeys(), $txt);
        }
        # Substitute any existing value, or append if not there
        unless ($this->{content} =~ s/\$(TWiki::)?cfg$keys\s*=.*?;\n/$txt/s) {
            $this->{content} .= $txt."\n";
        }
    }
    return 1;
}

sub endVisit {
    my ($this, $visitee) = @_;

    return 1;
}

1;
