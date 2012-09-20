use strict;
package TWiki::Plugins::IncludeXMLPlugin::Handler;

use TWiki::Plugins::IncludeXMLPlugin;
use TWiki::Plugins::IncludeXMLPlugin::SubsequenceGenerator;
use TWiki::Plugins::IncludeXMLPlugin::XPathModifier;

use Encode;
use HTML::Entities;
use HTTP::Request;
use HTTP::Response;
use LWP::UserAgent;
use XML::LibXML;
use XML::LibXML::XPathContext;

my %xmlCache = ();

=begin twiki

---++ StaticMethod new($session, $params, $theTopic, $theWeb)

Creates a new object.

=cut

sub new {
    my ($class, $session, $params, $theTopic, $theWeb) = @_;

    bless {
        session  => $session,
        params   => $params,
        theTopic => $theTopic,
        theWeb   => $theWeb
    }, $class;
}

=begin twiki

---++ StaticMethod clearCache()

Clears the internal cache. Expected to be called when all the variable expansion is completed.

=cut

sub clearCache {
    %xmlCache = ();
}

=begin twiki

---++ ObjectMethod generate() -> \$text

Generates the result text (table or formatted text).

=cut

sub generate {
    my ($self) = @_;
    my $params = $self->{params};
    my $xml = $self->getXML($params->{_DEFAULT}, $params->{request}, TWiki::isTrue($params->{soap}));
    my ($fields, $table, $varnames, $exnames) = $self->buildTable($$xml);
    return $self->formatTable($fields, $table, $varnames, $exnames);
}

sub getVariableMap {
    my ($self, $varnames, $exnames) = @_;

    # Example:
    #   (Indices)   0,               1,              2
    #   VarNames = [['abc', 'def'], ['ghi', 'abc'], ['def', 'jkl']]
    #   ExNames  = [['foo']       , []            , ['abc']       ]
    #   Output = {'abc' => 2, 'def' => 0, 'ghi' => 1, 'jkl' => 2, 'foo' => 0}
    my %varmap = map {$_ => undef} map {@$_} (@$varnames, @$exnames);

    for my $names ($exnames, $varnames) {
        if ($names && @$names > 0) {
            for my $i (0..$#$names) {
                for my $var (@{$names->[$i]}) {
                    $varmap{$var} = $i if !defined $varmap{$var};
                }
            }
        }
    }

    return \%varmap;
}

=begin twiki

---++ ObjectMethod buildTable($xml) -> ($fields, $table, $varnames, $exnames)

Converts the =$xml= text into a table.
   * =$fields= - an array ref of field names
   * =$table= - a 2-level array ref to table values
   * =$varnames= - an array ref to lists of default variable names
   * =$exnames= - an array ref to lists of explicit variable names

=cut

