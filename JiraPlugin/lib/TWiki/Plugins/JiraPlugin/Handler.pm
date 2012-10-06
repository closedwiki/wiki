# Module for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2012 TWiki:Main.MahiroAndo
# Copyright (C) 2012 TWiki Contributors
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# For licensing info read LICENSE file in the TWiki root.

use strict;
package TWiki::Plugins::JiraPlugin::Handler;

use TWiki::Func;
use TWiki::Plugins::JiraPlugin::Client;
use TWiki::Plugins::JiraPlugin::Field;

use Date::Parse;
use DateTime;
use HTTP::Cookies;
use LWP::UserAgent;
use POSIX;
use Sort::Versions;

sub new {
    my ($class, $session, $params, $theTopic, $theWeb) = @_;
    my $self;
    
    my $urlprefix = $params->{_DEFAULT} or die "default parameter must be specified";
    $urlprefix =~ s{/+$}{};
    my $inst = $urlprefix;
    
    my $jql = $params->{jql} or die "jql must be specified";
    $jql =~ s/[\r\n]+/ /g;
    my $timeout = $params->{timeout} || 20;
    
    my $use_icons = TWiki::Func::isTrue($params->{icons}, 1);
    my $use_gmt = TWiki::Func::isTrue($params->{gmt}, 0);
    
    my $dateformat = $params->{dateformat};
    
    # Group-by
    my $groupby;
    
    if (defined $params->{groupby}) {
        my ($field, $sort) = getParamValues($params->{groupby}, 1);
        $sort = lc $sort;
        
        if ($sort ne '' && $sort ne 'asc' && $sort ne 'desc') {
            die "invalid groupby: $params->{groupby}";
        }
        
        $groupby = {field => _makeField($field), sort => $sort};
    }
    
    # Collect necessary fields
    my @fields = ();
    
    if (defined $params->{fields}) {
        @fields = map {_makeField($_)} getParamValues($params->{fields});
    }
    
    my @additional_fields = ();
    
    if ($groupby) {
        push @additional_fields, $groupby->{field};
    }
    
    for my $param (qw(header format footer separator),
            ($groupby ? qw(groupheader groupfooter groupseparator) : ())) {
        if (defined $params->{$param}) {
            while ($params->{$param} =~ /(\$(\w+|\{.*?\}))/g) {
                push @additional_fields, _makeField($1);
            }
        }
    }
    
    if (@fields == 0) {
		@fields = map {_makeField($_)} qw(type key assignee summary status priority);
    }

    
    # All other headers (for fields="all")
    my $all = {
        fields => [],
        seen => {map {$_->canonical => 1} grep {$_->canonical} @fields},
    };
    
    # Special
    my $special = {
        inst => $inst,
        urlprefix => $urlprefix,
        header => sub {
            if (@{$self->{fields}}) {
                return '| *'.join('* | *', map {ucfirst($_->name)} @{$self->{fields}}).'* |';
            } else {
                return '';
            }
        },
        all => sub {
            if (@{$self->{all}{fields}}) {
                return '| *'.join('* | *', map {ucfirst($_->name)} @{$self->{all}{fields}}).'* |';
            } else {
                return '';
            }
        },
    };
    
    # JIRA Client
    my $jira = TWiki::Plugins::JiraPlugin::Client->new(
        urlprefix => $urlprefix,
        fields => [@fields, @additional_fields],
        timeout => $timeout,
        all => $all,
    );
    
    my $token = $session->{remoteUser};
    
    # Log all the requests for troubleshooting
    if ($self->{logging}) {
        TWiki::Func::writeDebug(qq($theWeb.$theTopic \%JIRA{$params->{_RAW}}\%));
    }
    
    $self = bless {
        session    => $session,
        params     => $params,
        topic      => $theTopic,
        web        => $theWeb,
        
        jira       => $jira,
        token      => $token,
        jql        => $jql,
        timeout    => $timeout,
        dateformat => $dateformat,
        use_gmt    => $use_gmt,
        
        fields     => \@fields,
        all        => $all,
        groupby    => $groupby,
        special    => $special,
        use_icons  => $use_icons,

        logging    => 0,
    }, $class;
    
    return $self;
}

