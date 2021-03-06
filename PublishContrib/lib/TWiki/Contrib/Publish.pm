#
#  Publish site (generate static HTML)
#
#  Based on GenHTMLPlugin
#  Copyright (C) 2001 Motorola
#
#  Revisions Copyright (C) 2002, Eric Scouten
#  Cairo updates Copyright (C) 2004 Crawford Currie http://c-dot.co.uk
#
# TWiki WikiClone (see TWiki.pm for $wikiversion and other info)
#
# Copyright (C) 2001 Peter Thoeny, Peter@Thoeny.com
# Copyright (C) 2001-2007 Sven Dowideit, svenud@ozemail.com.au
# Copyright (C) 2001 Motorola Ltd.
# Copyright (C) 2005-2008 Crawford Currie, http://c-dot.co.uk
# Copyright (C) 2006 Martin Cleaver, http://www.cleaver.org
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html
#

package TWiki::Contrib::Publish;

use TWiki;
use TWiki::Func;
use Error qw( :try );

use strict;

use vars qw( $VERSION $RELEASE );

$VERSION = '$Rev$';

my $debug = 0;

$RELEASE = 'TWiki-4';

sub publish {
    my $session = shift;

    my $publisher = new TWiki::Contrib::Publish($session);

    $TWiki::Plugins::SESSION = $session;

    my $query = TWiki::Func::getCgiQuery();
    if (defined $query->param('control')) {
        $publisher->control();
    } else {
        my $web = $query->param( 'web' ) || $session->{webName};
        $query->delete('web');
        $web =~ m#([\w/.]*)#; # clean up and untaint

        $publisher->publishWeb($1);
    }
    $publisher->finish();
}

sub new {
    my ($class, $session) = @_;

    unless ( defined $TWiki::cfg{PublishContrib}{Dir} ) {
        die "{PublishContrib}{Dir} not defined; run install script";
    }
#    unless( -d $TWiki::cfg{PublishContrib}{Dir}) {
#        die "{PublishContrib}{Dir} $TWiki::cfg{PublishContrib}{Dir} does not exist";
#    }
    unless ( $TWiki::cfg{PublishContrib}{Dir} =~ m!/$!) {
        die "{PublishContrib}{Dir} must terminate in a slash";
    }
    unless ($TWiki::cfg{PublishContrib}{URL}) {
        die "Can't publish because {PublishContrib}{URL} was not set. Please notify your TWiki administrator";
    }
    if ( ! -d $TWiki::cfg{PublishContrib}{Dir} &&
           ! -e $TWiki::cfg{PublishContrib}{Dir}) {
        mkdir($TWiki::cfg{PublishContrib}{Dir}, 0777);
    }
    unless (-d $TWiki::cfg{PublishContrib}{Dir} &&
              -w $TWiki::cfg{PublishContrib}{Dir}) {
        die "Can't publish because no useable {PublishContrib}{Dir} was found. Please notify your TWiki administrator";
    }

    my $this = bless({}, $class);
    $this->{session} = $session;
    $this->{templatesWanted} = 'view';
    # used to prefix alternate template renderings
    $this->{templateLocation} = '';
    # this records which templates (e.g. view, viewprint, viuehandheld,
    # etc) have been referred to and thus should be generated.
    $this->{templatesReferenced} = {};
    $this->{historyTopic} = 'PublishContribHistory';
    $this->{inclusions} = '.*';
    $this->{exclusions} = '';
    $this->{topicFilter} = '';
    return $this;
}

sub finish {
    my $this = shift;
    $this->{session} = undef;
}

sub _display {
    my $msg = join('', @_);
    if (defined $TWiki::Plugins::SESSION->{response} &&
          defined &TWiki::Response::appendToBody &&
          !TWiki::Func::getContext()->{command_line}) {
        $TWiki::Plugins::SESSION->{response}->appendToBody($msg);
    } else {
        print $msg;
    }
}

