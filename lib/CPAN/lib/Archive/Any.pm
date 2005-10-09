package Archive::Any;

use strict;
use vars qw($VERSION @ISA);

$VERSION = 0.06;

require Class::Virtually::Abstract;
@ISA = qw(Class::Virtually::Abstract);

__PACKAGE__->virtual_methods(qw(files extract type));


use File::Spec::Functions qw(rel2abs splitpath splitdir);


=head1 NAME

Archive::Any - Single interface to deal with zips and tarballs

=head1 SYNOPSIS

  use Archive::Any;

  my $archive = Archive::Any->new($archive_file);

  my @files = $archive->files;

  $archive->extract;

  my $type = $archive->type;

  $archive->is_impolite;
  $archive->is_naughty;

=head1 DESCRIPTION

This module is a single interface for manipulating different archive
formats.  Tarballs, zip files, etc...

Currently only tar (with or without gzip) and zip are supported.

Currently only supports unpacking.

=over 4

=item B<new>

  my $archive = Archive::Any->new($archive_file);
  my $archive = Archive::Any->new($archive_file, $type);

Creates an Archive::Any object representing $file, but don't do anything
with it yet.

$type is optional.  It lets you force the file type in-case
Archive::Any can't figure it out.  'tar' or 'zip' is currently
accepted.

=cut

my %Type2Class = ( tar => 'Archive::Any::Tar',
                   zip => 'Archive::Any::Zip'
                 );

sub new {
    my($proto, $file, $type) = @_;

    unless( defined $type ) {
        # Needs to be replaced with some sort of File::Type
        if( $file =~ /\.(?:tar.gz|tgz|tar)$/i ) {
            $type = 'tar';
        }
        elsif( $file =~ /\.zip$/i ) {
            $type = 'zip';
        }
        else {
            warn "Archive::Any can't figure out what type '$file' is.\n";
            return;
        }
    }

    my $class = $Type2Class{$type};
    unless( $class ) {
        warn "Archive::Any can't handle $type.\n";
        return;
    }

    $file = rel2abs( $file );

    eval qq{require $class} or die $@;
    my $self = $class->new($file);

    return $self;
}

=item B<files>

  my @file = $archive->files;

A list of files in the archive.

=item B<extract>

  $archive->extract;
  $archive->extract($director);

Extracts the files in the archive to the given $directory.  If no
$directory is given, it will go into the current working directory.

=item B<type>

  my $type = $archive->type;

Returns the type of archive this is.  Currently 'zip' or 'tar'.

=item B<is_impolite>

  my $is_impolite = $archive->is_impolite;

Checks to see if this archive is going to unpack into the current
directory rather than create it's own.

=cut

sub is_impolite {
    my($self) = shift;

    my @files = $self->files;
    my $first_file = $files[0];
    my($first_dir) = splitdir($first_file);

    return grep(!/^\Q$first_dir\E/, @files) ? 1 : 0;
}

=item B<is_naughty>

  my $is_naughty = $archive->is_naughty;

Checks to see if this archive is going to unpack B<outside> the
current directory.

=cut

sub is_naughty {
    my($self) = shift;

    return (grep { m{^(?:/|(?:\./)*\.\./)} } $self->files) ? 1 : 0;
}

=back


=head1 AUTHOR

Michael G Schwern E<lt>schwern@pobox.comE<gt>

=cut

1;