sub logging {
    my $self = shift;

    if (@_) {
        my $orig = $self->{logging};
        $self->{logging} = shift;
        return $orig;
    } else {
        return $self->{logging};
    }
}

sub generate {
    my ($self) = @_;
    my $params = $self->{params};

    my $result = '';
    my $warn = TWiki::Func::isTrue($params->{warn}, 1);
    
    my $limit = int($params->{limit} || 10);
    my $grouplimit = int($params->{grouplimit} || 0);
    
    my $special = $self->{special};
    
    my $jira_issues = $self->getIssuesFromJqlSearch($self->{jql}, $limit);
    
    my @issue_groups = ();
    
    if ($self->{groupby}) {
        @issue_groups = $self->groupIssues($jira_issues, $self->{groupby}, $grouplimit);
    } else {
        push @issue_groups, {group => {}, issues => $jira_issues};
    }
    
    my @outer_result = ();
    
	# Separator
    my $default_separator = "\n";
    
    if (defined $params->{format} && $params->{format} =~ /\$n\s*$/) {
        $default_separator = '';
    }
    
    my $separator = $default_separator;
    
    if (defined $params->{separator}) {
        $separator = $self->applyFormat($params->{separator}, {});
    }
    
	# Header
    if (defined $params->{header}) {
        push @outer_result, $self->applyFormat($params->{header}, {});
    } elsif (!defined $params->{format} and !defined $params->{groupheader}) {
        push @outer_result, $self->getSpecialValue(_makeField('header'));
    }
    
	# Body
    for my $issue_group (@issue_groups) {
        my $group = $issue_group->{group};
        my $issues = $issue_group->{issues};
        my @inner_result = ();
        
        if ($self->{groupby} && defined $params->{groupheader}) {
            push @inner_result, $self->applyFormat($params->{groupheader}, $group);
        }

        for my $issue (@$issues) {
            if (defined $params->{format}) {
                push @inner_result, $self->applyFormat($params->{format}, $issue);
            } else {
                push @inner_result, $self->getIssueValue($issue, _makeField('row'));
            }
        }

        if ($self->{groupby} && defined $params->{groupfooter}) {
            push @inner_result, $self->applyFormat($params->{groupfooter}, $group);
        }
        
        if ($self->{groupby}) {
            my $inner_separator = $default_separator;
            
            if (defined $params->{separator}) {
                $inner_separator = $self->applyFormat($params->{separator}, $group);
            }
            
            push @outer_result, join($inner_separator, @inner_result);
        } else {
            push @outer_result, join($separator, @inner_result);
        }
    }
    
	# Footer
    if (defined $params->{footer}) {
        push @outer_result, $self->applyFormat($params->{footer}, {});
    }
    
	# Combine results
    if ($self->{groupby}) {
        my $groupseparator = $default_separator;
        
        if (defined $params->{groupseparator}) {
            $groupseparator = $self->applyFormat($params->{groupseparator}, {});
        }
        
        $result = join($groupseparator, @outer_result);
    } else {
        $result = join($separator, @outer_result);
    }
    
    return $result;
}

sub _makeField {
    return TWiki::Plugins::JiraPlugin::Field->new(@_);
}