# Allow manipulation of $TWiki::cfg{PublishContrib}{Dir}
sub control {
    my $this = shift;

    my ($header, $footer) = $this->_getPageTemplate();
    _display "content-type: text/html; charset=UTF-8\n\n";
    _display $header;
    _display CGI::p(<<HERE);
<h1>Publishers Control Interface</h1>
This interface lets you perform basic management operations
on published output files and directories. Click on the name of the
output file to visit it.
HERE
    my $query = TWiki::Func::getCgiQuery();
    my $action = $query->param('action') || '';
    $query->delete('action'); # delete so we can redefine them
    my $file = $query->param('file');
    $query->delete('file');

    if ($action eq 'delete') {
        $file =~ m#([\w./\\]+)#; # untaint
        File::Path::rmtree("$TWiki::cfg{PublishContrib}{Dir}/$1");
        _display $query->p("$1 deleted");
    }
    if (opendir(D, $TWiki::cfg{PublishContrib}{Dir})) {
        my @files = grep(!/^\./, readdir(D));
        if (scalar(@files)) {
            _display "<table>";
            foreach my $file (@files) {
                my $link = "$TWiki::cfg{PublishContrib}{URL}/$file";
                $link = "<a href=\"$link\">$file</a>";
                my @cols = "<th>$link</th>";
                my $delcol = "<form action='' method='GET' name='$file'>";
                $delcol .= "<input type='button' name='delete' />";
                $delcol .= "<input type='hidden' name='file' value='$file' />";
                $delcol .= "<input type='hidden' name='action' value='delete' />";
                $delcol .= "<input type='hidden' name='control' value='1' />";
                $delcol .= "<input type='hidden' name='skin' />";
                $delcol .= "</form>";
                push(@cols, $delcol);
                _display "<tr valign='baseline'>" .
                         join('', map {"<td>$_</td>"} @cols) .
                         "</tr>";
            }
            _display "</table>";
        } else {
            _display "The output directory is currently empty";
        }
    } else {
        _display "Failed to open '$TWiki::cfg{PublishContrib}{Dir}': $!";
    }
    _display $footer;
}

