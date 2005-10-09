package WWW::Mechanize;

=head1 NAME

WWW::Mechanize - Handy web browsing in a Perl object

=head1 VERSION

Version 1.14

=cut

our $VERSION = "1.14";

=head1 SYNOPSIS

C<WWW::Mechanize>, or Mech for short, helps you automate interaction with
a website. It supports performing a sequence of page fetches including
following links and submitting forms. Each fetched page is parsed and
its links and forms are extracted. A link or a form can be selected, form
fields can be filled and the next page can be fetched. Mech also stores
a history of the URLs you've visited, which can be queried and revisited.

    use WWW::Mechanize;
    my $mech = WWW::Mechanize->new();

    $mech->get( $url );

    $mech->follow_link( n => 3 );
    $mech->follow_link( text_regex => qr/download this/i );
    $mech->follow_link( url => 'http://host.com/index.html' );

    $mech->submit_form(
        form_number => 3,
        fields      => {
            username    => 'mungo',
            password    => 'lost-and-alone',
        }
    );

    $mech->submit_form(
        form_name => 'search',
        fields    => { query  => 'pot of gold', },
        button    => 'Search Now'
    );


Mech is well suited for use in testing web applications.  If you use
one of the Test::*, like L<Test::HTML::Lint> modules, you can check the
fetched content and use that as input to a test call.

    use Test::More;
    like( $mech->content(), qr/$expected/, "Got expected content" );

Each page fetch stores its URL in a history stack which you can
traverse.

    $mech->back();

If you want finer control over over your page fetching, you can use
these methods. C<follow_link> and C<submit_form> are just high
level wrappers around them.

    $mech->follow( $link );
    $mech->find_link( n => $number );
    $mech->form_number( $number );
    $mech->form_name( $name );
    $mech->field( $name, $value );
    $mech->set_fields( %field_values );
    $mech->set_visible( @criteria );
    $mech->click( $button );

L<WWW::Mechanize> is a proper subclass of L<LWP::UserAgent> and
you can also use any of L<LWP::UserAgent>'s methods.

    $mech->add_header($name => $value);

Please note that Mech does NOT support JavaScript.  Please check the
FAQ in WWW::Mechanize::FAQ for more.

=head1 IMPORTANT LINKS

=over 4

=item * L<http://search.cpan.org/dist/WWW-Mechanize/>

The CPAN documentation page for Mechanize.

=item * L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=WWW-Mechanize>

The RT queue for bugs & enhancements in Mechanize.  Click the "Report bug"
link if your bug isn't already reported.

=back

=cut

use strict;
use warnings;

use HTTP::Request 1.30;
use LWP::UserAgent 2.003;
use HTML::Form 1.00;
use HTML::TokeParser;
use URI::URL;
use UNIVERSAL qw( isa );

use base 'LWP::UserAgent';

=head1 CONSTRUCTOR AND STARTUP

=head2 new()

Creates and returns a new WWW::Mechanize object, hereafter referred to as
the 'agent'.

    my $mech = WWW::Mechanize->new()

The constructor for WWW::Mechanize overrides two of the parms to the
LWP::UserAgent constructor:

    agent => "WWW-Mechanize/#.##"
    cookie_jar => {}    # an empty, memory-only HTTP::Cookies object

You can override these overrides by passing parms to the constructor,
as in:

    my $mech = WWW::Mechanize->new( agent=>"wonderbot 1.01" );

If you want none of the overhead of a cookie jar, or don't want your
bot accepting cookies, you have to explicitly disallow it, like so:

    my $mech = WWW::Mechanize->new( cookie_jar => undef );

Here are the parms that WWW::Mechanize recognizes.  These do not include
parms that L<LWP::UserAgent> recognizes.

=over 4

=item * C<< autocheck => [0|1] >>

Checks each request made to see if it was successful.  This saves you
the trouble of manually checking yourself.  Any errors found are errors,
not warnings.  Default is off.

=item * C<< onwarn => \&func() >>

Reference to a C<warn>-compatible function, such as C<< L<Carp>::carp >>,
that is called when a warning needs to be shown.

If this is set to C<undef>, no warnings will ever be shown.  However,
it's probably better to use the C<quiet> method to control that behavior.

If this value is not passed, Mech uses C<Carp::carp> if L<Carp> is
installed, or C<CORE::warn> if not.

=item * C<< onerror => \&func() >>

Reference to a C<die>-compatible function, such as C<< L<Carp>::croak >>,
that is called when there's a fatal error.

If this is set to C<undef>, no errors will ever be shown.

If this value is not passed, Mech uses C<Carp::croak> if L<Carp> is
installed, or C<CORE::die> if not.

=item * C<< quiet => [0|1] >>

Don't complain on warnings.  Setting C<< quiet => 1 >> is the same as
calling C<< $agent->quiet(1) >>.  Default is off.

=item * C<< stack_depth => $value >>

Sets the depth of the page stack that keeps tracks of all the downloaded
pages. Default is 0 (infinite). If the stack is eating up your memory,
then set it to 1.

=back

=cut

sub new {
    my $class = shift;

    my %parent_parms = (
        agent       => "WWW-Mechanize/$VERSION",
        cookie_jar  => {},
    );

    my %mech_parms = (
        autocheck   => 0,
        onwarn      => \&WWW::Mechanize::_warn,
        onerror     => \&WWW::Mechanize::_die,
        quiet       => 0,
        stack_depth => 0,
        headers     => {},
    );

    my %passed_parms = @_;

    # Keep the mech-specific parms before creating the object.
    while ( my($key,$value) = each %passed_parms ) {
        if ( exists $mech_parms{$key} ) {
            $mech_parms{$key} = $value;
        }
        else {
            $parent_parms{$key} = $value;
        }
    }

    my $self = $class->SUPER::new( %parent_parms );
    bless $self, $class;

    # Use the mech parms now that we have a mech object.
    for my $parm ( keys %mech_parms ) {
        $self->{$parm} = $mech_parms{$parm};
    }
    $self->{page_stack} = [];
    $self->env_proxy();

    # libwww-perl 5.800 (and before, I assume) has a problem where
    # $ua->{proxy} can be undef and clone() doesn't handle it.
    $self->{proxy} = {} unless defined $self->{proxy};
    push( @{$self->requests_redirectable}, 'POST' );

    $self->_reset_page;

    return $self;
}

=head2 $mech->agent_alias( $alias )

Sets the user agent string to the expanded version from a table of actual user strings.
I<$alias> can be one of the following:

=over 4

=item * Windows IE 6

=item * Windows Mozilla

=item * Mac Safari

=item * Mac Mozilla

=item * Linux Mozilla

=item * Linux Konqueror

=back

then it will be replaced with a more interesting one.  For instance,

    $mech->agent_alias( 'Windows IE 6' );

sets your User-Agent to

    Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1)

The list of valid aliases can be returned from C<known_agent_aliases()>.

=cut

my %known_agents = (
    'Windows IE 6'      => 'Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1)',
    'Windows Mozilla'   => 'Mozilla/5.0 (Windows; U; Windows NT 5.0; en-US; rv:1.4b) Gecko/20030516 Mozilla Firebird/0.6',
    'Mac Safari'        => 'Mozilla/5.0 (Macintosh; U; PPC Mac OS X; en-us) AppleWebKit/85 (KHTML, like Gecko) Safari/85',
    'Mac Mozilla'       => 'Mozilla/5.0 (Macintosh; U; PPC Mac OS X Mach-O; en-US; rv:1.4a) Gecko/20030401',
    'Linux Mozilla'     => 'Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.4) Gecko/20030624',
    'Linux Konqueror'   => 'Mozilla/5.0 (compatible; Konqueror/3; Linux)',
);