sub getIssuesFromJqlSearch {
    my ($self, $jql, $limit) = @_;
    my $special = $self->{special};
    
    my $issues = $self->{jira}->getIssuesFromJqlSearch($jql, $limit);
    
    # Set _SPECIAL and _CUSTOM
    for my $issue (@$issues) {
        $issue->{_SPECIAL} = {};
        $issue->{_SPECIAL}{url} = $special->{urlprefix}."/browse/".$issue->{key};
        
        if (@{$self->{fields}}) {
            $issue->{_SPECIAL}{row} = sub {
                '| '.join(' | ', map {$self->formatValue($issue, $_)} @{$self->{fields}}).' |'
            };
        } else {
            $issue->{_SPECIAL}{row} = '';
        }
        
        $issue->{_SPECIAL}{all} = sub {
            '| '.join(' | ', map {$self->formatValue($issue, $_)} @{$self->{all}{fields}}).' |'
        };
        
        $issue->{_CUSTOM} = {};
        
        if (exists $issue->{customFieldValues}) {
            for my $custom (@{$issue->{customFieldValues}}) {
                my $custom_id = $custom->{customfieldId};
                my $custom_key = $custom->{key};
                
                my $custom_name = defined $custom->{customfieldName} ?
                        $custom->{customfieldName} : $custom->{name};
                
                my $custom_values = $custom->{values};
                
                $issue->{lc $custom_id} = $custom_values if defined $custom_id;
                $issue->{_CUSTOM}{lc $custom_key} = $custom_values if defined $custom_key;
                $issue->{_CUSTOM}{lc $custom_name} = $custom_values if defined $custom_name;
            }
        }
    }
    
    # Process all fields (for fields="all")
    for my $issue (@$issues) {
        for my $canonical (keys %$issue) {
            unless ($self->{all}{seen}{$canonical}) {
                my $field = _makeField($canonical);
                
                if ($field->canonical) {
                    push @{$self->{all}{fields}}, $field;
                    $self->{all}{seen}{$canonical} = 1;
                }
            }
        }
        
        if (exists $issue->{customFieldValues}) {
            for my $custom (@{$issue->{customFieldValues}}) {
                my $custom_id = $custom->{customfieldId};
                
                unless ($self->{all}{seen}{$custom_id}) {
                    push @{$self->{all}{fields}}, _makeField($custom_id);
                    $self->{all}{seen}{$custom_id} = 1;
                }
            }
        }
    }
    
    # Convert 'all' in fields
    $self->{fields} = [map {
        $_->name eq 'all' ? (@{$self->{all}{fields}}) : ($_)
    } @{$self->{fields}}];
    
    return $issues;
}

sub getSpecialValue {
    my ($self, $field) = @_;
    my $special = $self->{special};
    my $name = lc $field->name;
    my $value;
    
    if (exists $special->{$name}) {
        $value = $special->{$name};
        
        if (defined $value && ref($value) eq 'CODE') {
            $value = &$value();
        }
    }
    
    return $value;
}

sub getIssueValue {
    my ($self, $issue, $field) = @_;
    my $value = undef;
    
    if ($field->canonical) {
        $value = $issue->{$field->canonical};
    } else {
        my $name = lc $field->name;
        
        for my $key (qw(_SPECIAL _CUSTOM)) {
            if (exists $issue->{$key}{$name}) {
                $value = $issue->{$key}{$name};
                
                if (defined $value && ref($value) eq 'CODE') {
                    $value = &$value();
                }
                
                last;
            }
        }
    }
    
    return $value;
}

