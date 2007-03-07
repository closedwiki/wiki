package TWiki::Plugins::SubscribePlugin;

use strict;

use vars qw( $VERSION $RELEASE $SHORTDESCRIPTION $debug $pluginName $NO_PREFS_IN_TOPIC $uid );

$VERSION = '$Rev$';

$RELEASE = 'Dakar';

$SHORTDESCRIPTION = 'Subscribe to web notification';

$NO_PREFS_IN_TOPIC = 1;

$pluginName = 'SubscribePlugin';

sub initPlugin {
    my( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.026 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    TWiki::Func::registerTagHandler( 'SUBSCRIBE', \&_SUBSCRIBE );
    $uid = 1;

    return 1;
}

# Show a button inviting (un)subscription to this topic
sub _SUBSCRIBE {
    my($session, $params, $topic, $web) = @_;

    my $query = TWiki::Func::getCgiQuery();
    my $form;
    my $suid = $query->param( 'subscribe_uid' );

    if ($suid && $suid == $uid) {
        # We have been asked to subscribe
        my $topics = $query->param('subscribe_topic');
        $topics =~ /^(.*)$/;
        $topics = $1; # Untaint - we will check it later
        my $who = $query->param('subscribe_subscriber');
        my $unsubscribe = $query->param('subscribe_remove');
        $form = _subscribe($web, $topics, $who, $unsubscribe);
    } else {
        my $who = $params->{who} || TWiki::Func::getWikiName();
        my $topics = $params->{topic} || $topic;
        my $prompt = $params->{prompt} || "Subscribe me to changes";
        my $unsubscribe = $params->{unsubscribe} || 0;

        $form = <<FORM;
<form name="subscriber_form$uid" method="POST" action="%SCRIPTURLPATH{view}%/%WEB%/%TOPIC%">
<input type="hidden" name="subscribe_topic" value="$topics" />
<input type="hidden" name="subscribe_subscriber" value="$who" />
<input type="hidden" name="subscribe_remove" value="$unsubscribe" />
<input type="hidden" name="subscribe_uid" value="$uid" />
<input type="submit" name="subscribe_me" value="$prompt" />
</form>
FORM
        $form =~ s/\n//g;
    }
    $uid++;
    return $form;
}

sub _alert {
    my( $mess ) = @_;
    return "<span class='twikiAlert'>$mess</span>";
}

# Handle a subscription request
sub _subscribe {
    my( $web, $topics, $subscriber ) = @_;

    eval { require TWiki::Contrib::MailerContrib::WebNotify };
    return _alert("Failed to load MailerContrib")
      if $@;

    my $cur_user = TWiki::Func::getWikiName();

    $subscriber ||= $cur_user;
    return _alert("bad subscriber '$subscriber'") unless
      $subscriber =~ m/($TWiki::cfg{LoginNameFilterIn})/ ||
        $subscriber =~ m/^([A-Z0-9._%-]+@[A-Z0-9.-]+\.[A-Z]{2,4})$/i ||
          $subscriber =~ m/($TWiki::regex{wikiWordRegex})/o;
    $subscriber = $1; # untaint

    # replace wildcards for checking - we want them
    my $cweb;
    ($web, $topics) = TWiki::Func::normalizeWebTopicName($web, $topics);
    return _alert("bad web '$web'") if
      $web =~ m/$TWiki::cfg{NameFilter}/o;
    my $checktopic = $topics;
    $checktopic =~ s/\*/STARSTARSTAR/g;
    return _alert("bad topic '$topics'") if
      $checktopic =~ m/$TWiki::cfg{NameFilter}/o;

    # First make sure we are allowed to subscribe
    my $allowed = TWiki::Func::checkAccessPermission(
        'SUBSCRIBE',
        $cur_user,
        undef,
        $TWiki::cfg{NotifyTopicName}, $web,
        undef );
    return _alert("not allowed to subscribe to this web")
      unless $allowed;

    $allowed = TWiki::Func::checkAccessPermission(
        'CHANGE',
        $cur_user,
        undef,
        $TWiki::cfg{NotifyTopicName}, $web,
        undef );
    return _alert("$cur_user is not allowed to change <nop>$TWiki::cfg{NotifyTopicName} in this web")
      unless $allowed;

    my $wn = new TWiki::Contrib::MailerContrib::WebNotify(
        $TWiki::Plugins::SESSION, $web, $TWiki::cfg{NotifyTopicName} );

    $wn->subscribe( $subscriber, $topics );

    $wn->writeWebNotify();

    return _alert("$subscriber has been subscribed to $web.<nop>$topics");
}

1;
