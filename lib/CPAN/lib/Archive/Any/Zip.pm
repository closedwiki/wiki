package Archive::Any::Zip;

use strict;
use vars qw($VERSION @ISA);
$VERSION = 0.03;

require Archive::Any;
@ISA = qw(Archive::Any);


use Archive::Zip qw(:ERROR_CODES);
use Cwd;


=head1 NAME

Archive::Any::Zip - Archive::Any wrapper around Archive::Zip

=head1 SYNOPSIS

B<DO NOT USE THIS MODULE DIRECTLY>

Use Archive::Any instead.

=head1 DESCRIPTION

Wrapper around Archive::Zip for Archive::Any.

=cut

sub new {
    my($class, $file) = @_;

    my $self = bless {}, $class;

    Archive::Zip::setErrorHandler(sub {});
    $self->{handler} = Archive::Zip->new($file);
    return unless $self->{handler};

    $self->{file}    = $file;

    return $self;
}


sub files {
    my($self) = shift;

    $self->{handler}->memberNames;
}


sub extract {
    my($self, $dir) = @_;

    my $orig_dir;
    if( $dir ) {
        $orig_dir = getcwd;
        chdir $dir;
    }

    $self->{handler}->extractTree;

    if( $dir) {
        chdir $orig_dir;
    }

    return 1;
}


sub type {
    return 'zip';
}


=head1 AUTHOR

Michael G Schwern E<lt>schwern@pobox.comE<gt>

=head1 SEE ALSO

Archive::Any, Archive::Zip

=cut

1;