sub groupIssues {
    my ($self, $jira_issues, $groupby, $grouplimit) = @_;
    my $field = $groupby->{field};
    my $sort = $groupby->{sort};

    my @issue_groups = (); # result
    
    my @value_list = ();
    my %map = ();
    my $is_ver = $field->canonical && $field->canonical =~ /^(fix|affects)Versions$/;
    my $is_num = 1;
    
    my $add_value = sub {
        my ($issue, $value) = @_;
        
        if (ref $value) {
            if (ref($value) =~ /^Remote/ && exists $value->{name}) {
                $value = $value->{name};
            }
        }
        
        if (exists $map{$value}) {
            return 0 if $grouplimit > 0 && @{$map{$value}} >= $grouplimit;
        } else {
            $map{$value} = [];
            push @value_list, $value;
        }
        
        push @{$map{$value}}, $issue;
        $is_num = 0 unless $value =~ /^\-?(\d*\.)?\d+$/;
        return 1;
    };
    
    my $groupdefault = $self->{params}{groupdefault};
    
    for my $issue (@$jira_issues) {
        my $value = $self->getIssueValue($issue, $field);
        
        if (defined $value && ref $value eq 'ARRAY') {
            my @values = @$value;
            
            if (defined $groupdefault) {
                @values = map {(defined $_ && $_ ne '') ? $_ : $groupdefault} @values;
                push @values, $groupdefault if @values == 0;
            } else {
                @values = grep {defined $_ && $_ ne ''} @values;
            }
            
            my %seen = ();
            
            for my $item (@values) {
                if (!$seen{$item}) {
                    &$add_value($issue, $item) or next;
                    $seen{$item} = 1;
                }
            }
        } else {
            if (defined $value) {
                &$add_value($issue, $value) or next;
            } elsif (defined $groupdefault) {
                &$add_value($issue, $groupdefault) or next;
            }
        }
    }
    
    if ($sort =~ /^(asc|desc)$/) {
        if ($is_ver) {
            @value_list = sort {versioncmp($a, $b)} @value_list;
        } elsif ($is_num) {
            @value_list = sort {$a <=> $b} @value_list;
        } else {
            @value_list = sort {$a cmp $b} @value_list;
        }
        
        if ($sort eq 'desc') {
            @value_list = reverse @value_list;
        }
    }
    
    for my $value (@value_list) {
        my $group = {};
        
        if ($field->canonical) {
            $group->{$field->canonical} = $value;
        } else {
            $group->{_CUSTOM} = {lc $field->name => $value};
        }
        
        push @issue_groups, {group => $group, issues => $map{$value}};
    }

    return @issue_groups;
}

sub applyFormat {
    my ($self, $format, $issue) = @_;
    my $special = $self->{special};
    
    my $conv = sub {
        my ($var) = @_;
        my $field = _makeField($var);
        my $name = lc $field->name;
        my $value;
        
        if (exists $issue->{_SPECIAL}{$name}) {
            return $self->getIssueValue($issue, $field); # Do not escape HTML/TML
        } elsif (exists $special->{$name}) {
            return $self->getSpecialValue($field); # Do not escape HTML/TML
        } else {
            return $self->formatValue($issue, $field);
        }
    };
    
    my $result = $format;
    $result = TWiki::expandStandardEscapes($result);
    $result =~ s/(\$(\w+|\{.*?\}))/&$conv($1)/ge;
    return $result;
}