sub agent_alias {
    my $self = shift;
    my $alias = shift;

    if ( defined $known_agents{$alias} ) {
        return $self->agent( $known_agents{$alias} );
    }
    else {
        $self->warn( qq{Unknown agent alias "$alias"} );
        return $self->agent();
    }
}

=head2 known_agent_aliases()

Returns a list of all the agent aliases that Mech knows about.

=cut

sub known_agent_aliases {
    return sort keys %known_agents;
}

=head1 PAGE-FETCHING METHODS

=head2 $mech->get( $url )

Given a URL/URI, fetches it.  Returns an L<HTTP::Response> object.
I<$url> can be a well-formed URL string, a L<URI> object, or a
L<WWW::Mechanize::Link> object.

The results are stored internally in the agent object, but you don't
know that.  Just use the accessors listed below.  Poking at the internals
is deprecated and subject to change in the future.

C<get()> is a well-behaved overloaded version of the method in
L<LWP::UserAgent>.  This lets you do things like

    $mech->get( $url, ":content_file"=>$tempfile );

and you can rest assured that the parms will get filtered down
appropriately.

=cut

sub get {
    my $self = shift;
    my $uri = shift;

    $uri = $uri->url if ref($uri) eq 'WWW::Mechanize::Link';

    $uri = $self->base
            ? URI->new_abs( $uri, $self->base )
            : URI->new( $uri );

    return $self->SUPER::get( $uri->as_string, @_ );
}

=head2 $mech->reload()

Acts like the reload button in a browser: repeats the current
request. The history (as per the L<back> method) is not altered.

Returns the L<HTTP::Response> object from the reload, or C<undef>
if there's no current request.

=cut

sub reload {
    my $self = shift;

    return unless my $req = $self->{req};

    $self->_update_page( $req, $self->_make_request( $req, @_ ) );
}

=head2 $mech->back()

The equivalent of hitting the "back" button in a browser.  Returns to
the previous page.  Won't go back past the first page. (Really, what
would it do if it could?)

=cut

sub back {
    my $self = shift;
    $self->_pop_page_stack;
}

=head1 STATUS METHODS

=head2 $mech->success()

Returns a boolean telling whether the last request was successful.
If there hasn't been an operation yet, returns false.

This is a convenience function that wraps C<< $mech->res->is_success >>.

=cut

sub success {
    my $self = shift;

    return $self->res && $self->res->is_success;
}


=head2 $mech->uri()

Returns the current URI.

=head2 $mech->response() / $mech->res()

Return the current response as an L<HTTP::Response> object.

Synonym for C<< $mech->response() >>

=head2 $mech->status()

Returns the HTTP status code of the response.

=head2 $mech->ct()

Returns the content type of the response.

=head2 $mech->base()

Returns the base URI for the current response

=head2 $mech->forms()

When called in a list context, returns a list of the forms found in
the last fetched page. In a scalar context, returns a reference to
an array with those forms. The forms returned are all L<HTML::Form>
objects.

=head2 $mech->current_form()

Returns the current form as an L<HTML::Form> object.  I'd call this
C<form()> except that C<L<form()>> already exists and sets the current_form.

=head2 $mech->links()

When called in a list context, returns a list of the links found in the
last fetched page.  In a scalar context it returns a reference to an array
with those links.  Each link is a L<WWW::Mechanize::Link> object.

=head2 $mech->is_html()

Returns true/false on whether our content is HTML, according to the
HTTP headers.

=cut

sub uri {           my $self = shift; return $self->{uri}; }
sub res {           my $self = shift; return $self->{res}; }
sub response {      my $self = shift; return $self->{res}; }
sub status {        my $self = shift; return $self->{status}; }
sub ct {            my $self = shift; return $self->{ct}; }
sub base {          my $self = shift; return $self->{base}; }
sub current_form {  my $self = shift; return $self->{form}; }
sub is_html {       my $self = shift; return defined $self->{ct} && ($self->{ct} eq "text/html"); }

=head2 $mech->title()

Returns the contents of the C<< <TITLE> >> tag, as parsed by
L<HTML::HeadParser>.  Returns undef if the content is not HTML.

=cut

sub title {
    my $self = shift;
    return unless $self->is_html;

    require HTML::HeadParser;
    my $p = HTML::HeadParser->new;
    $p->parse($self->content);
    return $p->header('Title');
}

=head1 CONTENT-HANDLING METHODS

=head2 $mech->content(...)

Returns the content that the mech uses internally for the last page
fetched. Ordinarily this is the same as $mech->response()->content(),
but this may differ for HTML documents if L</update_html> is
overloaded (in which case the value passed to the base-class
implementation of same will be returned), and/or extra named arguments
are passed to I<content()>:

=over 2

=item I<< $mech->content( format => "text" ) >>

Returns a text-only version of the page, with all HTML markup
stripped. This feature requires I<HTML::TreeBuilder> to be installed,
or a fatal error will be thrown.

=item I<< $mech->content( base_href => [$base_href|undef] ) >>

Returns the HTML document, modified to contain a
C<< <base href="$base_href"> >> mark-up in the header.
I<$base_href> is C<< $mech->base() >> if not specified. This is
handy to pass the HTML to e.g. L<HTML::Display>.

=back