sub buildTable {
    my $self =  $_[0];
    my $xml  = \$_[1];

    my $params = $self->{params};

    my $records = $params->{records};
    my $fields  = $params->{fields};
    my $itemsep = $params->{itemsep};

    my $offset = $params->{offset};
    my $limit = $params->{limit};
    my $reverse = TWiki::isTrue($params->{reverse}, 0);

    defined($records) or $records = '';
    defined($fields ) or $fields  = '';
    defined($itemsep) or $itemsep = ', ';

    # Check if there are parameters required to create a table
    if ($records eq ''  and $fields eq '') {
        my $msg = "Either records or fields must be specified";
        $self->error($msg);
    }

    # Parse XML
    my ($dom, $xpc);

    eval {
        $dom = XML::LibXML->load_xml(string => $$xml);
        $xpc = XML::LibXML::XPathContext->new($dom)
                or die "Cannot create XPathContext";

        # Replace all CDATA sections with the inner texts
        for my $node ($xpc->findnodes('//text()')->get_nodelist) {
            if ($node->nodeType == XML::LibXML::XML_CDATA_SECTION_NODE) {
                $node->replaceNode($dom->createTextNode($node->nodeValue));
            }
        }
    };

    if ($@) {
        my $msg = "Failed to parse XML document: $@";
        $self->error($msg);
    };

    # Set up NS's
    for my $name (keys %$params) {
        if ($name =~ /^xmlns[:_](.*)/) {
            my $prefix = $1;
            $xpc->registerNs($prefix, $params->{$name});
            # Note: Do not pass $1 directly to the method, or a segmentation fault will be caused
        }
    }

    # Parse fields
    my $colxpm = TWiki::Plugins::IncludeXMLPlugin::XPathModifier->new();
    $colxpm->parse($fields)->addPrefixes('//');
    my @fields = $colxpm->getXPaths();

    # Parse records
    my $rowxpath = '';

    if ($records ne '') {
        my $rowxpm = TWiki::Plugins::IncludeXMLPlugin::XPathModifier->new();
        $rowxpm->parse($records)->addPrefixes('//');
        $rowxpath = join '|', $rowxpm->getModifiedXPaths();
    }

    # Create table
    my $sg = TWiki::Plugins::IncludeXMLPlugin::SubsequenceGenerator->new($offset, $limit);

    if ($records ne '') {
        if ($fields ne '') {
            # CASE 1: Both $records and $fields are specified
            my @colxpaths = $colxpm->addPrefixes('.//')->getModifiedXPaths();

            for my $rownode ($xpc->findnodes($rowxpath)->get_nodelist) {
                $sg->push(sub {
                    my $row = [];

                    for my $colxpath (@colxpaths) {
                        my @nodelist = $xpc->findnodes($colxpath, $rownode)->get_nodelist;
                        push @$row, [@nodelist];
                    }

                    return $row;
                });

                last unless $sg->more;
            }
        } else {
            # CASE 2: Only $records is specified
            my %fieldIndices = ();

            for my $rownode ($xpc->findnodes($rowxpath)->get_nodelist) {
                $sg->push(sub {
                    my $row = [];

                    for my $node ($rownode->attributes, $rownode->childNodes) {
                        my $fieldName = $node->nodeName;

                        if ($node->nodeType == XML::LibXML::XML_ATTRIBUTE_NODE) {
                            $fieldName = '@'.$fieldName;
                        } elsif ($node->nodeType != XML::LibXML::XML_ELEMENT_NODE) {
                            next;
                        }

                        my $c = $fieldIndices{$fieldName};

                        unless (defined $c) {
                            push @fields, $fieldName;
                            $c = $#fields;
                            $fieldIndices{$fieldName} = $c;
                        }

                        $row->[$c] ||= [];
                        push @{$row->[$c]}, $node;
                    }

                    return $row;
                });

                last unless $sg->more;
            }
        }
    } else {
        if ($fields ne '') {
            # CASE 3: Only $fields is specified
            my @colxpaths = $colxpm->getModifiedXPaths();
            my $c = 0;

            for my $colxpath (@colxpaths) {
                my $r = 0;

                for my $node ($xpc->findnodes($colxpath)->get_nodelist) {
                    $sg->set($r, sub {
                        my ($row) = @_;
                        $row ||= [];
                        $row->[$c] ||= [$node];
                        return $row;
                    });

                    $r++;
                }

                $c++;
            }
        }
    }

    my @table = @{$sg->result};
    @table = reverse @table if $reverse;

    # Fill table
    for my $r (0..$#table) {
        for my $c (0..$#fields) {
            my $nodes = $table[$r][$c] || [];
            $table[$r][$c] = join $itemsep, map {$self->getInnerText($_)} @$nodes;
        }
    }

    my @varnames;
    my @exnames;

    if ($fields ne '') {
        @varnames = $colxpm->getVariableNames();
        @exnames = $colxpm->getExplicitNames();
    } else {
        @varnames = map {my $name = $_; $name =~ s/^\@//; [$name]} @fields;
        @exnames = map {[]} @fields;
    }

    return (\@fields, \@table, \@varnames, \@exnames);
}

sub helpVariables {
    my ($self, $fields, $varmap, $varnames, $exnames) = @_;

    my @rows = ();

    for my $i (0..$#$fields) {
        my $field = $fields->[$i];

        push @rows, join('', '| ', $field, ' | ', join(', ', '$'.($i + 1), map {
            defined $varmap->{$_} && $varmap->{$_} == $i ? ('$'.$_) :
                ('%RED%<strike>$'.$_.'</strike>%ENDCOLOR%')
        } (@{$exnames->[$i] || []}, @{$varnames->[$i] || []})), ' |');
    }

    return \join("\n", "| *Field* | *Variable(s)* |", @rows);
}

=begin twiki

---++ ObjectMethod formatTable($fields, $table, $varnames, $exnames) -> \$text

Generates a formatted text based on a given table data.

=cut

sub formatTable {
    my ($self, $fields, $table, $varnames, $exnames) = @_;

    if (!defined $fields or !defined $table) {
        $self->error('Failed to build table');
    } elsif (@$fields == 0) {
        $self->error('No fields to display');
    }

    $varnames ||= [];
    $exnames ||= [];
    my $varmap = $self->getVariableMap($varnames, $exnames);

    my $params = $self->{params};

    if ($params->{help} && $params->{help} =~ /^var(iable)?s?/i) {
        return $self->helpVariables($fields, $varmap, $varnames, $exnames);
    }

    my @fields = @$fields;
    my @table  = @$table;
    my $header = $params->{header};
    my $footer = $params->{footer};
    my $format = $params->{format};
    my $separator = $params->{separator};

    # Format field names
    my @fieldNames = map {$self->_normalizeFieldHeader($_)} @fields;

    # Create header, body, and footer
    if (defined $header) {
        $header = $self->applyFormat($header, \@fieldNames, $varmap);
    } else {
        unless (defined $format) {
            $header = '| *'.join('* | *', map {$self->escapeValue($_)} @fieldNames)."* |";
        }
    }

    if (defined $footer) {
        $footer = $self->applyFormat($footer, \@fieldNames, $varmap);
    }

    if (defined $separator) {
        $separator = $self->applyFormat($separator, \@fieldNames, $varmap);
    } else {
        $separator = "\n";

        if (defined $format) {
            $separator = "" if $format =~ /\$n\s*$/;
        }
    }

    return \join($separator,
        (defined $header ? ($header) : ()),
        (map {$self->applyFormat($format, $_, $varmap)} @table),
        (defined $footer ? ($footer) : ()),
    );
}

sub error {
    my ($self, $msg) = @_;
    die "$msg\n";
}

sub debug {
    my ($self, $msg) = @_;
    die \$msg;
}

=begin twiki

---++ ObjectMethod getXML($source, $request, $isSoap) -> \$xml

Gets the XML from the given $source (URL, topic name, or a literal XML).

If =$request= is given, it is POSTed to the server.
If =$isSoap= is true, the request XML is wrapped in a soap envelope and body.

=cut

sub getXML {
    my $self    =  $_[0];
    my $source  = \$_[1];
    my $request = \$_[2];
    my $isSoap  =  $_[3];

    my $params = $self->{params};

    if (!defined($source) || $$source eq '') {
        my $msg = "Missing default parameter (URL, TWiki topic, or XML literal)";
        $self->error($msg);
    }

    if (!defined($request) || $$request eq '') {
        $request = \'';
    } else {
        $request = $self->getXML($$request, '', $isSoap);
    }

    if (defined($request) && $$request =~ /^\s*</m) {
        if ($$request !~ /^\s*<\?xml\b/m) {
            if ($isSoap && $$request !~ /^\s*<([^:]+:)?Envelope/m) {
                my $soapNs = $params->{xmlns_soap} || 'http://www.w3.org/2003/05/soap-envelope';
                    # or xmlns:soap="http://www.w3.org/2001/12/soap-envelope"

                $request = \<<END;
<?xml version="1.0" encoding="UTF-8"?>
<soap:Envelope xmlns:soap="$soapNs">
<soap:Body>
$$request
</soap:Body>
</soap:Envelope>
END
            } else {
                $request = \qq(<?xml version="1.0" encoding="UTF-8"?>\n$$request);
            }
        }
    }

    if (defined($params->{debug}) and $params->{debug} =~ /(\s|^)req/i) {
        $self->debug($$request);
    }

    my $xml = _getXMLCache($$source, $$request);

    if (!defined $xml) {
        if ($$source =~ /^[\s\r\n]*</) {
            $xml = $source;
        } else {
            if ($$source =~ m!^tcp://!) {
                $xml = $self->_getTCP($$source, $$request);
            } elsif ($$source =~ m!^https?://!) {
                $xml = $self->_getHTTP($$source, $$request, $isSoap);
            } elsif ($$source =~ m!^/!) {
                my $url = TWiki::Func::getUrlHost().$$source;
                $xml = $self->_getHTTP($url, $$request, $isSoap);
            } else {
                my $wikiName = TWiki::Func::getWikiName();
                my ($web, $topic) = TWiki::Func::normalizeWebTopicName($self->{theWeb}, $$source);

                unless (TWiki::Func::topicExists($web, $topic)) {
                    $self->error("Topic $$source does not exist");
                }

                if (TWiki::Func::checkAccessPermission('VIEW', $wikiName, undef, $topic, $web)) {
                    $xml = \(TWiki::Func::readTopic($web, $topic))[1];
                } else {
                    $self->error("You do not have access to $$source");
                }
            }

            _setXMLCache($$source, $$request, $$xml);
        }
    }

    if (defined($params->{debug}) and
            ($params->{debug} =~ /(\s|^)res/i or $$request =~ /$params->{debug}/i)) {
        $self->debug($$xml);
    }

    if ($$xml eq '') {
        my $msg = "Failed to retrieve XML document";
        $self->error($msg);
    }

    return $xml;
}

sub _getXMLCache {
    my $source  = \$_[0];
    my $request = \$_[1];

    if (rand() < 0.01) {
        for my $s (keys %xmlCache) {
            for my $r (keys %{$xmlCache{$s}}) {
                if ($xmlCache{$s}{$r}{expires} <= time) {
                    delete $xmlCache{$s}{$r};
                }
            }

            if (scalar(keys %{$xmlCache{$s}}) == 0) {
                delete $xmlCache{$s};
            }
        }
    }

    my $sourceCache = $xmlCache{$$source};

    if (exists $sourceCache->{$$request}) {
        my $requestCache = $sourceCache->{$$request};

        if ($requestCache->{expires} > time) {
            return $requestCache->{xml};
        }
    }

    return undef;
}

sub _setXMLCache {
    my $source  = \$_[0];
    my $request = \$_[1];
    my $xml     = \$_[2];

    my $sourceCache = ($xmlCache{$$source} ||= {});

    $sourceCache->{$$request} = {
        expires => time + 10 * 60,
        xml => $xml,
    };
}

sub escapeXML {
    my ($self, $text) = @_;
    $text =~ s/&/&amp;/g;
    $text =~ s/</&lt;/g;
    $text =~ s/>/&gt;/g;
    $text =~ s/"/&quot;/g; #"
    return $text;
}

sub _getTCP {
    my $self    =  $_[0];
    my $url     =  $_[1];
    my $request = \$_[2];

    my $params = $self->{params};

    my $timeout = $params->{timeout} || 5; # seconds

    my ($host, $port);

    if ($url =~ m!^tcp://([^:]+):(\d+)!) {
        ($host, $port) = ($1, $2);
    } else {
        my $msg = "Malformed URL: $url";
        $self->error($msg);
    }

    eval "use IO::Socket::INET";
    die $@ if $@;

    my $sock = IO::Socket::INET->new(
        PeerAddr => $host,
        PeerPort => $port,
        Proto => 'tcp',
        Timeout => $timeout,
    ) or die "Socket error ($host:$port): $@";

    my $orig = select $sock;
    {
        local $| = 1;
        print $$request;
    }
    select $orig;

    my @result = ();
    @result = <$sock>;
    $sock->shutdown(2);
    $sock->close;

    return \join('', @result);
}

sub _getHTTP {
    my $self    =  $_[0];
    my $url     =  $_[1];
    my $request = \$_[2];
    my $isSoap  =  $_[3];

    my $params = $self->{params};

    my $extras  = $params->{requestheader} || '';
    my $ctype   = $params->{contenttype} || '';
    my $timeout = $params->{timeout} || 5; # seconds
    my $charset = 'UTF-8';
    my $basicauth;
    my $length = length($$request);

    if ($url =~ s!^(https?://)([^/\@:]+):([^/\@:]+)\@!$1!) {
        my ($user, $pass) = ($2, $3);
        require MIME::Base64;
        $basicauth = "Basic ".MIME::Base64::encode_base64("$user:$pass");
    }

    my @extras = map {s/^\s+|\s+$//g; $_} split /([\r\n]|\$n)+/, $extras;

    if ($ctype eq '') {
        if ($isSoap) {
            $ctype = 'application/soap+xml';
        } elsif ($$request =~ /^\s*</) {
            $ctype = 'text/xml';
        } else {
            $ctype = 'multipart/form-data';
        }

        $charset = $1 if $$request =~ /\bencoding=["']?([^"']+)["']?/;
        $ctype .= "; charset=$charset";
    }

    my $proxyHost = eval {TWiki::Func::getPreferencesValue('PROXYHOST')} || '';
    my $proxyPort = eval {TWiki::Func::getPreferencesValue('PROXYPORT')} || '';
        # use eval for test environment

    # Set up request
    my $ua = LWP::UserAgent->new(cookie_jar => mkCookieJar());
    $ua->timeout($timeout);

    if ($proxyHost && $proxyPort) {
        $ua->proxy("http", "$proxyHost:$proxyPort");
    }

    my $method = $$request eq '' ? 'GET' : 'POST';
    my $req = HTTP::Request->new($method => $url);
    $req->content($$request);

    if ($$request ne '') {
        $req->header(
            'Content-Type'   => $ctype,
            'Content-Length' => $length
        );
    }

    $req->header(Authorization => $basicauth) if $basicauth;

    for (@extras) {
        $req->header($1 => $2) if /^([^\s:]+)\s*:\s*(.*)$/;
    }

    # Send request and get response
    my $res = $ua->request($req);
    my $status = $res->status_line;

    if ($status =~ /^[45]/) {
        my $msg = "HTTP error: $status (URL=$url)";
        $self->error($msg);
    }

    my $resText = \$res->decoded_content;
    my $resCtype = $res->content_type;
    my $resCharset = 'utf8';
    $resCharset = $1 if $resCtype =~ /;\s*charset=([\-\w]+)/i;

    if ($resCharset =~ /^utf-?8$/i) {
        $resText = \Encode::encode_utf8($$resText);
        # to turn off the UTF-8 flag
    } else {
        $$resText = Encode::encode('utf8', Encode::decode($resCharset, $$resText));
        # to turn off the UTF-8 flag
    }

    return $resText;
}

sub mkCookieJar {
    my $cookieJar;
    if ( $TWiki::cfg{LocalDNSDomain} && $ENV{HTTP_COOKIE} ) {
        require HTTP::Cookies;
        $cookieJar = HTTP::Cookies->new();
        for my $c ( split(/\s*;\s*/, $ENV{HTTP_COOKIE}) ) {
            my ($name, $value) = split(/=/, $c, 2);
            $cookieJar->set_cookie(undef, $name, $value, '/',
                $TWiki::cfg{LocalDNSDomain});
        }
    }
    return $cookieJar;
}

sub getInnerText {
    my ($self, $node) = @_;
    return '' unless defined $node;

    if (ref $node eq 'XML::LibXML::NodeList') {
        $node = $node->shift;
        return '' unless defined $node;
    }

    my $value;

    if ($node->nodeType == XML::LibXML::XML_ELEMENT_NODE) {
        my @children = $node->getChildNodes;

        # Use toString instead of string_value to allow HTML tags to be nested
        # without escape:
        # <xmlTag>This is <i>HTML</i> text inside an <b>XML</b> tag</xmlTag>
        $value = join '', map {$_->toString} @children;
    } else {
        $value = $node->string_value;

        # Since string_value will xml-unescape the value obviously
        # (i.e. an attribute value="&lt;abc&gt;" will be '<abc>'),
        # let's xml-escape the text here, to be in line with the above toString results.
        $value = $self->escapeXML($value);
    }

    # Escape characters that may break markups
    $value = $self->escapeValue($value);

    return Encode::encode_utf8($value);
    # LibXML always returns a text with the utf8 flag turned on, which should be disabled.
}

sub _normalizeFieldHeader {
    my ($self, $col) = @_;
#    $col =~ s/@//g;
#    $col = uc $col;
#    $col =~ s/^[^A-Z]*|[^0-9A-Z]*$//g;
#    $col =~ s/[^0-9A-Z]+/_/g;
    return $col;
}

# (see TWiki::Render)
my $STARTWW = qr/^|(?<=[\s\(])/m;
my $ENDWW = qr/$|(?=[\s,.;:!?)])/m;

sub _encodeEntities {
    my ($text) = @_;
    return join('', map {'&#'.ord($_).';'} split(//, $text));
}

sub escapeValue {
    my ($self, $text) = @_;
    my $params = $self->{params};

    my $is_raw_xml = defined $params->{raw} && $params->{raw} =~ /^xml$/i;
    my $is_raw = $is_raw_xml || TWiki::isTrue($params->{raw}, 0);
    my $is_html = TWiki::isTrue($params->{html}, $is_raw_xml ? 0 : 1);
    my $is_tml = TWiki::isTrue($params->{tml}, $is_raw ? 1 : 0);

    if ($is_html) {
        # Un-escape HTML/XML
        $text = decode_entities($text);
    }

    if (!$is_raw) {
        if ($is_html) {
            # Strip leading and trailing spaces (which would affect alignment in table cells)
            $text =~ s/^\s+|\s+$//g;

            # HTML (copied from TWiki::mkTableSafe)
            my $preLevel = 0;
            my $result = '';
            for my $chunk ( split(m:(\s*</?pre\s*>\r?\n?):i, $text) ) {
                if ( $chunk =~ m:<pre\s*>:i ) {
                    $preLevel++;
                    $chunk = "<pre>";
                }
                elsif ( $chunk =~ m:</pre\s*>:i ) {
                    $preLevel--;
                    $chunk = "</pre>";
                }
                else {
                    if ( $preLevel ) {
                        $chunk =~ s:\r?\n:<br/>:g;
                    }
                    else {
                        $chunk =~ s/\r\n/\n/g;
                        $chunk =~ s:\n\n:<p/>:g;
                        $chunk =~ s/\n/ /g;
                    }
                }
                $result .= $chunk;
            }
            $text = $result;
        } else {
            # Pre-formated text (use white-spaces and newlines as they look like)
            # The text could contain embedded HTML.
            $text = $self->_untabifyLines($text);
            $text =~ s{\r?\n}{<br/>}g;
            $text =~ s/(\s{2,}|^\s|\s$)/('&nbsp;' x length($1))/eg;
        }
    }

    if (!$is_tml) {
        # Escape everything
#        $text =~ s/([\%\$!\|\[\]=_\*\-\.\d:])/'&#'.ord($1).';'/ge;

        # Escape %MACRO%, $variable, *bold*, [[link]]
        $text =~ s/([\%\$!\|\[\]])/'&#'.ord($1).';'/ge;

        # Escape inline TML (see TWiki::Render)
        $text =~ s/(${STARTWW})(==)(\S+?|\S[^\n]*?\S)(==)($ENDWW)/$1._encodeEntities($2).$3._encodeEntities($4).$5/gme;
        $text =~ s/(${STARTWW})(__)(\S+?|\S[^\n]*?\S)(__)($ENDWW)/$1._encodeEntities($2).$3._encodeEntities($4).$5/gme;
        $text =~ s/(${STARTWW})(=)(\S+?|\S[^\n]*?\S)(=)($ENDWW)/$1.('&#'.ord($2).';').$3.('&#'.ord($4).';').$5/gme;
        $text =~ s/(${STARTWW})(_)(\S+?|\S[^\n]*?\S)(_)($ENDWW)/$1.('&#'.ord($2).';').$3.('&#'.ord($4).';').$5/gme;
        $text =~ s/(${STARTWW})(\*)(\S+?|\S[^\n]*?\S)(\*)($ENDWW)/$1.('&#'.ord($2).';').$3.('&#'.ord($4).';').$5/gme;

        # Escape line-oriented TML
        # raw only, because the assumption is that non-raw texts are used between the table bars: "| text |"
        if ($is_raw) {
            $text =~ s/^(\s*)(---|#)/$1._encodeEntities($2)/gme;
            $text =~ s/^((?:\t|   )+)([1AaIi])(\.)/$1._encodeEntities($2).$3/gme;
            $text =~ s/^((?:\t|   )+)(\d+)(\.?)/$1._encodeEntities($2).$3/gme;
            $text =~ s/^((?:\t|   )+)(\$)(\s(?:[^:]+|:[^\s]+)+?:\s)/$1.('&#'.ord($2).';').$3/gme;
            $text =~ s/^((?:\t|   )+\S+?)(:)(\s)/$1.('&#'.ord($2).';').$3/gme;
            $text =~ s/^((?:\t|   )+)(\*)(\s)/$1.('&#'.ord($2).';').$3/gme;
        }
    } else {
        if (!$is_raw) {
            $text =~ s/\|/&#124;/g;
        }
    }

    return $text;
}

sub _untabifyLines {
    my ($self, $lines) = @_;
    my $tabwidth = $self->{params}{tabwidth} || 8;

    my $convert = sub {
        my ($prefix) = @_;
        my $len = length($prefix);
        return $prefix.(' ' x ($tabwidth - $len % $tabwidth));
    };

    my @result = ();

    while ($lines =~ /(.*?(\r?\n|$))/g) {
        my $line = $1;
        $line =~ s/([^\t]*)\t/&$convert($1)/ge;
        push @result, $line;
    }

    return join('', @result);
}

sub applyFormat {
    my ($self, $format, $values, $varmap) = @_;
    $varmap ||= {};

    my @values = @$values;

    my $conv = sub {
        my ($var) = @_;
        my $name = $var;
        $name =~ s/^\$//;
        $name =~ s/^\{|\}$//g;

        if ($name =~ /^\d+$/) {
            return $values[$name - 1] if defined $values[$name - 1];
        } elsif (defined $varmap->{$name}) {
            my $n = $varmap->{$name};
            return $values[$n] if defined $values[$n];
        }

        return $var;
    };

    if (defined $format) {
        my $result = $format;
        $result =~ s/(\$(\d+|[A-Za-z_][A-Za-z_0-9]*|\{.*?\}))/&$conv($1)/ge;
        $result = TWiki::expandStandardEscapes($result);
        return $result;
    } else {
        return '| '.join(' | ', @values)." |";
    }
}

1;