sub getParamValues {
    my ($value, $space_separated) = @_;
    my $sep = $space_separated ? '[,\s]+' : '\s*,\s*';
    return grep {$_ ne ''} map {s/^\s*|\s*$//g; $_} split /$sep/, $value;
}

# (see TWiki::Render)
my $STARTWW = qr/^|(?<=[\s\(])/m;
my $ENDWW = qr/$|(?=[\s,.;:!?)])/m;

sub normalizeText {
    my ($self, $text, $is_html) = @_;

    if (ref $text) {
        if (ref($text) =~ /^Remote/ && exists $text->{name}) {
            $text = $text->{name};
        }
    }

    # Escape HTML
    if ($is_html) {
        $text =~ s{\r?\n}{ }g;
    } else {
        $text =~ s/&(#\d+|\w+);/&amp;$1;/g;
        $text =~ s/</&lt;/g;
        $text =~ s/>/&gt;/g;
        $text =~ s/\"/&quot;/g; # "
        $text =~ s/\'/&#39;/g; # '

        # Honor spaces
        $text = _untabifyLines($text);
        $text =~ s{\r?\n}{<br/>}g;
        $text =~ s/(\s{2,})/('&nbsp;' x length($1))/eg;
    }

    # Escape %MACRO%, $variable, *bold*, [[link]]
    $text =~ s/([\%\$!\|\[\]])/'&#'.ord($1).';'/ge;

    # Escape inline TML (see TWiki::Render)
    $text =~ s/(${STARTWW})(==)(\S+?|\S[^\n]*?\S)(==)($ENDWW)/$1._encodeEntities($2).$3._encodeEntities($4).$5/gme;
    $text =~ s/(${STARTWW})(__)(\S+?|\S[^\n]*?\S)(__)($ENDWW)/$1._encodeEntities($2).$3._encodeEntities($4).$5/gme;
    $text =~ s/(${STARTWW})(=)(\S+?|\S[^\n]*?\S)(=)($ENDWW)/$1.('&#'.ord($2).';').$3.('&#'.ord($4).';').$5/gme;
    $text =~ s/(${STARTWW})(_)(\S+?|\S[^\n]*?\S)(_)($ENDWW)/$1.('&#'.ord($2).';').$3.('&#'.ord($4).';').$5/gme;
    $text =~ s/(${STARTWW})(\*)(\S+?|\S[^\n]*?\S)(\*)($ENDWW)/$1.('&#'.ord($2).';').$3.('&#'.ord($4).';').$5/gme;

    # Escape line-oriented TML
    $text =~ s/^(\s*)(---|#)/$1._encodeEntities($2)/gme;
    $text =~ s/^((?:\t|   )+)([1AaIi])(\.)/$1._encodeEntities($2).$3/gme;
    $text =~ s/^((?:\t|   )+)(\d+)(\.?)/$1._encodeEntities($2).$3/gme;
    $text =~ s/^((?:\t|   )+)(\$)(\s(?:[^:]+|:[^\s]+)+?:\s)/$1.('&#'.ord($2).';').$3/gme;
    $text =~ s/^((?:\t|   )+\S+?)(:)(\s)/$1.('&#'.ord($2).';').$3/gme;
    $text =~ s/^((?:\t|   )+)(\*)(\s)/$1.('&#'.ord($2).';').$3/gme;

    return $text;
}

sub _untabifyLines {
    my ($lines) = @_;
    my $tabwidth = 8;

    my $convert = sub {
        my ($prefix) = @_;
        my $len = length($prefix);
        return $prefix.(' ' x ($tabwidth - $len % $tabwidth));
    };

    my @result = ();

    while ($lines =~ /(.*?(\r?\n|$))/g) {
        my $line = $1;
        $line =~ s/([^\t]*)\t/&$convert($1)/e;
        push @result, $line;
    }

    return join('', @result);
}

sub defaultFormatValue {
    my ($self, $value) = @_;
    
    if (defined $value) {
        if (ref $value eq 'ARRAY') {
            my $itemsep = $self->{params}{itemsep};
            
            if (defined $itemsep) {
                $itemsep = $self->applyFormat($itemsep, {});
            } else {
                $itemsep = ', ';
            }
            
            return join $itemsep, @$value;
        } else {
            return $value;
        }
    } else {
        return '';
    }
}

sub formatIconText {
    my ($self, $value, $icon, $name, $option, $urlprefix) = @_;

    if ($option eq 'text' or $option eq 'name') {
        return qq(<nobr>$name</nobr>);
    } else {
        $icon = "$urlprefix/images/icons/$icon.gif" unless $icon =~ m{^https?://};
        $icon = qq(<img src="$icon" title="$name"/>);

        if ($option eq 'icon') {
            return $icon;
        } elsif ($option eq 'mixed') {
            return "<nobr>$icon $name</nobr>";
        } else {
            return defined $value ? $value : '';
        }
    }
}

sub formatLinkedText {
    my ($self, $href, $text, $option) = @_;

    if ($option eq 'text' or $option eq 'name') {
        return $text;
    } elsif ($option eq 'url' or $option eq 'href') {
        return $href;
    } elsif ($option eq 'mixed') {
        return "[[$href][$text]]";
    } else {
        return $text;
    }
}

sub getUserFullName {
    my ($self, $username) = @_;
    return $self->{jira}{cache}{user}{$username} || $username;
}

sub getCachedIcon {
    my ($self, $field, $value) = @_;
    my $canonical = $field->canonical or return undef;
    return $self->{jira}{cache}{$canonical}{$value} || undef;
}

sub _encodeEntities {
    my ($text) = @_;
    return join('', map {'&#'.ord($_).';'} split(//, $text));
}

sub formatValue {
    my ($self, $issue, $field, $default) = @_;
    my $value = $self->getIssueValue($issue, $field);
    
    unless (defined $value) {
        return defined $default ? $default : '';
    }
    
    if (ref $value eq 'ARRAY') {
        $value = [map {$self->normalizeText($_, $field->is_html)} @$value];
    } else {
        $value = $self->normalizeText($value, $field->is_html);
    }
    
    my $option = $field->option || '';
    
    if (($option eq 'id' or $option eq 'raw') and
            (($field->canonical || '') !~ /^(created|updated|resolved|duedate)$/)) {
        return $self->defaultFormatValue($value);
    }
    
    my $special = $self->{special};
    my $urlprefix = $special->{urlprefix};
    my $inst = $special->{inst};
    
    if ($field->canonical) {
        my $canonical = $field->canonical;
        
        if ($canonical eq 'type') {
            my ($icon, $name) = @{$self->getCachedIcon($field, $value) || ['genericissue', 'Generic']};
            my $default_option = $self->{use_icons} ? 'mixed' : 'text';
            return $self->formatIconText($value, $icon, $name, $option || $default_option, $urlprefix);
        } elsif ($canonical eq 'priority') {
            my ($icon, $name) = @{$self->getCachedIcon($field, $value) || ['priority_trivial', 'Unknown']};
            my $default_option = $self->{use_icons} ? 'mixed' : 'text';
            return $self->formatIconText($value, $icon, $name, $option || $default_option, $urlprefix);
        } elsif ($canonical eq 'status') {
            my ($icon, $name) = @{$self->getCachedIcon($field, $value) || ['status_generic', 'Generic']};
            my $default_option = $self->{use_icons} ? 'mixed' : 'text';
            return $self->formatIconText($value, $icon, $name, $option || $default_option, $urlprefix);
        } elsif ($canonical eq 'resolution') {
            my ($icon, $name) = @{$self->getCachedIcon($field, $value) || [undef, 'Unresolved']};
            return $self->formatIconText($value, $icon, $name, $option || 'text', $urlprefix);
        } elsif ($canonical =~ /^(key|project)$/) {
            my $href = "$urlprefix/browse/$value";
            return '<nobr>'.$self->formatLinkedText($href, $value, $option || 'mixed').'</nobr>';
        } elsif ($canonical eq 'summary') {
            my $href = "$urlprefix/browse/$value";
            return $self->formatLinkedText($href, $value, $option || 'text');
        } elsif ($canonical =~ /^(assignee|reporter)$/) {
            my $href = "$urlprefix/secure/ViewProfile.jspa?name=$value";
            my $text = $self->getUserFullName($value);
            return '<nobr>'.$self->formatLinkedText($href, $text, $option || 'mixed').'</nobr>';
        } elsif ($canonical =~ /^(created|updated|resolved|duedate)$/) {
            my $ts = str2time($value);
            return '' unless defined $ts;
            
            if ($ts =~ /^(\d+)$/) {
                $ts = $1;
                # Clear the tainted flag.
                # Looks like DateTime->from_epoch causes segmentation fault with
                # mod_perl+PerlTaintCheck (but not with just -T option)
                # if the parameter is tainted.
            }
            
            if ($option eq 'ts') {
                return $ts;
            }
            
            my $fmt = '%d/%b/%Y'; # Jira's default format
            
            my $dt = DateTime->from_epoch(epoch => $ts);
            
            if ($option eq 'id' or $option eq 'raw') {
                $fmt = '%Y-%m-%dT%H:%M:%S.000Z';
            } else {
                unless ($self->{use_gmt}) {
                    if ($value =~ /([\-\+]\d{4})$/) {
                        $dt->set_time_zone($1);
                    }
                }
                
                if ($option eq 'long') {
                    $fmt = '%Y-%m-%d %H:%M %Z';
                } elsif ($option eq 'full') {
                    $fmt = '%Y-%m-%d %H:%M:%S %Z';
                } elsif (defined $self->{dateformat}) {
                    $fmt = $self->{dateformat};
                    $fmt = TWiki::expandStandardEscapes($fmt);
                    $fmt =~ s/\$/\%/g;
                }
            }
            
            return '<nobr>'.$dt->strftime($fmt).'</nobr>';
        }
    }
    
    return $self->defaultFormatValue($value);
}

1;