sub publishWeb {
    my ($this, $web) = @_;

    $this->{publisher} = TWiki::Func::getWikiName();
    $this->{web} = $web;

    #don't add extra markup for topics we're not linking too
    # NEWTOPICLINKSYMBOL LINKTOOLTIPINFO
    if (defined $TWiki::Plugins::SESSION->{renderer}) {
        $TWiki::Plugins::SESSION->{renderer}->{NEWLINKSYMBOL} = '';
    } else {
        $TWiki::Plugins::SESSION->renderer()->{NEWLINKSYMBOL} = '';
    }

    my $skin = '';
    my $format = 'file';
    my $genopt = '';

    my $query = TWiki::Func::getCgiQuery();
    die "No query" unless $query;
    my $configtopic = $query->param('configtopic');

    my $versionsTopic;
    if (defined $configtopic) {
        $query->delete('configtopic');
        # Parameters are defined in config topic
        my ($cw, $ct) = TWiki::Func::normalizeWebTopicName(
            $this->{web}, $configtopic);
        unless( TWiki::Func::topicExists($cw, $ct) ) {
            die "Specified configuration topic $cw.$ct does not exist!\n";
        }
        my ($cfgm, $cfgt) = TWiki::Func::readTopic($cw, $ct);
        unless( TWiki::Func::checkAccessPermission(
            "VIEW", $this->{publisher}, $cfgt, $ct, $cw)) {
            die "Access to $cw.$ct denied";
        }

        $cfgt = TWiki::Func::expandCommonVariables(
            $cfgt, $configtopic, $this->{web}, $cfgm);

        # SMELL: common preferences parser?
        foreach my $line (split(/\r?\n/, $cfgt)) {
            next unless $line =~ /^\s+\*\s+Set\s+(?:PUBLISH_)?([A-Z]+)\s*=\s*(.*?)\s*$/;
            my $k = $1;
            my $v = $2;

            if ( $k eq 'HISTORY' && $v ne '' ) {
                $this->{historyTopic} = $v;
            } elsif ( $k eq 'INCLUSIONS' && $v ne '' ) {
                $v =~ s/([*?])/.$1/g;
                $v =~ s/,/|/g;
                $this->{inclusions} = $v;
            } elsif ( $k eq 'EXCLUSIONS' ) {
                $v =~ s/([*?])/.$1/g;
                $v =~ s/,/|/g;
                $this->{exclusions} = $v;
            } elsif ( $k eq 'TOPICSEARCH' || $k eq 'FILTER' ) {
                $this->{topicFilter} = $v;
            } elsif ( $k eq 'PUBLISHSKIN' || $k eq 'SKIN' ) {
                $skin = $v;
            } elsif( $k eq 'EXTRAS' ) {
                $genopt = $v;
            } elsif( $k eq 'FORMAT' ) {
                $v =~ /(\w*)/;
                $format = $1;
            } elsif ($k eq 'DEBUG' ) {
                $debug = $v;
            } elsif ($k eq 'VERSIONS') {
                $versionsTopic = $v;
            } elsif ($k eq 'TEMPLATES' && $v ne '' ) {
                $v =~ /([\w,]*)/;
                $this->{templatesWanted} = $1;
            } elsif ($k eq 'TEMPLATELOCATION' ) {
                if (-d $v) {
                    $v =~ /(.*)/;
                    $this->{templateLocation} = $1;
                }
            } elsif ($k eq 'INSTANCE' ) {
                $TWiki::cfg{PublishContrib}{Dir} .= $v.'/' if $v;
                $TWiki::cfg{PublishContrib}{URL} .= $v.'/' if $v;
            }
        }
    } else {
        # Parameters are defined in the query
        if ( defined($query->param('history')) ) {
            my $v = $query->param('history');
            if ($v =~ /(\w+)/) {
                $this->{historyTopic} = $1;
            }
            $query->delete('history');
        }
        if ( defined($query->param('inclusions')) ) {
            my $v = $query->param('inclusions');
            $v =~ s/([*?])/.$1/g;
            $v =~ s/,/|/g;
            $this->{inclusions} = $v;
            $query->delete('inclusions');
        }
        if ( defined($query->param('exclusions')) ) {
            my $v = $query->param('exclusions');
            $v =~ s/([*?])/.$1/g;
            $v =~ s/,/|/g;
            $this->{exclusions} = $v;
            $query->delete('exclusions');
        }
        if ( defined($query->param('versions')) ) {
            my $v = $query->param('versions');
            $versionsTopic = $v;
            $query->delete('versions');
        }
        $this->{topicFilter} = $query->param('filter') ||
          $query->param('topicsearch') || '';
        $genopt = $query->param('genopt') || '';
        # 'compress' retained for compatibility
        if( defined $query->param('compress') ) {
            my $v = $query->param('compress');
            if ($v =~ /(\w+)/) {
                $format = $1;
            }
        } elsif (defined $query->param( 'format' )) {
            my $v = $query->param( 'format' ) || '';
            if ($v =~ /(\w+)/) {
                $format = $1;
            }
        }
        $skin = $query->param('skin') || $query->param('publishskin');
        $this->{format} = $format;
        foreach my $param qw(inclusions exclusions filter topicsearch genopt compress format configtopic history) {
            $query->delete($param);
        }
    }

    $this->{skin} = $skin ||
      TWiki::Func::getPreferencesValue('PUBLISHSKIN') || 'basic_publish';

    my ($hw, $ht) = TWiki::Func::normalizeWebTopicName(
        $this->{web}, $this->{historyTopic});
    unless (TWiki::Func::checkAccessPermission(
        'CHANGE', TWiki::Func::getWikiName(), undef, $ht, $hw)) {
        die <<TEXT;
Can't publish because $this->{publisher} can't CHANGE
$hw.$ht.
This topic must be editable by the user doing the publishing.
TEXT
    }
    $this->{historyWeb} = $hw;
    $this->{historyTopic} = $ht;

    # Generate the progress information screen (based on the view template)
    my ($header, $footer) = ('', '');
    unless (TWiki::Func::getContext()->{command_line}) {
        # running from CGI
        if (defined $TWiki::Plugins::SESSION->{response}) {
            $TWiki::Plugins::SESSION->generateHTTPHeaders();
            $TWiki::Plugins::SESSION->{response}->body(
                CGI::start_html( -title => 'TWiki: Pubish'));
        }
        ($header, $footer) = $this->_getPageTemplate();
    }

    # Disable unwanted plugins
    my $enabledPlugins = '';
    my $disabledPlugins = '';
    my @pluginsToEnable;
    if (defined $query->param('enableplugins')) {
        @pluginsToEnable = split(/[, ]+/, $query->param('enableplugins'));
    }
    foreach my $plugin (keys(%{$TWiki::cfg{Plugins}})) {
        my $enable = $TWiki::cfg{Plugins}{$plugin}{Enabled};
        if (scalar(@pluginsToEnable) > 0) {
            $enable = grep(/$plugin/, @pluginsToEnable);
            $TWiki::cfg{Plugins}{$plugin}{Enabled} = $enable;
        }
        $enabledPlugins .= ', '.$plugin if ($enable);
        $disabledPlugins .= ', '.$plugin unless ($enable);
    }

    $TWiki::cfg{PublishContrib}{URL} .= '/'
      unless $TWiki::cfg{PublishContrib}{URL} =~ m#/$#;

    $this->logInfo("Publisher", $this->{publisher});
    $this->logInfo("Date", TWiki::Func::formatTime(time()));
    $this->logInfo("{PublishContrib}{Dir}", $TWiki::cfg{PublishContrib}{Dir});
    $this->logInfo("{PublishContrib}{URL}", $TWiki::cfg{PublishContrib}{URL});
    $this->logInfo("Web", $this->{web});
    $this->logInfo("Versions topic", $versionsTopic)
      if $versionsTopic;
    $this->logInfo("Content Generator", $format);
    $this->logInfo("Config", $configtopic) if $configtopic;
    $this->logInfo("Skin", $this->{skin});
    $this->logInfo("Inclusions", $this->{inclusions});
    $this->logInfo("Exclusions", $this->{exclusions});
    $this->logInfo("Content Filter", $this->{topicFilter});
    $this->logInfo("Generator Options", $genopt);
    $this->logInfo("Enabled Plugins", $enabledPlugins);
    $this->logInfo("Disabled Plugins", $disabledPlugins);

    if ($versionsTopic) {
        $this->{topicVersions} = {};
        my ($vweb, $vtopic) = TWiki::Func::normalizeWebTopicName(
            $web, $versionsTopic);
        die "Versions topic $vweb.$vtopic does not exist"
          unless TWiki::Func::topicExists($vweb, $vtopic);
        my ($meta, $text) = TWiki::Func::readTopic($vweb, $vtopic);
        $text = TWiki::Func::expandCommonVariables(
            $text, $vtopic, $vweb, $meta);
        my $pending;
        my $count = 0;
        foreach my $line (split(/\r?\n/, $text)) {
            if (defined $pending) {
                $line =~ s/^\s*//;
                $line = $pending . $line;
                undef $pending;
            }
            if ($line =~ s/\\$//) {
                $pending = $line;
                next;
            }
            if ($line =~ /^\s*\|\s*(.*?)\s*\|\s*(?:\d\.)?(\d+)\s*\|\s*$/) {
                my ($t, $v) = ($1, $2);
                ($vweb, $vtopic) = TWiki::Func::normalizeWebTopicName(
                    $web, $t);
                $this->{topicVersions}->{"$vweb.$vtopic"} = $v;
                $count++;
            }
        }
        die "Versions topic $vweb.$vtopic contains no topic versions"
          unless $count;
    }

    my @templatesWanted = split(/,/, $this->{templatesWanted});

    foreach my $template (@templatesWanted) {
        next unless $template;
        $this->{templatesReferenced}->{$template} = 1;
        my $dir = $TWiki::cfg{PublishContrib}{Dir}.
          $this->_dirForTemplate($template);

        my $generator = 'TWiki::Contrib::PublishContrib::'.$format;
        eval 'use '.$generator;
        unless ($@) {
            eval {
                $this->{archive} =
                  $generator->new($dir, $this->{web}, $genopt, $this, $query);
            };
        }
        if ($@ || (!$this->{archive})) {
            die "Failed to initialise '$format' ($generator) generator: <pre>$@</pre>\n",$footer;
        }
        $this->publishUsingTemplate($template);
    }

    # check the templates referenced, and that everything referenced
    # has been generated.
    my @templatesReferenced = sort keys %{$this->{templatesReferenced}};
    @templatesWanted = sort @templatesWanted;

    my @difference = arrayDiff(\@templatesReferenced, \@templatesWanted); 
    if ($#difference > 0) {
        $this->logInfo("Templates Used", join(",", @templatesReferenced));
        $this->logInfo("Templates Specified", join(",", @templatesWanted));
        $this->logWarn(<<BLAH);
There is a difference between the templates you specified and what you
needed. Consider changing the TEMPLATES setting so it has all Templates
Used.
BLAH
    }

    my $landed = $this->{archive}->close();

    $this->logInfo("Published To",<<LINK);
<a href="$TWiki::cfg{PublishContrib}{URL}$landed">$landed</a>
LINK
    my ($meta, $text) =
      TWiki::Func::readTopic($this->{historyWeb}, $this->{historyTopic});
    $text =~ s/(^|\n)---\+ Last Published\n.*$//s;
    TWiki::Func::saveTopic(
        $this->{historyWeb}, $this->{historyTopic}, $meta,
        "$text---+ Last Published\n$this->{history}\n",
        { minor => 1, forcenewrevision => 1 });
    my $url = TWiki::Func::getScriptUrl(
        $this->{historyWeb}, $this->{historyTopic}, 'view');
    $this->logInfo("History saved in", "<a href='$url'>$url</a>");

    _display($footer);
}

