use strict;
package TestPlugin;
use base 'TWiki::Plugins::IncludeXMLPlugin::Handler';

sub new {
    my $class = shift;

    if (@_ % 2 == 1) {
        unshift @_, '_DEFAULT';
    }

    my %params = @_;
    my $session = TestPlugin::TWikiMock->new;

    my $plugin = $class->SUPER::new($session, \%params, 'TestTopic', 'TestWeb');
    return bless $plugin, $class;
}

sub _getHTTP {
    my ($self, $url, $request, $isSoap) = @_;
    $url =~ s{^http://localhost(?=/|$)}{};

    if ($url =~ m{^/}) {
        return \$self->{session}->readTestFile($url);
    } else {
        return $self->SUPER::_getHTTP($url, $request, $isSoap);
    }
}

sub getTestFile {
    my ($self, $path) = @_;
    return $self->{session}->getTestFile($path);
}

sub readTestFile {
    my ($self, $path) = @_;
    return $self->{session}->readTestFile($path);
}

package TestPlugin::TWikiMock;
use FindBin;

my $htdocs = "$FindBin::RealBin/../t/htdocs";

sub new {
    bless {}, shift;
}

sub _INCLUDE {
    my ($self, $params, $theTopic, $theWeb) = @_;
    my $source = $params->{_DEFAULT};
    die "Nothing to include" unless $source;

    $source =~ s{^http://localhost(?=/|$)}{};

    if ($source =~ m{^https?://}) {
        return $self->SUPER::_INCLUDE(@_);
    } else {
        my $request = $params->{request};
        # TODO: use $request for POST

        if ($source !~ m{^/}) {
            $source =~ s{\.}{/}g;
            $source = "/data/$source.txt";
        }

        return _readFile($htdocs.$source);
    }
}

sub getTestFile {
    my ($self, $path) = @_;
    return "$htdocs/$path";
}

sub readTestFile {
    my ($self, $path) = @_;
    $path = "/$path" if $path !~ m{^/};
    return _readFile($htdocs.$path);
}

sub _readFile {
    my ($file) = @_;
    open(my $in, $file) or die "$file: $!";
    local $/;
    my $cont = <$in>;
    close $in;
    return $cont;
}

1;
