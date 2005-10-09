package Archive::Any::Tar;

use strict;
use vars qw($VERSION @ISA);
$VERSION = 0.02;

require Archive::Any;
@ISA = qw(Archive::Any);


use Archive::Tar;
use Cwd;


=head1 NAME

Archive::Any::Tar - Archive::Any wrapper around Archive::Tar

=head1 SYNOPSIS

B<DO NOT USE THIS MODULE DIRECTLY>

Use Archive::Any instead.

=head1 DESCRIPTION

Wrapper around Archive::Tar for Archive::Any.

=cut

sub new {
    my($class, $file) = @_;

    my $self = bless {}, $class;

    $self->{handler} = Archive::Tar->new($file);
    return unless $self->{handler};

    $self->{file}    = $file;

    return $self;
}


sub files {
    my($self) = shift;

    $self->{handler}->list_files;
}


sub extract {
    my($self, $dir) = @_;

    my $orig_dir;
    if( $dir ) {
        $orig_dir = getcwd;
        chdir $dir;
    }

    my $success = $self->{handler}->extract;

    if( $dir) {
        chdir $orig_dir;
    }

    return $success;
}


sub type {
    return 'tar';
}


=head1 AUTHOR

Michael G Schwern E<lt>schwern@pobox.comE<gt>

=head1 SEE ALSO

Archive::Any, Archive::Tar

=cut

1;