# get a template for presenting output / interacting (*not* used
# for published content)
sub _getPageTemplate {
    my ($this) = @_;

    my $query = TWiki::Func::getCgiQuery();
    my $topic = $query->param('publishtopic') || $this->{session}->{topicName};
    my $tmpl = TWiki::Func::readTemplate('view', $this->{skin});

    $tmpl =~ s/%META{.*?}%//g;
    for my $tag qw( REVTITLE REVARG REVISIONS MAXREV CURRREV ) {
        $tmpl =~ s/%$tag%//g;
    }
    my ($header, $footer) = split(/%TEXT%/, $tmpl);
    $header = TWiki::Func::expandCommonVariables(
        $header, $topic, $this->{web} );
    $header = TWiki::Func::renderText( $header, $this->{web} );
    $header =~ s/<nop>//go;
    TWiki::Func::writeHeader($query);
    _display "content-type: text/html; charset=UTF-8\n\n";
    _display $header;

    $footer = TWiki::Func::expandCommonVariables( $footer, $topic,
                                                  $this->{web} );
    $footer = TWiki::Func::renderText( $footer, $this->{web} );
    return ($header, $footer);
}

# from http://perl.active-venture.com/pod/perlfaq4-dataarrays.html
sub arrayDiff {
    my ($array1, $array2) = @_;
    my (@union, @intersection, @difference);
    @union = @intersection = @difference = ();
    my %count = ();
    foreach my $element (@$array1, @$array2) { $count{$element}++ }
    foreach my $element (keys %count) {
        push @union, $element;
        push @{ $count{$element} > 1 ? \@intersection : \@difference }, $element;
    }
    return @difference;
}

