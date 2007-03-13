package TWiki::Plugins::EditRowPlugin::TableRow;

use strict;

use TWiki::Func;

my $defCol ||= { type => 'text', size => 20, values => [] };
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
        push(@out, $_->renderForEdit($ct->[$col++] || $defCol));
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
            push(@out, $_->renderForDisplay($ct->[$col++] || $defCol));
        }
        my $id = "$this->{table}->{number}_$this->{number}";
        my $url = TWiki::Func::getScriptUrl(
            $this->{table}->{web}, $this->{table}->{topic}, 'view',
            active_table => $this->{table}->{number},
            active_row => $this->{number},
            '#' => "$erp$id");
        unshift(@out,
             "<a href='$url'>".
               CGI::image_button(
                   -name => '$erp_edit$id',
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
