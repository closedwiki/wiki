use strict;
package TWiki::Plugins::JiraPlugin::Client;

use TWiki::Plugins::JiraPlugin::Field;

use Encode;
use LWP::UserAgent;
use URI::Escape;
use XML::LibXML;
use XML::LibXML::XPathContext;

sub new {
    my ($class, %params) = @_;
    
    return bless {
        cache => {},
        %params,
    }, $class;
}

sub _makeField {
    return TWiki::Plugins::JiraPlugin::Field->new(@_);
}

sub _getNodeValue {
    my ($node) = @_;
    # Turn off UTF-8 flags
    return Encode::encode_utf8($node->string_value);
}

sub checkField {
    my ($self, $field) = @_;
    my $canonical = $field->canonical;
    
    unless ($self->{all}{seen}{$canonical}) {
        push @{$self->{all}{fields}}, $field;
        $self->{all}{seen}{$canonical} = 1;
    }
}

sub getIssuesFromJqlSearch {
    my ($self, $jql, $limit) = @_;
    
    my $urlprefix = $self->{urlprefix};
    my $timeout   = $self->{timeout};
    
    my %urlparams = (issuekey => 1);
    my $require_all = 0;
    
    for my $field (@{$self->{fields}}) {
        if ($field->urlparam) {
            $urlparams{$field->urlparam} = 1;
        } elsif (lc $field->name eq 'all') {
            $require_all = 1;
        }
    }
    
    my $url = "$urlprefix/sr/jira.issueviews:searchrequest-xml/temp/SearchRequest.xml".
        '?jqlQuery='.uri_escape($jql).
        '&tempMax='.uri_escape($limit);
    
    unless ($require_all) {
        $url .= join('', map {'&field='.uri_escape($_)} keys %urlparams);
    }
    
    my $ua = LWP::UserAgent->new(
        cookie_jar => mkCookieJar(), timeout => $timeout,
    );
    
    my $res = $ua->get($url);
    
    unless ($res->is_success) {
        die $res->message;
    }
    
    return $self->parseXML($res->content);
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

sub parseXML {
    my ($self, $xml) = @_;
    
    my $dom = XML::LibXML->load_xml(string => $xml);
    my $xpc = XML::LibXML::XPathContext->new($dom);
    
    my @issues = ();
    
    for my $item ($xpc->findnodes('/rss/channel/item')) {
        my $issue = bless {
            (map {
                $_->canonical => undef
            } grep {$_->canonical} @{$self->{fields}}),
        }, 'RemoteIssue';
        
        for my $node ($item->childNodes) {
            next if $node->nodeType != XML::LibXML::XML_ELEMENT_NODE;
            
            my $field = _makeField($node->nodeName);
            next unless $field->canonical || $field->name eq 'customfields';
            
            my $canonical = $field->canonical;
            
            if ($field->name eq 'customfields') {
                $issue->{customFieldValues} ||= [];
                
                for my $fnode ($node->findnodes('./customfield')) {
                    my $id = _getNodeValue($fnode->find('@id'));
                    my $key = _getNodeValue($fnode->find('@key'));
                    my $name = _getNodeValue($fnode->find('./customfieldname'));
                    
                    $self->checkField(_makeField($id));
                    
                    my @values = ();
                    
                    # Case 1:
                    # <customfieldvalues>
                    #   <customfieldvalue>value 1</customfieldvalue>
                    #   <customfieldvalue>value 2</customfieldvalue>
                    # </customfieldvalues>
                    # 
                    # Case 2:
                    # <customfieldvalues>
                    #   <label>label 1</label>
                    #   <label>label 2</label>
                    # </customfieldvalues>
                    for my $vnode ($fnode->findnodes('./customfieldvalues/*')) {
                        push @values, _getNodeValue($vnode);
                    }
                    
                    # Case 3:
                    # <customfieldvalues>35 minutes ago</customfieldvalues>
                    if (@values == 0) {
                        for my $vnode ($fnode->findnodes('./customfieldvalues/text()')) {
                            my $text = _getNodeValue($vnode);
                            $text =~ s/^\s+|\s+$//g;
                            
                            if ($text ne '') {
                                push @values, $text;
                            }
                        }
                    }
                    
                    push @{$issue->{customFieldValues}}, bless({
                        customfieldId => $id,
                        customfieldName => $name,
                        values => \@values,
                        key => $key,
                    }, 'RemoteCustomFieldValue');
                }
            } else {
                $self->checkField($field);
                
                if ($canonical eq 'project') {
                    $issue->{$canonical} = _getNodeValue($node->find('@key'));
                } elsif ($canonical eq 'key') {
                    $issue->{$canonical} = _getNodeValue($node);
                    $issue->{id} = _getNodeValue($node->find('@id'));
                    $self->checkField(_makeField('id'));
                } elsif ($canonical =~ /^(summary|description|environment|votes)$/) {
                    $issue->{$canonical} = _getNodeValue($node);
                } elsif ($canonical =~ /^(created|updated|resolved|duedate)$/) {
                    $issue->{$canonical} = _getNodeValue($node);
                } elsif ($canonical =~ /^(reporter|assignee)$/) {
                    my $username = _getNodeValue($node->find('@username'));
                    my $fullname = _getNodeValue($node);
                    $self->{cache}{user} ||= {};
                    $self->{cache}{user}{$username} = $fullname;
                    $issue->{$canonical} = $username;
                } elsif ($canonical =~ /^(type|status|priority|resolution)$/) {
                    my $id = _getNodeValue($node->find('@id'));
                    my $icon = _getNodeValue($node->find('@iconUrl'));
                    my $name = _getNodeValue($node);
                    $self->{cache}{$canonical} ||= {};
                    $self->{cache}{$canonical}{$id} = [$icon, $name];
                    $issue->{$canonical} = $id;
                } elsif ($canonical =~ /^(fixVersion|(?:affects)?Version|label|component|attachment)(s?)$/i) {
                    my $s = $2;
                    $issue->{$canonical} ||= [];
                    
                    if ($node->nodeName =~ /s$/) {
                        for my $child ($node->childNodes) {
                            next if $child->nodeType != XML::LibXML::XML_ELEMENT_NODE;
                            
                            my $value = _getNodeValue($canonical eq 'attachmentNames' ?
                                    $child->find('@name') : $child);
                            
                            push @{$issue->{$canonical}}, $value;
                        }
                    } else {
                        my $value = _getNodeValue($canonical eq 'attachmentNames' ?
                                $node->find('@name') : $node);
                        
                        push @{$issue->{$canonical}}, $value;
                    }
                } elsif ($canonical =~ /^(aggregate)?Time(Spent|(Original)?Estimate)$/i) {
                    $issue->{$canonical} = _getNodeValue($node);
                    # TODO: $node->find('@seconds')
                }
            }
        }

        push @issues, $issue;
    }
    
    return \@issues;
}

1;