sub logInfo {
    my ($this, $header, $body) = @_;
    _display( CGI::b("$header:&nbsp;"), $body, CGI::br());
    $this->{history} .= "<b> $header </b>$body%BR%\n";
}

sub logWarn {
    my ($this, $message) = @_;
    _display CGI::span({class=>'twikiAlert'}, $message);
    _display CGI::br();
    $this->{history} .= "%ORANGE% *WARNING* $message %ENDCOLOR%%BR%\n";
}

sub logError {
    my ($this, $message) = @_;
    _display CGI::span({class=>'twikiAlert'}, "ERROR: $message");
    _display CGI::br();
    $this->{history} .= "%RED% *ERROR* $message %ENDCOLOR%%BR%\n";
}

#  Publish the contents of one web using the given template (e.g. view)
sub publishUsingTemplate {
    my ($this, $template) = @_;

    # Get list of topics from this web.
    my @topics = TWiki::Func::getTopicList($this->{web});

    # Choose template. Note that $template_TEMPLATE can still override
    # this in specific topics.
    my $tmpl = TWiki::Func::readTemplate($template, $this->{skin});
    die "Couldn't find template\n" if(!$tmpl);
	my $filetype = _filetypeForTemplate($template);

    # Attempt to render each included page.
    my %copied;
    my @inclusionsSet = grep { $_ ne '' } split(/;\s*/, $this->{inclusions});
    my %visited;
    foreach my $inclusions ( @inclusionsSet ) {
	$this->logInfo('Inclusions', $inclusions);
	foreach my $topic (@topics) {
	    next if $topic eq $this->{historyTopic};
	    try {
		my $dispo = '';
		if( $topic !~ /^$inclusions$/ ) {
		    $dispo = 'not included';
		} elsif( $this->{exclusions} && $topic =~ /^($this->{exclusions})$/ ) {
		    $dispo = 'excluded';
		} else {
		    if ( $visited{$topic} ) {
			$dispo = 'already published';
		    }
		    else {
			$this->publishTopic($topic, $filetype, $template, $tmpl,
				     \%copied);
			my ( $date, $user, $rev, $comment ) =
			  TWiki::Func::getRevisionInfo($this->{web}, $topic);
			$dispo = "Rev $rev published";
			$visited{$topic} = 1;
		    }
		}
		$this->logInfo($topic, $dispo) if ( $dispo ne 'not included' );
	    } catch Error::Simple with {
		my $e = shift;
		$this->logError("$topic not published: ".$e->{-text});
	    };
	}
    }
}

#  Publish one topic from web.
#   * =$this->{web}= - which web to publish
#   * =$topic= - which topic to publish
#   * =$filetype= - which filetype (pdf, html) to use as a suffix on the file generated