Passing arguments to C<content()> if the current document is not
HTML has no effect now (i.e. the return value is the same as
C<< $self->response()->content() >>. This may change in the future,
but will likely be backwards-compatible when it does.

=cut

sub content {
    my $self = shift;
    my $content = $self->{content};
    return $content unless $self->is_html;

    while ( my ($cmd, $arg) = splice(@_, 0, 2) ) {
        if ($cmd eq 'format') {
            if ($arg eq 'text') {
                require HTML::TreeBuilder;
                my $tree = HTML::TreeBuilder->new();
                $tree->parse($content);
                $tree->eof();
                $tree->elementify(); # just for safety
                $content = $tree->as_text();
            }
            else {
                $self->die( qq{Unknown format parameter "$arg"} );
            };
        }
        elsif ($cmd eq 'base_href') {
            $arg ||= $self->base;
            $content=~s/<head>/<head>\n<base href="$arg">/;
        }
        else {
            $self->die( qq{Unknown named argument "$cmd"} );
        }
    }

    return $content;
}

=head1 LINK METHODS

=head2 $mech->links

Lists all the links on the current page.  Each link is a
WWW::Mechanize::Link object. In list context, returns a list of all
links.  In scalar context, returns an array reference of all links.

=cut

sub links {
    my $self = shift ;
    return @{$self->{links}} if wantarray;
    return $self->{links};
}

=head2 $mech->follow_link(...)

Follows a specified link on the page.  You specify the match to be
found using the same parms that C<L<find_link()>> uses.

Here some examples:

=over 4

=item * 3rd link called "download"

    $mech->follow_link( text => "download", n => 3 );

=item * first link where the URL has "download" in it, regardless of case:

    $mech->follow_link( url_regex => qr/download/i );

or

    $mech->follow_link( url_regex => qr/(?i:download)/ );

=item * 3rd link on the page

    $mech->follow_link( n => 3 );

=back

Returns the result of the GET method (an HTTP::Response object) if
a link was found. If the page has no links, or the specified link
couldn't be found, returns undef.

This method is meant to replace C<< $mech->follow() >> which should
not be used in future development.

=cut

sub follow_link {
    my $self = shift;
    my %parms = ( n=>1, @_ );

    if ( $parms{n} eq "all" ) {
        delete $parms{n};
        $self->warn( qq{follow_link(n=>"all") is not valid} );
    }

    my $response;
    my $link = $self->find_link(%parms);
    if ( $link ) {
        $response = $self->get( $link->url );
    }

    return $response;
}

=head2 $mech->find_link()

Finds a link in the currently fetched page. It returns a
L<WWW::Mechanize::Link> object which describes the link.  (You'll
probably be most interested in the C<url()> property.)  If it fails
to find a link it returns undef.

You can take the URL part and pass it to the C<get()> method.  If
that's your plan, you might as well use the C<follow_link()> method
directly, since it does the C<get()> for you automatically.

Note that C<< <FRAME SRC="..."> >> tags are parsed out of the the HTML
and treated as links so this method works with them.

You can select which link to find by passing in one or more of these
key/value pairs:

=over 4

=item * C<< text => 'string', >> and C<< text_regex => qr/regex/, >>

C<text> matches the text of the link against I<string>, which must be an
exact match.  To select a link with text that is exactly "download", use

    $mech->find_link( text => "download" );

C<text_regex> matches the text of the link against I<regex>.  To select a
link with text that has "download" anywhere in it, regardless of case, use

    $mech->find_link( text_regex => qr/download/i );

Note that the text extracted from the page's links are trimmed.  For
example, C<< <a> foo </a> >> is stored as 'foo', and searching for
leading or trailing spaces will fail.

=item * C<< url => 'string', >> and C<< url_regex => qr/regex/, >>

Matches the URL of the link against I<string> or I<regex>, as appropriate.
The URL may be a relative URL, like F<foo/bar.html>, depending on how
it's coded on the page.

=item * C<< url_abs => string >> and C<< url_abs_regex => regex >>

Matches the absolute URL of the link against I<string> or I<regex>,
as appropriate.  The URL will be an absolute URL, even if it's relative
in the page.

=item * C<< name => string >> and C<< name_regex => regex >>

Matches the name of the link against I<string> or I<regex>, as appropriate.

=item * C<< tag => string >> and C<< tag_regex => regex >>

Matches the tag that the link came from against I<string> or I<regex>,
as appropriate.  The C<tag_regex> is probably most useful to check for
more than one tag, as in:

    $mech->find_link( tag_regex => qr/^(a|frame)$/ );

The tags and attributes looked at are defined below, at
L<$mech->find_link() : link format>.

=back

If C<n> is not specified, it defaults to 1.  Therefore, if you don't
specify any parms, this method defaults to finding the first link on the
page.

Note that you can specify multiple text or URL parameters, which
will be ANDed together.  For example, to find the first link with
text of "News" and with "cnn.com" in the URL, use:

    $mech->find_link( text => "News", url_regex => qr/cnn\.com/ );

The return value is a reference to an array containing a
L<WWW::Mechanize::Link> object for every link in C<< $self->content >>.

The links come from the following:

=over 4

=item C<< <A HREF=...> >>

=item C<< <AREA HREF=...> >>

=item C<< <FRAME SRC=...> >>

=item C<< <IFRAME SRC=...> >>

=item C<< <META CONTENT=...> >>

=back

=cut

sub find_link {
    my $self = shift;
    my %parms = ( n=>1, @_ );

    my $wantall = ( $parms{n} eq "all" );

    $self->_clean_keys( \%parms, qr/^(n|(text|url|url_abs|name|tag)(_regex)?)$/ );

    my @links = $self->links or return;

    my $nmatches = 0;
    my @matches;
    for my $link ( @links ) {
        if ( _match_any_link_parms($link,\%parms) ) {
            if ( $wantall ) {
                push( @matches, $link );
            }
            else {
                ++$nmatches;
                return $link if $nmatches >= $parms{n};
            }
        }
    } # for @links

    if ( $wantall ) {
        return @matches if wantarray;
        return \@matches;
    }

    return;
} # find_link

# Used by find_links to check for matches
# The logic is such that ALL parm criteria that are given must match
sub _match_any_link_parms {
    my $link = shift;
    my $p = shift;

    # No conditions, anything matches
    return 1 unless keys %$p;

    return if defined $p->{url}           and !($link->url eq $p->{url} );
    return if defined $p->{url_regex}     and !($link->url =~ $p->{url_regex} );
    return if defined $p->{url_abs}       and !($link->url_abs eq $p->{url_abs} );
    return if defined $p->{url_abs_regex} and !($link->url_abs =~ $p->{url_abs_regex} );
    return if defined $p->{text}          and !(defined($link->text) and $link->text eq $p->{text} );
    return if defined $p->{text_regex}    and !(defined($link->text) and $link->text =~ $p->{text_regex} );
    return if defined $p->{name}          and !(defined($link->name) and $link->name eq $p->{name} );
    return if defined $p->{name_regex}    and !(defined($link->name) and $link->name =~ $p->{name_regex} );
    return if defined $p->{tag}           and !($link->tag and $link->tag eq $p->{tag} );
    return if defined $p->{tag_regex}     and !($link->tag and $link->tag =~ $p->{tag_regex} );

    # Success: everything that was defined passed.
    return 1;

}

# Cleans the %parms parameter for the find_link and find_image methods.
sub _clean_keys {
    my $self = shift;
    my $parms = shift;
    my $rx_keyname = shift;

    for my $key ( keys %$parms ) {
        my $val = $parms->{$key};
        if ( $key !~ qr/$rx_keyname/ ) {
            $self->warn( qq{Unknown link-finding parameter "$key"} );
            delete $parms->{$key};
            next;
        }

        my $key_regex = ( $key =~ /_regex$/ );
        my $val_regex = ( ref($val) eq "Regexp" );

        if ( $key_regex ) {
            if ( !$val_regex ) {
                $self->warn( qq{$val passed as $key is not a regex} );
                delete $parms->{$key};
                next;
            }
        }
        else {
            if ( $val_regex ) {
                $self->warn( qq{$val passed as '$key' is a regex} );
                delete $parms->{$key};
                next;
            }
            if ( $val =~ /^\s|\s$/ ) {
                $self->warn( qq{'$val' is space-padded and cannot succeed} );
                delete $parms->{$key};
                next;
            }
        }
    } # for keys %parms
} # _clean_keys()


=head2 $mech->find_all_links( ... )

Returns all the links on the current page that match the criteria.  The
method for specifying link criteria is the same as in C<L<find_link()>>.
Each of the links returned is a L<WWW::Mechanize::Link> object.

In list context, C<find_all_links()> returns a list of the links.
Otherwise, it returns a reference to the list of links.

C<find_all_links()> with no parameters returns all links in the
page.

=cut

sub find_all_links {
    my $self = shift;
    return $self->find_link( @_, n=>'all' );
}


=head1 IMAGE METHODS

=head2 $mech->images

Lists all the images on the current page.  Each image is a
WWW::Mechanize::Image object. In list context, returns a list of all
images.  In scalar context, returns an array reference of all images.

=cut

sub images {
    my $self = shift ;
    return @{$self->{images}} if wantarray;
    return $self->{images};
}

=head2 $mech->find_image()

Finds an image in the current page. It returns a
L<WWW::Mechanize::Image> object which describes the image.  If it fails
to find an image it returns undef.

You can select which link to find by passing in one or more of these
key/value pairs:

=over 4

=item * C<< alt => 'string' >> and C<< alt_regex => qr/regex/, >>

C<alt> matches the ALT attribute of the image against I<string>, which must be an
exact match. To select a image with an ALT tag that is exactly "download", use

    $mech->find_image( alt  => "download" );

C<alt_regex> matches the ALT attribute of the image  against a regular
expression.  To select an image with an ALT attribute that has "download"
anywhere in it, regardless of case, use

    $mech->find_image( alt_regex => qr/download/i );

=item * C<< url => 'string', >> and C<< url_regex => qr/regex/, >>

Matches the URL of the image against I<string> or I<regex>, as appropriate.
The URL may be a relative URL, like F<foo/bar.html>, depending on how
it's coded on the page.

=item * C<< url_abs => string >> and C<< url_abs_regex => regex >>

Matches the absolute URL of the image against I<string> or I<regex>,
as appropriate.  The URL will be an absolute URL, even if it's relative
in the page.

=item * C<< tag => string >> and C<< tag_regex => regex >>

Matches the tag that the image came from against I<string> or I<regex>,
as appropriate.  The C<tag_regex> is probably most useful to check for
more than one tag, as in:

    $mech->find_image( tag_regex => qr/^(img|input)$/ );

The tags supported are C<< <img> >> and C<< <input> >>.

=back

If C<n> is not specified, it defaults to 1.  Therefore, if you don't
specify any parms, this method defaults to finding the first image on the
page.

Note that you can specify multiple ALT or URL parameters, which
will be ANDed together.  For example, to find the first image with
ALT text of "News" and with "cnn.com" in the URL, use:

    $mech->find_image( image => "News", url_regex => qr/cnn\.com/ );

The return value is a reference to an array containing a
L<WWW::Mechanize::Image> object for every image in C<< $self->content >>.

=cut

sub find_image {
    my $self = shift;
    my %parms = ( n=>1, @_ );

    my $wantall = ( $parms{n} eq "all" );

    $self->_clean_keys( \%parms, qr/^(n|(alt|url|url_abs|tag)(_regex)?)$/ );

    my @images = $self->images or return;

    my $nmatches = 0;
    my @matches;
    for my $image ( @images ) {
        if ( _match_any_image_parms($image,\%parms) ) {
            if ( $wantall ) {
                push( @matches, $image );
            }
            else {
                ++$nmatches;
                return $image if $nmatches >= $parms{n};
            }
        }
    } # for @images

    if ( $wantall ) {
        return @matches if wantarray;
        return \@matches;
    }

    return;
}

# Used by find_images to check for matches
# The logic is such that ALL parm criteria that are given must match
sub _match_any_image_parms {
    my $image = shift;
    my $p = shift;

    # No conditions, anything matches
    return 1 unless keys %$p;

    return if defined $p->{url}           and !($image->url eq $p->{url} );
    return if defined $p->{url_regex}     and !($image->url =~ $p->{url_regex} );
    return if defined $p->{url_abs}       and !($image->url_abs eq $p->{url_abs} );
    return if defined $p->{url_abs_regex} and !($image->url_abs =~ $p->{url_abs_regex} );
    return if defined $p->{alt}           and !(defined($image->alt) and $image->alt eq $p->{alt} );
    return if defined $p->{alt_regex}     and !(defined($image->alt) and $image->alt =~ $p->{alt_regex} );
    return if defined $p->{tag}           and !($image->tag and $image->tag eq $p->{tag} );
    return if defined $p->{tag_regex}     and !($image->tag and $image->tag =~ $p->{tag_regex} );

    # Success: everything that was defined passed.
    return 1;
}


=head2 $mech->find_all_images( ... )

Returns all the images on the current page that match the criteria.  The
method for specifying image criteria is the same as in C<L<find_image()>>.
Each of the images returned is a L<WWW::Mechanize::Image> object.

In list context, C<find_all_images()> returns a list of the images.
Otherwise, it returns a reference to the list of images.

C<find_all_images()> with no parameters returns all images in the page.

=cut

sub find_all_images {
    my $self = shift;
    return $self->find_image( @_, n=>'all' );
}

=head1 FORM METHODS

=head2 $mech->forms

Lists all the forms on the current page.  Each form is an HTML::Form
object.  In list context, returns a list of all forms.  In scalar
context, returns an array reference of all forms.

=cut

sub forms {
    my $self = shift ;
    return @{$self->{forms}} if wantarray;
    return $self->{forms};
}


=head2 $mech->form_number($number)

Selects the I<number>th form on the page as the target for subsequent
calls to C<L<field()>> and C<L<click()>>.  Also returns the form that was
selected.  Emits a warning and returns undef if there is no such
form.  Forms are indexed from 1, so the first form is number 1,
not zero.

=cut

sub form_number {
    my ($self, $form) = @_;
    if ($self->{forms}->[$form-1]) {
        $self->{form} = $self->{forms}->[$form-1];
        return $self->{form};
    }
    else {
        $self->warn( "There is no form numbered $form" );
        return;
    }
}

=head2 $mech->form_name($name)

Selects a form by name.  If there is more than one form on the page
with that name, then the first one is used, and a warning is
generated.  Also returns the form itself, or undef if it's not
found.

Note that this functionality requires libwww-perl 5.69 or higher.

=cut

sub form_name {
    my ($self, $form) = @_;

    my $temp;
    my @matches = grep {defined($temp = $_->attr('name')) and ($temp eq $form) } $self->forms;
    if ( @matches ) {
        $self->warn( "There are ", scalar @matches, " forms named $form.  The first one was used." )
            if @matches > 1;
        return $self->{form} = $matches[0];
    }
    else {
        $self->warn( qq{ There is no form named "$form"} );
        return undef;
    }
}


=head2 $mech->field( $name, $value, $number )

=head2 $mech->field( $name, \@values, $number )

Given the name of a field, set its value to the value specified.  This
applies to the current form (as set by the C<L<form()>> method or defaulting
to the first form on the page).

The optional I<$number> parameter is used to distinguish between two fields
with the same name.  The fields are numbered from 1.

=cut

sub field {
    my ($self, $name, $value, $number) = @_;
    $number ||= 1;

    my $form = $self->{form};
    if ($number > 1) {
        $form->find_input($name, undef, $number)->value($value);
    }
    else {
        if ( ref($value) eq "ARRAY" ) {
            $form->param($name, $value);
        }
        else {
            $form->value($name => $value);
        }
    }
}

=head2 $mech->select($name, $value)

=head2 $mech->select($name, \@values)

Given the name of a C<select> field, set its value to the value
specified.  If the field is not E<lt>select multipleE<gt> and the
C<$value> is an array, only the B<first> value will be set.  [Note:
the documentation previously claimed that only the last value would
be set, but this was incorrect.]  Passing C<$value> as a hash with
an C<n> key selects an item by number (e.g. C<{n => 3> or C<{n => [2,4]}>).
The numbering starts at 1.  This applies to the current form (as set by the
C<L<form()>> method or defaulting to the first form on the page).

Returns 1 on successfully setting the value. On failure, returns
undef and calls C<$self->warn()> with an error message.

=cut

sub select {
    my ($self, $name, $value) = @_;

    my $form = $self->{form};

    my $input = $form->find_input($name);
    if (!$input) {
        $self->warn( qq{Input "$name" not found} );
        return;
    }

    if ($input->type ne 'option') {
        $self->warn( qq{Input "$name" is not type "select"} );
        return;
    }

    # For $mech->select($name, {n => 3}) or $mech->select($name, {n => [2,4]}),
    # transform the 'n' number(s) into value(s) and put it in $value.
    if (ref($value) eq "HASH") {
        for (keys %$value) {
            $self->warn(qq{Unknown select value parameter "$_"})
              unless $_ eq 'n';
        }

        if (defined($value->{n})) {
            my @inputs = $form->find_input($name, 'option');
            my @values = ();
            # distinguish between multiple and non-multiple selects
            # (see INPUTS section of `perldoc HTML::Form`)
            if (@inputs == 1) {
                @values = $inputs[0]->possible_values();
            }
            else {
                foreach my $input (@inputs) {
                    my @possible = $input->possible_values();
                    push @values, pop @possible;
                }
            }

            my $n = $value->{n};
            if (ref($n) eq 'ARRAY') {
                $value = [];
                for (@$n) {
                    unless (/^\d+$/) {
                        $self->warn(qq{"n" value "$_" is not a positive integer});
                        return;
                    }
                    push @$value, $values[$_ - 1];  # might be undef
                }
            }
            elsif (!ref($n) && $n =~ /^\d+$/) {
                $value = $values[$n - 1];           # might be undef
            }
            else {
                $self->warn('"n" value is not a positive integer or an array ref');
                return;
            }
        }
        else {
            $self->warn('Hash value is invalid');
            return;
        }
    }

    if (ref($value) eq "ARRAY") {
        $form->param($name, $value);
        return 1;
    }

    $form->value($name => $value);
    return 1;
}

=head2 $mech->set_fields( $name => $value ... )

This method sets multiple fields of the current form. It takes a list
of field name and value pairs. If there is more than one field with
the same name, the first one found is set. If you want to select which
of the duplicate field to set, use a value which is an anonymous array
which has the field value and its number as the 2 elements.

        # set the second foo field
        $mech->set_fields( $name => [ 'foo', 2 ] ) ;

The fields are numbered from 1.

This applies to the current form (as set by the C<L<form()>> method or
defaulting to the first form on the page).

=cut

sub set_fields {
    my $self = shift;
    my %fields = @_;

    my $form = $self->current_form or $self->die( "No form defined" );

    while ( my ( $field, $value ) = each %fields ) {
        if ( ref $value eq 'ARRAY' ) {
            $form->find_input( $field, undef,
                         $value->[1])->value($value->[0] );
        }
        else {
            $form->value($field => $value);
        }
    } # while
} # set_fields()

=head2 $mech->set_visible( @criteria )

This method sets fields of the current form without having to know
their names.  So if you have a login screen that wants a username and
password, you do not have to fetch the form and inspect the source (or
use the F<mech-dump> utility, installed with WWW::Mechanize) to see
what the field names are; you can just say

    $mech->set_visible( $username, $password ) ;

and the first and second fields will be set accordingly.  The method
is called set_I<visible> because it acts only on visible fields;
hidden form inputs are not considered.  The order of the fields is
the order in which they appear in the HTML source which is nearly
always the order anyone viewing the page would think they are in,
but some creative work with tables could change that; caveat user.

Each element in C<@criteria> is either a field value or a field
specifier.  A field value is a scalar.  A field specifier allows
you to specify the I<type> of input field you want to set and is
denoted with an arrayref containing two elements.  So you could
specify the first radio button with

    $mech->set_visible( [ radio => "KCRW" ] ) ;

Field values and specifiers can be intermixed, hence

    $mech->set_visible( "fred", "secret", [ option => "Checking" ] ) ;

would set the first two fields to "fred" and "secret", and the I<next>
C<OPTION> menu field to "Checking".

The possible field specifier types are: "text", "password", "hidden",
"textarea", "file", "image", "submit", "radio", "checkbox" and "option".

=cut

sub set_visible {
    my $self = shift;

    my $form = $self->current_form;
    my @inputs = $form->inputs;

    my $num_set = 0;
    for my $value ( @_ ) {
        if ( ref $value eq 'ARRAY' ) {
            my ( $type, $value ) = @$value;
            while ( my $input = shift @inputs ) {
                next if $input->type eq 'hidden';
                if ( $input->type eq $type ) {
                    $input->value( $value );
                    $num_set++;
                    last;
                }
            } # while
        }
        else {
            while ( my $input = shift @inputs ) {
                next if $input->type eq 'hidden';
                $input->value( $value );
                $num_set++;
                last;
            } # while
        }
    } # for

    return $num_set;
} # set_visible()

=head2 $mech->tick( $name, $value [, $set] )

'Ticks' the first checkbox that has both the name and value assoicated
with it on the current form.  Dies if there is no named check box for
that value.  Passing in a false value as the third optional argument
will cause the checkbox to be unticked.

=cut

sub tick {
    my $self = shift;
    my $name = shift;
    my $value = shift;
    my $set = @_ ? shift : 1;  # default to 1 if not passed

    # loop though all the inputs
    my $index = 0;
    while ( my $input = $self->current_form->find_input( $name, "checkbox", $index ) ) {
        # Can't guarantee that the first element will be undef and the second
        # element will be the right name
        foreach my $val ($input->possible_values()) {
            next unless defined $val;
            if ($val eq $value) {
                $input->value($set ? $value : undef);
                return;
            }
        }

        # move onto the next input
        $index++;
    } # while

    # got self far?  Didn't find anything
    $self->warn( qq{No checkbox "$name" for value "$value" in form} );
} # tick()

=head2 $mech->untick($name, $value)

Causes the checkbox to be unticked.  Shorthand for
C<tick($name,$value,undef)>

=cut

sub untick {
    shift->tick(shift,shift,undef);
}

=head2 $mech->value( $name, $number )

Given the name of a field, return its value. This applies to the current
form (as set by the C<form()> method or defaulting to the first form on
the page).

The option I<$number> parameter is used to distinguish between two fields
with the same name.  The fields are numbered from 1.

If the field is of type file (file upload field), the value is always
cleared to prevent remote sites from downloading your local files.
To upload a file, specify its file name explicitly.

=cut

sub value {
    my $self = shift;
    my $name = shift;
    my $number = shift || 1;

    my $form = $self->{form};
    if ( $number > 1 ) {
        return $form->find_input( $name, undef, $number )->value();
    }
    else {
        return $form->value( $name );
    }
} # value

=head2 $mech->click( $button [, $x, $y] )

Has the effect of clicking a button on the current form.  The first
argument is the name of the button to be clicked.  The second and
third arguments (optional) allow you to specify the (x,y) coordinates
of the click.

If there is only one button on the form, C<< $mech->click() >> with
no arguments simply clicks that one button.

Returns an L<HTTP::Response> object.

=cut

sub click {
    my ($self, $button, $x, $y) = @_;
    for ($x, $y) { $_ = 1 unless defined; }
    my $request = $self->{form}->click($button, $x, $y);
    return $self->request( $request );
}

=head2 $mech->click_button( ... )

Has the effect of clicking a button on the current form by specifying
its name, value, or index.  Its arguments are a list of key/value
pairs.  Only one of name, number, input or value must be specified in
the keys.

=over 4

=item * name => name

Clicks the button named I<name> in the current form.

=item * number => n

Clicks the I<n>th button in the current form. Numbering starts at 1.

=item * value => value

Clicks the button with the value I<value> in the current form.

=item * input => $inputobject

Clicks on the button referenced by $inputobject, an instance of
L<HTML::Form::SubmitInput> obtained e.g. from

  $mech->current_form()->find_input(undef, "submit")

$inputobject must belong to the current form.

=item * x => x
=item * y => y

These arguments (optional) allow you to specify the (x,y) coordinates
of the click.

=back

=cut

sub click_button {
    my $self = shift;
    my %args = @_;

    for ( keys %args ) {
        if ( !/^(number|name|value|input|x|y)$/ ) {
            $self->warn( qq{Unknown click_button parameter "$_"} );
        }
    }

    for ($args{x}, $args{y}) { $_ = 1 unless defined; }
    my $form = $self->{form};
    my $request;
    if ( $args{name} ) {
        $request = $form->click( $args{name}, $args{x}, $args{y} );
    }
    elsif ( $args{number} ) {
        my $input = $form->find_input( undef, 'submit', $args{number} );
        $request = $input->click( $form, $args{x}, $args{y} );
    }
    elsif ( $args{input} ) {
        $request = $args{input}->click( $form, $args{x}, $args{y} );
    }
    elsif ( $args{value} ) {
        my $i = 1;
        while ( my $input = $form->find_input(undef, 'submit', $i) ) {
            if ( $args{value} && ($args{value} eq $input->value) ) {
                $request = $input->click( $form, $args{x}, $args{y} );
                last;
            }
            $i++;
        } # while
    } # $args{value}

    return $self->request( $request );
}

=head2 $mech->submit()

Submits the page, without specifying a button to click.  Actually,
no button is clicked at all.

This used to be a synonym for C<< $mech->click("submit") >>, but is no
longer so.

=cut

sub submit {
    my $self = shift;

    my $request = $self->{form}->make_request;
    return $self->request( $request );
}

=head2 $mech->submit_form( ... )

This method lets you select a form from the previously fetched page,
fill in its fields, and submit it. It combines the form_number/form_name,
set_fields and click methods into one higher level call. Its arguments
are a list of key/value pairs, all of which are optional.

=over 4

=item * form_number => n

Selects the I<n>th form (calls C<L<form_number()>>).  If this parm is not
specified, the currently-selected form is used.

=item * form_name => name

Selects the form named I<name> (calls C<L<form_name()>>)

=item * fields => fields

Sets the field values from the I<fields> hashref (calls C<L<set_fields()>>)

=item * button => button

Clicks on button I<button> (calls C<L<click()>>)

=item * x => x, y => y

Sets the x or y values for C<L<click()>>

=back

If no form is selected, the first form found is used.

If I<button> is not passed, then the C<L<submit()>> method is used instead.

Returns an L<HTTP::Response> object.

=cut

sub submit_form {
    my( $self, %args ) = @_ ;

    for ( keys %args ) {
        if ( !/^(form_(number|name)|fields|button|x|y)$/ ) {
            $self->warn( qq{Unknown submit_form parameter "$_"} );
        }
    }

    if ( my $form_number = $args{'form_number'} ) {
        $self->form_number( $form_number ) or die;
    }
    elsif ( my $form_name = $args{'form_name'} ) {
        $self->form_name( $form_name ) or die;
    }

    if ( my $fields = $args{'fields'} ) {
        if ( isa( $fields, 'HASH' ) ) {
            $self->set_fields( %{$fields} ) ;
        } # TODO: What if it's not a hash?  We just ignore it silently?
    }

    my $response;
    if ( $args{button} ) {
        $response = $self->click( $args{button}, $args{x} || 0, $args{y} || 0 );
    }
    else {
        $response = $self->submit();
    }

    return $response;
}

=head1 MISCELLANEOUS METHODS

=head2 $mech->add_header( name => $value [, name => $value... ] )

Sets HTTP headers for the agent to add or remove from the HTTP request.

    $mech->add_header( Encoding => 'text/klingon' );

If a I<value> is C<undef>, then that header will be removed from any
future requests.  For example, to never send a Referer header:

    $mech->add_header( Referer => undef );

If you want to delete a header, use C<delete_header>.

Returns the number of name/value pairs added.

B<NOTE>: This method was very different in WWW::Mechanize before 1.00.
Back then, the headers were stored in a package hash, not as a member of
the object instance.  Calling C<add_header()> would modify the headers
for every WWW::Mechanize object, even after your object no longer existed.

=cut

sub add_header {
    my $self = shift;
    my $npairs = 0;

    while ( @_ ) {
        my $key = shift;
        my $value = shift;
        ++$npairs;

        $self->{headers}{$key} = $value;
    }

    return $npairs;
}

=head2 $mech->delete_header( name [, name ... ] )

Removes HTTP headers from the agent's list of special headers.  For instance, you might need to do something like:

    # Don't send a Referer for this URL
    $mech->add_header( Referer => undef );

    # Get the URL
    $mech->get( $url );

    # Back to the default behavior
    $mech->delete_header( 'Referer' );

=cut

sub delete_header {
    my $self = shift;

    while ( @_ ) {
        my $key = shift;

        delete $self->{headers}{$key};
    }
}


=head2 $mech->quiet(true/false)

Allows you to suppress warnings to the screen.

    $mech->quiet(0); # turns on warnings (the default)
    $mech->quiet(1); # turns off warnings
    $mech->quiet();  # returns the current quietness status

=cut

sub quiet {
    my $self = shift;

    $self->{quiet} = $_[0] if @_;

    return $self->{quiet};
}

=head2 $mech->stack_depth($value)

Get or set the page stack depth. Older pages are discarded first.

A value of 0 means "keep all the pages".

=cut

sub stack_depth {
    my $self = shift;
    $self->{stack_depth} = shift if @_;
    return $self->{stack_depth};
}

=head2 $mech->save_content( $filename )

Dumps the contents of C<< $mech->content >> into I<$filename>.
I<$filename> will be overwritten.

=cut

sub save_content {
    my $self = shift;
    my $filename = shift;

    open( my $fh, ">", $filename ) or $self->die( "Unable to create $filename: $!" );
    print $fh $self->content;
    close $fh;
}

=head1 OVERRIDDEN LWP::UserAgent METHODS

=head2 $mech->redirect_ok()

An overloaded version of C<redirect_ok()> in L<LWP::UserAgent>.
This method is used to determine whether a redirection in the request
should be followed.

=cut

sub redirect_ok {
    my $self = shift;
    my $prospective_request = shift;
    my $response = shift;

    my $ok = $self->SUPER::redirect_ok( $prospective_request, $response );
    if ( $ok ) {
        $self->{redirected_uri} = $prospective_request->uri;
    }

    return $ok;
}


=head2 $mech->request( $request [, $arg [, $size]])

Overloaded version of C<request()> in L<LWP::UserAgent>.  Performs
the actual request.  Normally, if you're using WWW::Mechanize, it's
because you don't want to deal with this level of stuff anyway.

Note that C<$request> will be modified.

Returns an L<HTTP::Response> object.

=cut

sub request {
    my $self = shift;
    my $request = shift;

    $request = $self->_modify_request( $request );

    if ( $request->method eq "GET" || $request->method eq "POST" ) {
        $self->_push_page_stack();
    }

    $self->_update_page($request, $self->_make_request( $request, @_ ));
}

=head2 $mech->update_html( $html )

Allows you to replace the HTML that the mech has found.  Updates the
forms and links parse-trees that the mech uses internally.

Say you have a page that you know has malformed output, and you want to
update it so the links come out correctly:

    my $html = $mech->content;
    $html =~ s[</option>.{0,3}</td>][</option></select></td>]isg;
    $mech->update_html( $html );

This method is also used internally by the mech itself to update its
own HTML content when loading a page. This means that if you would
like to I<systematically> perform the above HTML substitution, you
would overload I<update_html> in a subclass thusly:

   package MyMech;
   use base 'WWW::Mechanize';

   sub update_html {
       my ($self, $html) = @_;
       $html =~ s[</option>.{0,3}</td>][</option></select></td>]isg;
       $self->WWW::Mechanize::update_html( $html );
   }

If you do this, then the mech will use the tidied-up HTML instead of
the original both when parsing for its own needs, and for returning to
you through L</content>.

Overloading this method is also the recommended way of implementing
extra validation steps (e.g. link checkers) for every HTML page
received.  L</warn> and L</die> would then come in handy to signal
validation errors.

=cut

sub update_html {
    my $self = shift;
    my $html = shift;

    $self->_reset_page;
    $self->{ct} = 'text/html';
    $self->{content} = $html;

    $self->{forms} = [ HTML::Form->parse($html, $self->base) ];
    for my $form (@{ $self->{forms} }) {
        for my $input ($form->inputs) {
             if ($input->type eq 'file') {
                 $input->value( undef );
             }
        }
    }
    $self->{form}  = $self->{forms}->[0];
    $self->_extract_links();
    $self->_extract_images();

    return;
}

=head1 DEPRECATED METHODS

This methods have been replaced by more flexible and precise methods.
Please use them instead.

=head2 $mech->follow($string|$num)

B<DEPRECATED> in favor of C<L<follow_link()>>, which provides more
flexibility.

Follow a link.  If you provide a string, the first link whose text
matches that string will be followed.  If you provide a number, it
will be the I<$num>th link on the page.  Note that the links are
0-based.

Returns true if the link was found on the page or undef otherwise.

=cut

sub follow {
    my ($self, $link) = @_;
    my @links = $self->links;
    my $thislink;
    if ( $link =~ /^\d+$/ ) { # is a number?
        if ($link <= $#links) {
            $thislink = $links[$link];
        }
        else {
            $self->warn( "Link number $link is greater than maximum link $#links on this page ($self->{uri})" );
            return;
        }
    }
    else {                        # user provided a regexp
        LINK: foreach my $l (@links) {
            if ( defined($l->[1]) && $l->[1] =~ /$link/) {
                $thislink = $l;     # grab first match
                last LINK;
            }
        }
        unless ($thislink) {
            $self->warn( "Can't find any link matching $link on this page ($self->{uri})" );
            return;
        }
    }

    $thislink = $thislink->[0];     # we just want the URL, not the text

    $self->get( $thislink );

    return 1;
}

=head2 $mech->form($number|$name)

B<DEPRECATED> in favor of C<L<form_name()>> or C<L<form_number()>>.

Selects a form by number or name, depending on if it gets passed an
all-numeric string or not.  This means that if you have a form name
that's all digits, this method will not do the right thing.

=cut

sub form {
    my $self = shift;
    my $arg = shift;

    return $arg =~ /^\d+$/ ? $self->form_number($arg) : $self->form_name($arg);
}

=head1 INTERNAL-ONLY METHODS

These methods are only used internally.  You probably don't need to
know about them.

=head2 $mech->_update_page($request, $response)

Updates all internal variables in $mech as if $request was just
performed, and returns $response. The page stack is B<not> altered by
this method, it is up to caller (e.g. L</request>) to do that.

=cut

sub _update_page {
    my ($self, $request, $res) = @_;

    $self->{req} = $request;
    $self->{redirected_uri} = $request->uri->as_string;

    $self->{res} = $res;

    # These internal hash elements should be dropped in favor of
    # the accessors soon. -- 1/19/03
    $self->{status}  = $res->code;
    $self->{base}    = $res->base;
    $self->{ct}      = $res->content_type || "";

    if ( $res->is_success ) {
        $self->{uri} = $self->{redirected_uri};
        $self->{last_uri} = $self->{uri};
    }
    else {
        if ( $self->{autocheck} ) {
            $self->die( "Error ", $request->method, "ing ", $request->uri, ": ", $res->message );
        }
    }

    $self->_reset_page;
    if ($self->is_html) {
        $self->update_html($res->content);
    }
    else {
        $self->{content} = $res->content;
    }

    return $res;
} # _update_page


=head2 $mech->_modify_request( $req )

Modifies the request according to all the internal header mangling.

=cut

sub _modify_request {
    my $self = shift;
    my $req = shift;

    # add correct Accept-Encoding header to restore compliance with
    # http://www.freesoft.org/CIE/RFC/2068/158.htm
    unless ( $req->header( 'Accept-Encoding' ) ) {
        # Only allow "identity" for the time being
        $req->header( 'Accept-Encoding', 'identity' );
    }

    my $last = $self->{last_uri};
    if ( $last ) {
        $last = $last->as_string if ref($last);
        $req->header( Referer => $last );
    }
    while ( my($key,$value) = each %{$self->{headers}} ) {
        if ( defined $value ) {
            $req->header( $key => $value );
        }
        else {
            $req->remove_header( $key );
        }
    }

    return $req;
}


=head2 $mech->_make_request()

Convenience method to make it easier for subclasses like
L<WWW::Mechanize::Cached> to intercept the request.

=cut

sub _make_request {
    my $self = shift;
    $self->SUPER::request(@_);
}

=head2 $mech->_reset_page()

Resets the internal fields that track page parsed stuff.

=cut

sub _reset_page {
    my $self = shift;

    $self->{links} = [];
    $self->{forms} = [];
    delete $self->{form};

    return;
}

=head2 $mech->_extract_links()

Extracts links from the content of a webpage, and populates the C<{links}>
property with L<WWW::Mechanize::Link> objects.

=cut

my %link_tags = (
    a => "href",
    area => "href",
    frame => "src",
    iframe => "src",
    meta => "content",
);

sub _extract_links {
    my $self = shift;

    my $parser = HTML::TokeParser->new(\$self->{content});

    $self->{links} = [];

    while ( my $token = $parser->get_tag( keys %link_tags ) ) {
        my $link = $self->_link_from_token( $token, $parser );
        push( @{$self->{links}}, $link ) if $link;
    } # while

    return;
}


my %image_tags = (
    img => "src",
    input => "src",
);

sub _extract_images {
    my $self = shift;

    my $parser = HTML::TokeParser->new(\$self->{content});

    $self->{images} = [];

    while ( my $token = $parser->get_tag( keys %image_tags ) ) {
        my $image = $self->_image_from_token( $token, $parser );
        push( @{$self->{images}}, $image ) if $image;
    } # while

    return;
}

sub _image_from_token {
    my $self = shift;
    my $token = shift;
    my $parser = shift;

    my $tag = $token->[0];
    my $attrs = $token->[1];

    if ( $tag eq "input" ) {
        my $type = $attrs->{type} or return;
        return unless $type eq "image";
    }

    require WWW::Mechanize::Image;
    return
        WWW::Mechanize::Image->new({
            tag     => $tag,
            base    => $self->base,
            url     => $attrs->{src},
            name    => $attrs->{name},
            height  => $attrs->{height},
            width   => $attrs->{width},
            alt     => $attrs->{alt},
        });
}

sub _link_from_token {
    my $self = shift;
    my $token = shift;
    my $parser = shift;

    my $tag = $token->[0];
    my $attrs = $token->[1];
    my $url = $attrs->{$link_tags{$tag}};

    my $text;
    my $name;
    if ( $tag eq "a" ) {
        $text = $parser->get_trimmed_text("/$tag");
        $text = "" unless defined $text;

        my $onClick = $attrs->{onclick};
        if ( $onClick && ($onClick =~ /^window\.open\(\s*'([^']+)'/) ) {
            $url = $1;
        }
    } # a

    # Of the tags we extract from, only 'AREA' has an alt tag
    # The rest should have a 'name' attribute.
    # ... but we don't do anything with that bit of wisdom now.

    $name = $attrs->{name};

    if ( $tag eq "meta" ) {
        my $equiv = $attrs->{"http-equiv"};
        my $content = $attrs->{"content"};
        return unless $equiv && (lc $equiv eq "refresh") && defined $content;

        if ( $content =~ /^\d+\s*;\s*url\s*=\s*(\S+)/i ) {
            $url = $1;
        }
        else {
            undef $url;
        }
    } # meta

    return unless defined $url;   # probably just a name link or <AREA NOHREF...>

    require WWW::Mechanize::Link;
    return
        WWW::Mechanize::Link->new({
            url  => $url,
            text => $text,
            name => $name,
            tag  => $tag,
            base => $self->base,
            attrs => $attrs,
        });
} # _link_from_token

=head2 $mech->_push_page_stack() / $mech->_pop_page_stack()

The agent keeps a stack of visited pages, which it can pop when it needs
to go BACK and so on.

The current page needs to be pushed onto the stack before we get a new
page, and the stack needs to be popped when BACK occurs.

Neither of these take any arguments, they just operate on the $mech
object.

=cut

sub _push_page_stack {
    my $self = shift;

    # Don't push anything if it's a virgin object
    if ( $self->{res} ) {
        my $save_stack = $self->{page_stack};
        $self->{page_stack} = [];

        my $clone = $self->clone;
        # Huh, LWP::UserAgent->clone() ditches cookie_jar? Copy it over now.
        $clone->{cookie_jar} = $self->cookie_jar;
        push( @$save_stack, $clone );

        if ( $self->stack_depth > 0 ) {
            while ( @$save_stack > $self->stack_depth ) {
                shift @$save_stack;
            }
        } # if stack_depth > 0
        $self->{page_stack} = $save_stack;
    }

    return 1;
}

sub _pop_page_stack {
    my $self = shift;

    if (@{$self->{page_stack}}) {
        my $popped = pop @{$self->{page_stack}};

        # eliminate everything in self
        foreach my $key ( keys %$self ) {
            delete $self->{ $key }              unless $key eq 'page_stack';
        }

        # make self just like the popped object
        foreach my $key ( keys %$popped ) {
            $self->{ $key } = $popped->{ $key } unless $key eq 'page_stack';
        }
    }

    return 1;
}

=head2 warn( @messages )

Centralized warning method, for diagnostics and non-fatal problems.
Defaults to calling C<CORE::warn>, but may be overridden by setting
C<onwarn> in the construcotr.

=cut

sub warn {
    my $self = shift;

    return unless my $handler = $self->{onwarn};

    return if $self->quiet;

    $handler->(@_);
}

=head2 die( @messages )

Centralized error method.  Defaults to calling C<CORE::die>, but
may be overridden by setting C<onerror> in the constructor.

=cut

sub die {
    my $self = shift;

    return unless my $handler = $self->{onerror};

    $handler->(@_);
}


# NOT an object method!
sub _warn {
    require Carp;
    &Carp::carp; # pass thru
}

# NOT an object method!
sub _die {
    require Carp;
    &Carp::croak; # pass thru
}

__END__

=head1 WWW::MECHANIZE'S SUBVERSION REPOSITORY

Mech is hosted by the kind generosity of Ask and Robert,
maintainers of perl.org.  The Subversion repository is at
L<http://svn.perl.org/modules/www-mechanize>.

=head1 OTHER DOCUMENTATION

=head2 I<Spidering Hacks>, by Kevin Hemenway and Tara Calishain

I<Spidering Hacks> from O'Reilly
(L<http://www.oreilly.com/catalog/spiderhks/>) is a great book for anyone
wanting to know more about screen-scraping and spidering.

There are six hacks that use Mech or a Mech derivative:

=over 4

=item #21 WWW::Mechanize 101

=item #22 Scraping with WWW::Mechanize

=item #36 Downloading Images from Webshots

=item #44 Archiving Yahoo! Groups Messages with WWW::Yahoo::Groups

=item #64 Super Author Searching

=item #73 Scraping TV Listings

=back

The book was also positively reviewed on Slashdot:
L<http://books.slashdot.org/article.pl?sid=03/12/11/2126256>

=head1 ONLINE RESOURCES

=over 4

=item * WWW::Mechanize Development mailing list

Hosted at Sourceforge, this is where the contributors to Mech
discuss things.  L<http://sourceforge.net/mail/?group_id=83309>

=item * LWP mailing list

The LWP mailing list is at
L<http://lists.perl.org/showlist.cgi?name=libwww>, and is more
user-oriented and well-populated than the WWW::Mechanize Development
list.  This is a good list for Mech users, since LWP is the basis
for Mech.

=item * L<WWW::Mechanize::Examples>

A random array of examples submitted by users, included with the
Mechanize distribution.

=back

=head1 ARTICLES ABOUT WWW::MECHANIZE

=over 4

=item * L<http://www.oreilly.com/catalog/googlehks2/chapter/hack84.pdf>

Leland Johnson's hack #84 in I<Google Hacks, 2nd Edition> is
an example of a production script that uses WWW::Mechanize and
HTML::TableContentParser. It takes in keywords and returns the estimated
price of these keywords on Google's AdWords program.

=item * L<http://www.perl.com/pub/a/2004/06/04/recorder.html>

Linda Julien writes about using HTTP::Recorder to create WWW::Mechanize
scripts.

=item * L<http://www.developer.com/lang/other/article.php/3454041>

Jason Gilmore's article on using WWW::Mechanize for scraping sales
information from Amazon and eBay.

=item * L<http://www.perl.com/pub/a/2003/01/22/mechanize.html>

Chris Ball's article about using WWW::Mechanize for scraping TV
listings.

=item * L<http://www.stonehenge.com/merlyn/LinuxMag/col47.html>

Randal Schwartz's article on scraping Yahoo News for images.  It's
already out of date: He manually walks the list of links hunting
for matches, which wouldn't have been necessary if the C<find_link()>
method existed at press time.

=item * L<http://www.perladvent.org/2002/16th/>

WWW::Mechanize on the Perl Advent Calendar, by Mark Fowler.

=item * L<http://www.linux-magazin.de/Artikel/ausgabe/2004/03/perl/perl.html>

Michael Schilli's article on Mech and L<WWW::Mechanize::Shell> for the
German magazine I<Linux Magazin>.

=back

=head2 Other modules that use Mechanize

Here are modules that use or subclass Mechanize.  Let me know of any others:

=over 4

=item * L<Finance::Bank::LloydsTSB>

=item * L<HTTP::Recorder>

Acts as a proxy for web interaction, and then generates WWW::Mechanize scripts.

=item * L<Win32::IE::Mechanize>

Just like Mech, but using Microsoft Internet Explorer to do the work.

=item * L<WWW::Bugzilla>

=item * L<WWW::CheckSite>

=item * L<WWW::Google::Groups>

=item * L<WWW::Hotmail>

=item * L<WWW::Mechanize::Cached>

=item * L<WWW::Mechanize::FormFiller>

=item * L<WWW::Mechanize::Shell>

=item * L<WWW::Mechanize::Sleepy>

=item * L<WWW::Mechanize::SpamCop>

=item * L<WWW::Mechanize::Timed>

=item * L<WWW::SourceForge>

=item * L<WWW::Yahoo::Groups>

=back

=head1 REQUESTS & BUGS

Please report any requests, suggestions or (gasp!) bugs via the
excellent RT bug-tracking system at http://rt.cpan.org/, or email to
bug-WWW-Mechanize@rt.cpan.org.  This makes it much easier for me to
track things.

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=WWW-Mechanize> is the RT queue
for Mechanize.  Please check to see if your bug has already been reported.

=head1 ACKNOWLEDGEMENTS

Thanks to the numerous people who have helped out on WWW::Mechanize in
one way or another, including
Kirrily Robert for the orignal C<WWW::Automate>,
Mike O'Regan,
Mark Stosberg,
Uri Guttman,
Peter Scott,
Phillipe Bruhat,
Ian Langworth,
John Beppu,
Gavin Estey,
Jim Brandt,
Ask Bjoern Hansen,
Greg Davies,
Ed Silva,
Mark-Jason Dominus,
Autrijus Tang,
Mark Fowler,
Stuart Children,
Max Maischein,
Meng Wong,
Prakash Kailasa,
Abigail,
Jan Pazdziora,
Dominique Quatravaux,
Scott Lanning,
Rob Casey,
Leland Johnson,
Joshua Gatcomb,
Julien Beasley,
Abe Timmerman,
Peter Stevens,
and the late great Iain Truskett.

=head1 COPYRIGHT

Copyright (c) 2005 Andy Lester. All rights reserved. This program is
free software; you can redistribute it and/or modify it under the same
terms as Perl itself.

=cut

1;
