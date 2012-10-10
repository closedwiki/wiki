use strict;

package PreferencesPluginTests;

use base qw(TWikiFnTestCase);

use strict;
use Unit::Request;
use Unit::Response;
use TWiki;

sub set_up {
    my $this = shift;

    $this->SUPER::set_up();

    $TWiki::cfg{Plugins}{PreferencesPlugin}{Enabled} = 1;
}

sub test_edit_simple {
    my $this = shift;
    my $query = new Unit::Request(
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
    $this->assert($result =~ s/^.*(<form [^<]*name=[\"\']editpreferences[\"\'])/$1/si, $result);
    $this->assert($result =~ s/(<\/form>).*$/$1/);
    my $viewUrl = TWiki::Func::getScriptUrl(
        $this->{test_web}, $this->{test_topic}, 'viewauth');
    $this->assert_html_equals(<<HTML, $result);
<form method="post" action="$viewUrl" enctype="multipart/form-data" name="editpreferences">
 <span style="font-weight:bold;" class="twikiAlert">FLEEGLE = SHELTER\0070</span>
#EditPreferences
 <input type="submit" name="prefsaction" value="Save new settings" accesskey="s" class="twikiSubmit" />
 &nbsp;
 <input type="submit" name="prefsaction" value="Cancel" accesskey="c" class="twikiButton" />
</form>
HTML
    $twiki->finish();
}

# Item4816
sub test_edit_multiple_with_comments {
    my $this = shift;
    my $query = new Unit::Request(
        {
            prefsaction => [ 'edit' ],
        });
    my $text = <<HERE;
<!-- Comment should be outside form -->
Normal text outside form
%EDITPREFERENCES%
   * Set FLEEGLE = floon
   * Set FLEEGLE2 = floontoo
<!-- Form ends before this
   * Set HIDDENSETTING = hidden
-->
HERE
    my $twiki = new TWiki(undef, $query);
    $TWiki::Plugins::SESSION = $twiki;
    my $result = TWiki::Func::expandCommonVariables(
        $text, $this->{test_topic}, $this->{test_web}, undef);
    my $viewUrl = TWiki::Func::getScriptUrl(
        $this->{test_web}, $this->{test_topic}, 'viewauth');
    $this->assert_html_equals(<<HTML, $result);
<!-- Comment should be outside form -->
Normal text outside form
#EditPreferences
<form method="post" action="$viewUrl" enctype="multipart/form-data" name="editpreferences">
 <input type="submit" name="prefsaction" value="Save new settings" accesskey="s" class="twikiSubmit" />
 &nbsp;
 <input type="submit" name="prefsaction" value="Cancel" accesskey="c" class="twikiButton" />
   * Set <span style="font-weight:bold;" class="twikiAlert">FLEEGLE = SHELTER\0070</span>
   * Set <span style="font-weight:bold;" class="twikiAlert">FLEEGLE2 = SHELTER\0071</span></form>
<!-- Form ends before this
   * Set HIDDENSETTING = hidden
-->
HTML
    $twiki->finish();
}

sub test_save {
    my $this = shift;
    my $query = new Unit::Request(
        {
            prefsaction => [ 'save' ],
            FLEEGLE => [ 'flurb' ],
        });
    $query->request_method('POST');
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
            $twiki->{response}->body(
                TWiki::Func::expandCommonVariables(
                $input, $this->{test_topic}, $this->{test_web}, undef)
            );
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
    $this->assert($result =~ s/^.*(<form [^<]*name=[\"\']editpreferences[\"\'])/$1/si, $result);
    $this->assert($result =~ s/(<\/form>).*$/$1/);
    my $viewUrl = TWiki::Func::getScriptUrl(
        $this->{test_web}, $this->{test_topic}, 'viewauth');
    $this->assert_html_equals(<<HTML, $result);
<form method="post" action="$viewUrl#EditPreferences" enctype="multipart/form-data" name="editpreferences">
 <input type="hidden" name="prefsaction" value="edit"  />
 <input type="submit" name="edit" value="Edit Preferences" class="twikiButton" />
</form>
HTML
    $twiki->finish();
}

# Item6969
# *  Set VARIABLE = (two spaces before Set)
# * Set VARIABLE = (= at the end of line)
sub test_two_spcs_before_set_equal_at_eol {
    my $this = shift;
    my $query = new Unit::Request(
        {
            prefsaction => [ 'save' ],
            VAR1 => [ 'abc' ],
        });
    $query->request_method('POST');
    my $input = <<'END';
Normal text outside form
%EDITPREFERENCES%
   * Testing
      *  Set VAR1 =
      * Set VAR2 =
   * This line may be misrecognized as the value of VARIABLE when saved
END
    TWiki::Func::saveTopic( $this->{test_web}, $this->{test_topic},
                            undef, $input );

    my $twiki = new TWiki(undef, $query);
    $TWiki::Plugins::SESSION = $twiki;

    # This will attempt to redirect, so must capture
    my ($result, $ecode) = $this->capture(
        sub {
            $twiki->{response}->body(
                TWiki::Func::expandCommonVariables(
                $input, $this->{test_topic}, $this->{test_web}, undef)
            );
        });
    $this->assert($result =~ /Status: 302/);
    my $viewUrl = TWiki::Func::getScriptUrl(
        $this->{test_web}, $this->{test_topic}, 'view');
    $this->assert_matches(qr/Location: $viewUrl\n/s, $result);

    my ($meta, $text) =
      TWiki::Func::readTopic($this->{test_web}, $this->{test_topic});
    my $expected = <<'END';
Normal text outside form
%EDITPREFERENCES%
   * Testing
      *  Set VAR1 = abc
      * Set VAR2 = 
   * This line may be misrecognized as the value of VARIABLE when saved
END
    $this->assert_str_equals($expected, $text);
    $twiki->finish();
}

# Item6969
# * SetVARIABLE (no space between Set and VARIABLE)
sub test_no_space_b_w_set_and_variable {
    my $this = shift;
    my $query = new Unit::Request(
        {
            prefsaction => [ 'edit' ],
        });
    my $text = <<'END';
Normal text outside form
%EDITPREFERENCES%
   * Set VAR1 = 20
   * SetVAR2 = 10
END
    my $twiki = new TWiki(undef, $query);
    $TWiki::Plugins::SESSION = $twiki;
    my $result = TWiki::Func::expandCommonVariables(
        $text, $this->{test_topic}, $this->{test_web}, undef);
    my $viewUrl = TWiki::Func::getScriptUrl(
        $this->{test_web}, $this->{test_topic}, 'viewauth');
    $this->assert_html_equals(<<END, $result);
Normal text outside form
#EditPreferences
<form method="post" action="$viewUrl" enctype="multipart/form-data" name="editpreferences">
 <input type="submit" name="prefsaction" value="Save new settings" accesskey="s" class="twikiSubmit" />
 &nbsp;
 <input type="submit" name="prefsaction" value="Cancel" accesskey="c" class="twikiButton" />
   * Set <span style="font-weight:bold;" class="twikiAlert">VAR1 = SHELTER\0070</span></form>
   * SetVAR2 = 10
END
    $twiki->finish();
}

# Item6969
sub test_multi_line_value {
    my $this = shift;
    $this->{twiki}->{store}->saveTopic(
        $this->{twiki}->{user}, $this->{test_web}, 'TestForm', <<'END');
| *Name* | *Type* | *Size* |
| VAR2 | textarea | 80x3 |
END
    my $input = <<END;
%EDITPREFERENCES{"$this->{test_web}.TestForm"}%
   * Set VAR1 =
   * Set VAR2 = abc def
     ghi jkl
   * Set VAR3 =
END
    #### edit ####
    {
        my $query = new Unit::Request(
            {
                prefsaction => [ 'edit' ],
            });
        $query->{path_info} = "/$this->{test_web}/$this->{test_topic}";
        my $twiki = new TWiki(undef, $query);
        $TWiki::Plugins::SESSION = $twiki;
        my $twiki = new TWiki(undef, $query);
        $TWiki::Plugins::SESSION = $twiki;
        my $expanded = TWiki::Func::expandCommonVariables($input, $this->{test_web}, $this->{test_topic});
        my $rendered = TWiki::Func::renderText($expanded, $this->{test_web}, $this->{test_topic});
        my $expectedVar2 = <<'END';
    <span style="font-weight:bold;" class="twikiAlert">VAR2 = <textarea name="VAR2"  rows="3" cols="80" class="twikiInputField twikiEditFormTextAreaField">
    abc def
    ghi jkl</textarea></span>
    END
        $expectedVar2 =~ s/(\W)/\\$1/g;
        $this->assert($rendered =~ $expectedVar2);
        $twiki->finish();
    }

    #### save ####
    {
        TWiki::Func::saveTopic( $this->{test_web}, $this->{test_topic},
                                undef, $input );
        my $query = new Unit::Request(
            {
                prefsaction => [ 'save' ],
                VAR2 => [ "abc def\nghi jkl\nmno pqr" ],
            });
        $query->request_method('POST');
        my $twiki = new TWiki(undef, $query);
        $TWiki::Plugins::SESSION = $twiki;
        # This will attempt to redirect, so must capture
        my ($result, $ecode) = $this->capture(
            sub {
                $twiki->{response}->body(
                    TWiki::Func::expandCommonVariables(
                    $input, $this->{test_topic}, $this->{test_web}, undef)
                );
            });
        $this->assert($result =~ /Status: 302/);
        my $viewUrl = TWiki::Func::getScriptUrl(
            $this->{test_web}, $this->{test_topic}, 'view');
        $this->assert_matches(qr/Location: $viewUrl\n/s, $result);
        my ($meta, $text) =
          TWiki::Func::readTopic($this->{test_web}, $this->{test_topic});
        $this->assert_str_equals(<<END, $text);
%EDITPREFERENCES{"$this->{test_web}.TestForm"}%
   * Set VAR1 =
   * Set VAR2 = abc def
   ghi jkl
   mno pqr
   * Set VAR3 =
END
        $twiki->finish();
    }
}

# Item6969
sub test_save_set_null {
    my $this = shift;
    my $query = new Unit::Request(
        {
            prefsaction => [ 'save' ],
            FLEEGLE => [ '' ],
        });
    $query->request_method('POST');
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
            $twiki->{response}->body(
                TWiki::Func::expandCommonVariables(
                $input, $this->{test_topic}, $this->{test_web}, undef)
            );
        });
    $this->assert($result =~ /Status: 302/);
    my $viewUrl = TWiki::Func::getScriptUrl(
        $this->{test_web}, $this->{test_topic}, 'view');
    $this->assert_matches(qr/Location: $viewUrl\n/s, $result);
    my ($meta, $text) =
      TWiki::Func::readTopic($this->{test_web}, $this->{test_topic});
    $this->assert_str_equals(<<HERE, $text);
   * Set FLEEGLE = 
%EDITPREFERENCES%
HERE
    $twiki->finish();
}

1;
