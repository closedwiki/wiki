package TWiki::Plugins::ImmediateNotifyPlugin::SMTP;

use strict;
use TWiki::Net;

use vars qw($user $pass $server $twikiuser $web $topic $debug $warning $sendEmail);

# ========================
# initMethed - initializes a single notification method
# Parametrs $topic, $web, $user
#    $topic is the current topic
#    $web is the web in which the topic is stored
#    $user is the logged-in user
sub initMethod {
    ($topic, $web, $twikiuser) = @_;
    $server = TWiki::Prefs::getPreferencesValue("SMTPMAILHOST");
    $twikiuser = $_[2];
    $debug = \&TWiki::Plugins::ImmediateNotifyPlugin::debug;
    $warning = \&TWiki::Plugins::ImmediateNotifyPlugin::warning;
    $sendEmail = \&TWiki::Net::sendEmail;
    return defined($server);
}

# ========================
# handleNotify - handles notification for a single notification method
# Parameters: $users
#    $users is a hash reference of the form username->user topic text
sub handleNotify {
    my ($users) = @_;

    my ($skin) = TWiki::Prefs::getPreferencesValue("SKIN");
    my ($template) = &TWiki::Store::readTemplate("immediatenotify-SMTP", $skin);
    my ($from) = TWiki::Prefs::getPreferencesValue("WIKIWEBMASTER");

    $template =~ s/%EMAILFROM%/$from/go;
    $template =~ s/%WEB%/$web/go;
    $template =~ s/%TOPICNAME%/$topic/go;
    $template =~ s/%USER%/$twikiuser/go;

    foreach my $userName (keys %$users) {
        my ($to) = TWiki::getEmailOfUser( $userName );
        my ($msg) = $template;

        $msg =~ s/%EMAILTO%/$to/go;
        &$debug("- SMTP: Sending mail to $to ($userName)");
        &$sendEmail( $msg );    
    }
}

1;
