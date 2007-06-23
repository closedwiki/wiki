use strict;

package PreferencesPluginTests;

use base qw(TWikiFnTestCase);

use strict;
use TWiki;

sub set_up {
    my $this = shift;

    $this->SUPER::set_up();

    $TWiki::cfg{Plugins}{PreferencesPlugin}{Enabled} = 1;
}

sub test_edit {
    my $this = shift;
    my $query = new CGI(
        {
            prefsaction => [ 'edit' ],
        });
    my $text = <<HERE;
   * Set FLEEGLE = floon
%EDITPREFERENCES%
HERE
    my $twiki = new TWiki(undef, $query);
    $TWiki::Plugins::SESSION = $twiki;
    my $result = TWiki::Func::expandCommonVariables(
        $text, $this->{test_topic}, $this->{test_web}, undef);
    $this->assert($result =~ s/^.*(<form [^<]*name=["']editpreferences["'])/$1/si, $result);
    $this->assert($result =~ s/(<\/form>).*$/$1/);
    my $viewUrl = TWiki::Func::getScriptUrl(
        $this->{test_web}, $this->{test_topic}, 'viewauth');
    $this->assert_html_equals(<<HTML, $result);
<form method="post" action="$viewUrl" enctype="multipart/form-data" name="editpreferences">
 <span style="font-weight:bold;" class="twikiAlert">FLEEGLE = SHELTER\0070</span>
 <input type="submit" name="prefsaction" value="Save new settings" accesskey="s" class="twikiSubmit" />
 &nbsp;
 <input type="submit" name="prefsaction" value="Cancel" accesskey="c" class="twikiButton" />
</form>
HTML
    $twiki->finish();
}

sub test_save {
    my $this = shift;
    my $query = new CGI(
        {
            prefsaction => [ 'save' ],
            FLEEGLE => [ 'flurb' ],
        });
    my $input = <<HERE;
   * Set FLEEGLE = floon
%EDITPREFERENCES%
HERE
    TWiki::Func::saveTopic( $this->{test_web}, $this->{test_topic},
                            undef, $input );

    my $twiki = new TWiki(undef, $query);
    $TWiki::Plugins::SESSION = $twiki;

    # This will attempt to redirect, so must capture
    my ($result, $ecode) = $this->capture(
        sub {
            print TWiki::Func::expandCommonVariables(
                $input, $this->{test_topic}, $this->{test_web}, undef);
        });
    $this->assert($result =~ /Status: 302/);
    my $viewUrl = TWiki::Func::getScriptUrl(
        $this->{test_web}, $this->{test_topic}, 'view');
    $this->assert_matches(qr/Location: $viewUrl\n/s, $result);
    my ($meta, $text) =
      TWiki::Func::readTopic($this->{test_web}, $this->{test_topic});
    $this->assert_str_equals(<<HERE, $text);
   * Set FLEEGLE = flurb
%EDITPREFERENCES%
HERE

    $twiki->finish();
}

sub test_view {
    my $this = shift;
    my $text = <<HERE;
   * Set FLEEGLE = floon
%EDITPREFERENCES%
HERE
    my $twiki = new TWiki();
    $TWiki::Plugins::SESSION = $twiki;
    my $result = TWiki::Func::expandCommonVariables(
        $text, $this->{test_topic}, $this->{test_web}, undef);
    $this->assert($result =~ s/^.*(<form [^<]*name=["']editpreferences["'])/$1/si, $result);
    $this->assert($result =~ s/(<\/form>).*$/$1/);
    my $viewUrl = TWiki::Func::getScriptUrl(
        $this->{test_web}, $this->{test_topic}, 'viewauth');
    $this->assert_html_equals(<<HTML, $result);
<form method="post" action="$viewUrl" enctype="multipart/form-data" name="editpreferences">
 <input type="hidden" name="prefsaction" value="edit"  />
 <input type="submit" name="edit" value="Edit Preferences" class="twikiButton" />
</form>
HTML
    $twiki->finish();
}

1;
