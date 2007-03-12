package TWiki::Plugins::EditRowPlugin::TableCell;

use strict;

use TWiki::Func;

sub new {
    my ($class, $row, $text, $number) = @_;
    my $this = bless({}, $class);
    $this->{row} = $row;
    $this->{number} = $number;
    $text =~ s/^\s*//;
    $text =~ s/\s*$//;
    $this->{text} = $text;
    return $this;
}

sub finish {
    my $this = shift;
    $this->{row} = undef;
}

sub stringify {
    my $this = shift;

    return $this->{text};
}

sub renderForDisplay {
    my ($this, $colDef) = @_;

    if ($colDef->{type} eq 'row') {
        my $attrs = $this->{row}->{table}->{attrs};
        if ($this->{number} == 1 &&
              (!defined($attrs->{headerislabel}) ||
                 TWiki::isTrue($attrs->{headerislabel}))) {
            return $this->{row}->{number} - 1;
        } else {
            return $this->{row}->{number};
        }
    }
    return $this->{text};
}

sub renderForEdit {
    my ($this, $colDef) = @_;

    my $expandedValue = TWiki::Func::expandCommonVariables(
        $this->{text} || '');
    $expandedValue =~ s/^\s*(.*?)\s*$/$1/;

    my $text = '';
    my $cellName = 'cell_'.$this->{row}->{table}->{number}.'_'.
      $this->{row}->{number}.'_'.$this->{number};

    if( $colDef->{type} eq 'select' ) {

        $text = "<select name='$cellName' size='$colDef->{size}'>";
        foreach my $option ( @{$colDef->{values}} ) {
            my $expandedOption =
              TWiki::Func::expandCommonVariables($option);
            $expandedOption =~ s/^\s*(.*?)\s*$/$1/;
            my %opts;
            if ($expandedOption eq $expandedValue) {
                $opts{selected} = 'selected';
            }
            $text .= CGI::option(\%opts, $option);
        }
        $text .= "</select>";

    } elsif( $colDef->{type} =~ /^(radio|checkbox)$/ ) {

        $expandedValue = ",$expandedValue,";
        my $i = 0;
        foreach my $option ( @{$colDef->{values}} ) {
            my $expandedOption =
              TWiki::Func::expandCommonVariables($option);
            $expandedOption =~ s/^\s*(.*?)\s*$/$1/;
            $expandedOption =~ s/(\W)/\\$1/g;
            my %opts = (
                type => $colDef->{type},
                name => $cellName,
                value => $this->{text},
               );
            $opts{checked} = 'checked'
              if ($expandedValue =~ /,$expandedOption,/);
            $text .= CGI::input(\%opts);
            $text .= " $option ";
            if( $colDef->{size} > 1 ) {
                if ($i % $colDef->{size}) {
                    $text .= '<br />';
                }
            }
            $i++;
        }

    } elsif( $colDef->{type} eq 'row' ) {

        my $attrs = $this->{row}->{table}->{attrs};
        if ($this->{number} == 1 &&
              (!defined($attrs->{headerislabel}) ||
                 TWiki::isTrue($attrs->{headerislabel}))) {
            $text = $this->{row}->{number} - 1;
        } else {
            $text = $this->{row}->{number};
        }

    } elsif( $colDef->{type} eq 'textarea' ) {

        my ($rows, $cols) = split( /x/, $colDef->{size} );
        $rows = 3 if $rows < 1;
        $cols = 30 if $cols < 1;

        $text .= CGI::textarea({
            rows => $rows,
            cols => $cols,
            name => $cellName }, $this->{text});

    } elsif( $colDef->{type} eq 'date' ) {

        require TWiki::Contrib::JSCalendarContrib;
        unless( $@ ) {
            TWiki::Contrib::JSCalendarContrib::addHEAD( 'twiki' );
        }

        my $ifFormat = $colDef->{values}->[0] ||
          $TWiki::cfg{JSCalendarContrib}{format} || '%e %B %Y';

        $text .= CGI::textfield({
            name => $cellName,
            id => 'id'.$cellName,
            size=> $colDef->{size},
            value => $this->{text} });

        eval 'use TWiki::Contrib::JSCalendarContrib';
        unless ( $@ ) {
            $text .= CGI::image_button(
                -name => 'calendar',
                -onclick =>
                  "return showCalendar('id$cellName','$ifFormat')",
                -src=> TWiki::Func::getPubUrlPath() . '/' .
                  TWiki::Func::getTwikiWebname() .
                      '/JSCalendarContrib/img.gif',
                -alt => 'Calendar',
                -align => 'MIDDLE' );
        }

    } else { #  if( $colDef->{type} =~ /^(text|label)$/)

        $text = CGI::textfield({
            name => $cellName,
            size => $colDef->{size},
            value => $this->{text} });

    }
    return $text;
}

1;