#   * =\%copied= - map of copied resources to new locations
sub publishTopic {
    my ($this, $topic, $filetype, $template, $tmpl, $copied) = @_;

    # Read topic data.

    my ($meta, $text);
    my $publishedRev = $this->{topicVersions}
      ? $this->{topicVersions}->{"$this->{web}.$topic"}
        : undef;

    ($meta, $text) = TWiki::Func::readTopic(
        $this->{web}, $topic, $publishedRev );
    unless ($publishedRev) {
        my $d;
        ( $d, $d, $publishedRev, $d ) =
          TWiki::Func::getRevisionInfo($this->{web}, $topic);
    }

    unless( TWiki::Func::checkAccessPermission( "VIEW", $this->{publisher},
                                                $text, $topic, $this->{web})) {
        $this->logError("View access to $this->{web}.$topic denied");
        return;
    }

    if ( $this->{topicFilter} && $text =~ /$this->{topicFilter}/ ) {
        $this->logInfo($topic, "excluded by filter");
        return;
    }

    # REFACTOR OPPORTUNITY: start factor me into getTWikiRendering()

    # clone the current session
    my $oldTWiki = $TWiki::Plugins::SESSION;
    my $query = TWiki::Func::getCgiQuery();
    $query->param('topic', "$this->{web}.$topic");

    # Create a new TWiki so that the contexts are correct. This is really,
    # really inefficient, but is essential at the moment to maintain correct
    # prefs
    my $twiki = new TWiki($this->{publisher}, $query);
    $twiki->{security} = new TWiki::Access( $twiki );
    $TWiki::Plugins::SESSION = $twiki;

    # Because of Item5388, we have to re-read the topic to get the
    # right session in the $meta. This could be done by patching the
    # $meta object, but this should be longer-lasting.
    # $meta has to have the right session otherwise $WEB and $TOPIC
    # won't work in %IF statements.
    ($meta, $text) = TWiki::Func::readTopic(
        $this->{web}, $topic, $publishedRev );

    # Allow a local definition of VIEW_TEMPLATE to override the
    # template passed in (unless this is disabled by a global option)
    my $override =
      TWiki::Func::getPreferencesValue( 'VIEW_TEMPLATE' );
    if ($override) {
        $tmpl = TWiki::Func::readTemplate(
            $override, $this->{skin}, $this->{web});
        $this->logInfo($topic, "has a VIEW_TEMPLATE '$override'");
    }

    my ($revdate, $revuser, $maxrev);
    ($revdate, $revuser, $maxrev) = $meta->getRevisionInfo();
    if (ref($revuser)) {
        $revuser = $revuser->wikiName();
    }

    # clean-up for PDF
    if ( $this->{format} eq 'pdf' ) {
	$text =~ s/\%TOC({.*?})?\%//g;
	$text =~ s|<section\b.*?>||ig;
	$text =~ s|</section>||ig;
    }

    # Expand and render the topic text
    $text = TWiki::Func::expandCommonVariables(
        $text, $topic, $this->{web}, $meta);

    my $newText = '';
    my $tagSeen = 0;
    my $publish = 1;
    foreach my $s ( split( /(%STARTPUBLISH%|%STOPPUBLISH%)/, $text )) {
        if( $s eq '%STARTPUBLISH%' ) {
            $publish = 1;
            $newText = '' unless( $tagSeen );
            $tagSeen = 1;
        } elsif( $s eq '%STOPPUBLISH%' ) {
            $publish = 0;
            $tagSeen = 1;
        } elsif( $publish ) {
            $newText .= $s;
        }
    }
    $text = $newText;

    # Expand and render the template
    $tmpl = TWiki::Func::expandCommonVariables(
        $tmpl, $topic, $this->{web}, $meta);

    # Inject the text into the template
    $tmpl =~ s/%TEXT%/$text/g;

    # REFACTOR OPPORTUNITY: stop factor me into getTWikiRendering()

    # legacy
    $tmpl =~ s/<nopublish>.*?<\/nopublish>//gs;

    $tmpl =~ s/.*?<\/nopublish>//gs;
    $tmpl =~ s/%MAXREV%/$maxrev/g;
    $tmpl =~ s/%CURRREV%/$maxrev/g;
    $tmpl =~ s/%REVTITLE%//g;

    $tmpl = TWiki::Func::renderText($tmpl, $this->{web});

    $tmpl =~ s|( ?) *</*nop/*>\n?|$1|gois;

    # additional clean-up for PDF
    if ( $this->{format} eq 'pdf' ) {
	$tmpl =~ s|<script\b.*?</script>\s*||isg;
	$tmpl =~ s|<style\b.*?</style>\s*||isg;
    }

    # Remove <base.../> tag
    $tmpl =~ s/<base[^>]+\/>//i;
    # Remove <base...>...</base> tag
    $tmpl =~ s/<base[^>]+>.*?<\/base>//i;

    # Clean up unsatisfied WikiWords.
    $tmpl =~ s/<span class="twikiNewLink">(.*?)<\/span>/
      $this->_handleNewLink($1)/ge;

    # Copy files from pub dir to rsrc dir in static dir.
    my $hs = $ENV{HTTP_HOST} || "localhost";

    # Find and copy resources attached to the topic
    my $pub = TWiki::Func::getPubUrlPath();
    $tmpl =~ s!(['"])($TWiki::cfg{DefaultUrlHost}|https?://$hs)?$pub/(.*?)\1!
      $1.$this->_copyResource($3, $copied).$1!ge;

    my $ilt;

    # Modify local links relative to server base
    $ilt = $TWiki::Plugins::SESSION->getScriptUrl(0, 'view', 'NOISE', 'NOISE');
    $ilt =~ s!/NOISE/NOISE.*$!!;
    $tmpl =~ s!href=(["'])$ilt/(.*?)\1!"href=$1".$this->_topicURL($2).$1!ge;

    # Modify absolute topic links.
    $ilt = $TWiki::Plugins::SESSION->getScriptUrl(1, 'view', 'NOISE', 'NOISE');
    $ilt =~ s!/NOISE/NOISE.*$!!;
    $tmpl =~ s!href=(["'])$ilt/(.*?)\1!"href=$1".$this->_topicURL($2).$1!ge;

    # Modify topic-relative TOC links to strip out parameters (but not anchor)
    $tmpl =~ s!href=(["'])\?.*?(\1|#)!href=$1$2!g;

    # replace any external template references
    $tmpl =~ s!href=["'](.*?)\?template=(\w*)(.*?)["']!
      $this->_rewriteTemplateReferences($tmpl, $1, $2, $3)!e;

    my $extras = 0;

    # Handle image tags using absolute URLs not otherwise satisfied
    $tmpl =~ s!(<img\s+.*?\bsrc=)(["'])(.*?)\2(.*?>)!
      $1.$2.$this->_handleURL($3,\$extras).$2.$4!ge;

    $tmpl =~ s/<nop>//g;

    # Write the resulting HTML.
    $this->{archive}->addString( $tmpl, $topic.$filetype);

    $TWiki::Plugins::SESSION = $oldTWiki; # restore twiki object
    $twiki->finish();
    return $publishedRev;
}

# rewrite 
#   Topic?template=viewprint%REVARG%.html?template=viewprint%REVARG%
# to
#   _viewprint/Topic.html
#
#   * =$this->{web}=
#   * =$tmpl=
#   * =$topic=
#   * =$template=
# return
#   * 
# side effects

sub _rewriteTemplateReferences {
    my ($this, $tmpl, $topic, $template, $redundantduplicate) = @_;
    # for an unknown reason, these come through with doubled up template= arg
    # e.g.
    # http://.../site/instance/Web/WebHome?template=viewprint%REVARG%.html?template=viewprint%REVARG%
    #$link:
    # Web/ContactUs?template=viewprint%REVARG%.html? "

    my $newLink = $TWiki::cfg{PublishContrib}{URL}.
      $this->_dirForTemplate($template)."/".$this->{web}.'/'.
        $topic._filetypeForTemplate($template);
    $this->{templatesReferenced}->{$template} = 1;
	return "href='$newLink'";
}

# Where alternative templates (e.g. viewprint) renderings end up
# This gets appended onto puburl and pubdir
# The web is prefixed before this.
# Do not prepend with a /
sub _dirForTemplate {
    my ($this, $template) = @_;
    return '' if ($template eq 'view');
    return $template unless $this->{templateLocation};
    return "$this->{templateLocation}/$template";
}

# SMELL this needs to be table driven
sub _filetypeForTemplate {
	my ($template) = @_;
	return '.pdf' if ($template eq 'viewpdf');
	return '.html';
}

#  Copy a resource (image, style sheet, etc.) from twiki/pub/%WEB% to
#   static HTML's rsrc directory.
#   * =$this->{web}= - name of web
#   * =$rsrcName= - name of resource (relative to pub/%WEB%)
#   * =\%copied= - map of copied resources to new locations
sub _copyResource {
    my ($this, $rsrcName, $copied) = @_;

    # Trim the resource name, as they can sometimes pick up whitespaces
    $rsrcName =~ /^\s*(.*?)\s*$/;
    $rsrcName = $1;

    # remove URL parameters
    $rsrcName =~ s/\?.*$//;


    # SMELL WARNING
    # This is covers up a case such as where rsrcname comes through like 
    # configtopic=PublishTestWeb/WebPreferences/favicon.ico
    # this should be just WebPreferences/favicon.ico
    # I've searched for hours and so here's a workaround
    if ($rsrcName =~ m/configtopic/) {
        $this->logError("rsrcName '$rsrcName' contains literal 'configtopic'");
        $rsrcName =~ s!.*?/(.*)!$this->{web}/$1!;
        $this->logError("--- FIXED UP to $rsrcName");
    }

    # See if we've already copied this resource.
    unless (exists $copied->{$rsrcName}) {
        # Nope, it's new. Gotta copy it to new location.
        # Split resource name into path (relative to pub/%WEB%) and leaf name.
        my $file = $rsrcName;
        $file =~ s(^(.*)\/)()o;
        my $path = "";
        if ($rsrcName =~ "/") {
            $path = $rsrcName;
            $path =~ s(\/[^\/]*$)()o; # path, excluding the basename
        }
        # Copy resource to rsrc directory.
        my $TWikiPubDir = TWiki::Func::getPubDir($this->{web});
        if ( -r "$TWikiPubDir/$rsrcName" ) {
            $this->{archive}->addDirectory( "rsrc" );
            $this->{archive}->addDirectory( "rsrc/$path" );
            $this->{archive}->addFile( "$TWikiPubDir/$rsrcName" , "rsrc/$path/$file" );
            # Record copy so we don't duplicate it later.
            my $destURL = "rsrc/$path/$file";
            $destURL =~ s!//!/!g;
            $copied->{$rsrcName} = $destURL;
        } else {
            $this->logError("$TWikiPubDir/$rsrcName is not readable");
        }

        # check css for additional resources, ie, url()
        if ($rsrcName =~ /\.css$/) {
            my @moreResources = ();
            if (open(F, "$TWikiPubDir/$rsrcName")) {
                local $/;
                my $data = <F>;
                close(F);
                $data =~ s#\/\*.*?\*\/##gs; # kill comments
                foreach my $line (split(/\r?\n/, $data)) {
                    if ($line =~ /url\(["']?(.*?)["']?\)/) {
                        push @moreResources, $1;
                    }
                }
                my $pub = TWiki::Func::getPubUrlPath();
                foreach my $resource (@moreResources) {
                    # recurse
                    if ($resource !~ m!^/!) {
                        # if the url is not absolute, assume it's
                        # relative to the current path
                        $resource = $path.'/'.$resource;
                    } else {
                        if ($resource =~ m!$pub/(.*)!) {
                            my $old = $resource;
                            $resource = $1;
                        }
                    }
                    $this->_copyResource($resource, $copied);
                }
            }
        }
    }
    return $copied->{$rsrcName} if $copied->{$rsrcName};
    $this->logError("MISSING RESOURCE $rsrcName");
    return "MISSING RESOURCE $rsrcName";
}

sub _topicURL {
    my( $this, $path ) = @_;
    my $extra = '';

    if( $path && $path =~ s/([#\?].*)$// ) {
        $extra = $1;
        # no point in passing on script params; we are publishing
        # to static HTML.
        $extra =~ s/\?.*?(#|$)/$1/;
    }

    $path ||= $TWiki::cfg{HomeTopicName};
    $path .= $TWiki::cfg{HomeTopicName} if $path =~ /\/$/;

    # Normalise
    $this->{web} = join('/', split( /[\/\.]+/, $this->{web} ));
    $path = join('/', split( /[\/\.]+/, $path ));

    # make a path relative to the web
    $path = File::Spec->abs2rel( $path, $this->{web} );
    $path .= '.html';

    return $path.$extra;
}

sub _handleURL {
    my( $this, $src, $extras ) = @_;

    return $src unless $src =~ m!^([a-z]+):([^/:]*)(:\d+)?(/.*)$!;

    my $data;
    if (defined(&TWiki::Func::getExternalResource)) {
        my $response = TWiki::Func::getExternalResource($src);
        return $src if $response->is_error();
        $data = $response->content();
    } else {
        my $protocol = $1;
        my $host = $2;
        my $port = $3;
        my $path = $4;
        $data = $TWiki::Plugins::SESSION->{net}->getUrl(
            $protocol, $host, $port, $path);
    }

    # Note: no extension; rely on file format.
    # Images are pretty good that way.
    my $file = '___extra'.$$extras++;
    $this->{archive}->addDirectory( "rsrc" );
    $this->{archive}->addString( $data, "rsrc/$file" );

    return 'rsrc/'.$file;
}

# Returns a pattern that will match the HTML used by TWiki to represent an
# unsatisfied link. THIS IS NASTY, but I don't know how else to do it.
# SMELL: another case for a WysiwygPlugin-style rendering engine
sub _handleNewLink {
    my ($this, $link) = @_;
    $link =~ s!<a .*?>!!gi;
    $link =~ s!</a>!!gi;
    return $link;
}

1;
