# See bottom of file for copyright
package TWiki::Plugins::EditRowPlugin::TableRow;

use strict;

use TWiki::Func;

my $erp = 'erp';

sub new {
    my ($class, $table, $number) = @_;
    my $this = bless({}, $class);
    @{$this->{cols}} = @_;
    $this->{table} = $table;
    $this->{number} = $number;
    $this->{cols} = [];
    return $this;
}

sub stringify {
    my $this = shift;

    return '| '.join(' | ', map { $_->stringify() } @{$this->{cols}}).' |';
}

sub renderForEdit {
    my $this = shift;

    my @out;
    my $col = 0;
    my $ct = $this->{table}->{colTypes};
    foreach (@{$this->{cols}}) {
        push(@out, $_->renderForEdit($ct->[$col++]));
    }
    my $buttons = CGI::input({
        type => 'submit',
        name => 'editrowplugin_save',
        value => $TWiki::Plugins::EditRowPlugin::NOISY_SAVE,
        title => $TWiki::Plugins::EditRowPlugin::NOISY_SAVE,
        style => 'font-size:0;width:18px; height:18px; background-image:url(%PUBURLPATH%/TWiki/TWikiDocGraphics/save.gif)',
       }, '');
    my $attrs = $this->{table}->{attrs};
    if (TWiki::isTrue($attrs->{quietsave})) {
        $buttons .= CGI::input({
            type => 'submit',
            name => 'editrowplugin_save',
            value => $TWiki::Plugins::EditRowPlugin::QUIET_SAVE,
            title => $TWiki::Plugins::EditRowPlugin::QUIET_SAVE,
            style => 'font-size:0;width:18px; height:18px; background-image:url(%PUBURLPATH%/TWiki/TWikiDocGraphics/quiet.gif)',
        }, '');
    }
    # add save button
    if ($attrs->{changerows}) {
        # add add row button
        $buttons .= CGI::input({
            type => 'submit',
            name => 'editrowplugin_save',
            value => $TWiki::Plugins::EditRowPlugin::ADD_ROW,
            title => $TWiki::Plugins::EditRowPlugin::ADD_ROW,
            style => 'font-size:0;width:18px; height:18px; background-image:url(%PUBURLPATH%/TWiki/TWikiDocGraphics/plus.gif)',
        }, '');
        if ($attrs->{changerows} eq 'on') {
            # add delete row button
            $buttons .= CGI::input({
                type => 'submit',
                name => 'editrowplugin_save',
                value => $TWiki::Plugins::EditRowPlugin::DELETE_ROW,
                title => $TWiki::Plugins::EditRowPlugin::DELETE_ROW,
                style => 'font-size:0;width:18px; height:18px; background-image:url(%PUBURLPATH%/TWiki/TWikiDocGraphics/minus.gif)',
            }, '');
        }
    }
    $buttons .= "<a name='$erp$this->{table}->{number}_$this->{number}'></a>";
    unshift(@out, $buttons);

    return '| ' . join(' | ', @out) . '|';
}

sub renderForDisplay {
    my $this = shift;
    my @out;
    my $attrs = $this->{table}->{attrs};
    if ($this->{number} == 1 &&
          (!defined($attrs->{headerislabel}) ||
             TWiki::isTrue($attrs->{headerislabel}))) {
        @out = map { $_->{text} } @{$this->{cols}};
        unshift(@out, '');
    } else {
        my $col = 0;
        my $ct = $this->{table}->{colTypes};
        foreach (@{$this->{cols}}) {
            push(@out, $_->renderForDisplay($ct->[$col++]));
        }
        my $id = "$this->{table}->{number}_$this->{number}";
        my $url;
        if ($TWiki::Plugins::VERSION < 1.11) {
            $url = TWiki::Func::getScriptUrl(
                $this->{table}->{web}, $this->{table}->{topic}, 'view').
                "?active_table=$this->{table}->{number}".
                ";active_row=$this->{number}#$erp$id";
        } else {
            $url = TWiki::Func::getScriptUrl(
                $this->{table}->{web}, $this->{table}->{topic}, 'view',
                active_table => $this->{table}->{number},
                active_row => $this->{number},
                '#' => "$erp$id");
        }
        unshift(@out,
             "<a href='$url'>".
               CGI::image_button(
                   -name => "${erp}_edit$id",
                   -src => '%PUBURLPATH%/TWiki/TWikiDocGraphics/edittopic.gif').
                     "</a>");
    }
    return '| '.join(' | ', @out). ' |';
}

sub finish {
    my $this = shift;
    $this->{table} = undef;
}

1;
__END__

Author: Crawford Currie http://c-dot.co.uk

Copyright (C) 2007 WindRiver Inc. and TWiki Contributors.
All Rights Reserved. TWiki Contributors are listed in the
AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

Do not remove this copyright notice.

This is an object that represents a single row in a table.

=pod

---++ new(\$table, $rno)
Constructor
   * \$table - pointer to the table
   * $rno - what row number this is (start at 1)

---++ finish()
Must be called to dispose of the object. This method disconnects internal pointers that would
otherwise make a Table and its rows and cells self-referential.

---++ stringify()
Generate a TML representation of the row

---++ renderForEdit() -> $text
Render the row for editing. Standard TML is used to construct the table.

---++ renderForDisplay() -> $text
Render the row for display. Standard TML is used to construct the table.

=cut
