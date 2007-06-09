use strict;

# tests for basic formatting

package TableFormattingTests;

use base qw( TWikiFnTestCase );

use TWiki;
use Error qw( :try );

sub new {
    my $self = shift()->SUPER::new('TableFormatting', @_);
    return $self;
}

sub set_up {
    my $this = shift;

    $this->SUPER::set_up();
#    $this->{sup} = $this->{twiki}->getScriptUrl(0, 'view');
    $TWiki::cfg{AntiSpam}{RobotsAreWelcome} = 1;
    $TWiki::cfg{AntiSpam}{EmailPadding} = 'STUFFED';
    $TWiki::cfg{AllowInlineScript} = 1;
    $ENV{SCRIPT_NAME} = ''; #  required by fake sort URLs in expected text
}

# This formats the text up to immediately before <nop>s are removed, so we
# can see the nops.
sub do_test {
    my ($this, $expected, $actual) = @_;
    my $session = $this->{twiki};
    my $webName = $this->{test_web};
    my $topicName = $this->{test_topic};

    $actual = $session->handleCommonTags( $actual, $webName, $topicName );
    $actual = $session->{renderer}->getRenderedVersion( $actual, $webName, $topicName );

    $this->assert_html_equals($expected, $actual);
}

sub test_simpleTableusing {
    my $this = shift;
    my $expected = <<EXPECTED;
<nop>
<nop>
<nop>
<table cellspacing="0" cellpadding="0" class="twikiTable" border="1">
    <tr class="twikiTableEven">
        <td bgcolor="#ffffff" valign="top" class="twikiFirstCol"> a </td><td bgcolor="#ffffff" valign="top" > b </td>
    </tr>
    <tr class="twikiTableOdd">
        <td bgcolor="#edf4f9" valign="top" class="twikiFirstCol"> 2 </td><td bgcolor="#edf4f9" valign="top" > 3 </td>
    </tr>
    <tr class="twikiTableEven">
        <td bgcolor="#ffffff" valign="top" class="twikiFirstCol twikiLast"> ok </td><td bgcolor="#ffffff" valign="top" class="twikiLast"> bad </td>
    </tr>
</table>
EXPECTED
    my $actual = <<ACTUAL;
| a | b |
| 2 | 3 |
| ok | bad |
ACTUAL
    $this->do_test($expected, $actual);
}


sub test_simpleTheadTableusingTablePlugin {
    my $this = shift;

    my $cgi = $this->{twiki}->{cgiQuery};
    my $url = $cgi->url . $cgi->path_info();
    $url =~ s/\&/\&amp;/go;

    my $expected = <<EXPECTED;
<nop>
<nop>
<nop>
<table cellspacing="0" cellpadding="0" class="twikiTable" border="1">
    <thead>
        <tr class="twikiTableEven">
            <th bgcolor="#6b7f93" valign="top" class="twikiFirstCol" maxcols="0"> <a rel="nofollow" href="$url?sortcol=0;table=1;up=0#sorted_table" title="Sort by this column"><font color="#ffffff">a</font></a> </th><th bgcolor="#6b7f93" valign="top" maxcols="0"> <a rel="nofollow" href="$url?sortcol=1;table=1;up=0#sorted_table" title="Sort by this column"><font color="#ffffff">b</font></a> </th>
        </tr>
    </thead>
    <tr class="twikiTableOdd">
        <td bgcolor="#ffffff" valign="top" class="twikiFirstCol"> 2 </td><td bgcolor="#ffffff" valign="top" > 3 </td>
    </tr>
    <tr class="twikiTableEven">
        <td bgcolor="#edf4f9" valign="top" class="twikiFirstCol twikiLast"> ok </td><td bgcolor="#edf4f9" valign="top" class="twikiLast"> bad </td>
    </tr>
</table>
EXPECTED
    my $actual = <<ACTUAL;
| *a* | *b* |
| 2 | 3 |
| ok | bad |
ACTUAL
    $this->do_test($expected, $actual);
}

sub test_simpleTfootTableusingTablePlugin {
    my $this = shift;
    my $expected = <<EXPECTED;
<nop>
<nop>
<nop>
<nop>
<table cellspacing="0" cellpadding="0" class="twikiTable" border="1">
    <tr class="twikiTableEven">
        <td bgcolor="#ffffff" valign="top" class="twikiFirstCol"> a </td><td bgcolor="#ffffff" valign="top"> b </td>
    </tr>
    <tr class="twikiTableOdd">
        <td bgcolor="#edf4f9" valign="top" class="twikiFirstCol"> 2 </td><td bgcolor="#edf4f9" valign="top" > 3 </td>
    </tr>
    <tfoot>
         <tr class="twikiTableEven">
            <th bgcolor="#6b7f93" valign="top" class="twikiFirstCol twikiLast" maxcols="0"> <font color="#ffffff">ok</font> </th><th bgcolor="#6b7f93" valign="top" class="twikiLast" maxcols="0"> <font color="#ffffff">bad</font> </th>
        </tr>
    </tfoot>
</table>
EXPECTED
    my $actual = <<ACTUAL;
%TABLE{headerrows="0" footerrows="1"}%
| a | b |
| 2 | 3 |
| *ok* | *bad* |
ACTUAL
    $this->do_test($expected, $actual);
}

sub test_doubleTheadTableusingTablePlugin {
    my $this = shift;

    my $cgi = $this->{twiki}->{cgiQuery};
    my $url = $cgi->url . $cgi->path_info();
    $url =~ s/\&/\&amp;/go;

    my $expected = <<EXPECTED;
<nop>
<nop>
<nop>
<nop>

<table cellspacing="0" cellpadding="0" class="twikiTable" border="1"><thead><tr class="twikiTableEven"><th bgcolor="#6b7f93" valign="top" class="twikiFirstCol" maxcols="0"> <a rel="nofollow" href="http://localhost/TemporaryTableFormattingTestWebTableFormatting/TestTopicTableFormatting?sortcol=0;table=1;up=0#sorted_table" title="Sort by this column"><font color="#ffffff">a</font></a> </th><th bgcolor="#6b7f93" valign="top" maxcols="0"> <a rel="nofollow" href="http://localhost/TemporaryTableFormattingTestWebTableFormatting/TestTopicTableFormatting?sortcol=1;table=1;up=0#sorted_table" title="Sort by this column"><font color="#ffffff">b</font></a> </th></tr></thead>
<thead><tr class="twikiTableOdd"><th bgcolor="#6b7f93" valign="top" class="twikiFirstCol" maxcols="0"> <font color="#ffffff">c</font> </th><th bgcolor="#6b7f93" valign="top" maxcols="0"> <font color="#ffffff">c</font> </th></tr></thead>
<tr class="twikiTableEven"><td bgcolor="#ffffff" valign="top" class="twikiFirstCol"> 2 </td><td bgcolor="#ffffff" valign="top"> 3 </td></tr>
<tr class="twikiTableOdd"><td bgcolor="#edf4f9" valign="top" class="twikiFirstCol twikiLast"> ok </td><td bgcolor="#edf4f9" valign="top" class="twikiLast"> bad </td></tr>
</table>
EXPECTED
    my $actual = <<ACTUAL;
| *a* | *b* |
| *c* | *c* |
| 2 | 3 |
| ok | bad |
ACTUAL
    $this->do_test($expected, $actual);
}

sub test_doubleTheadandTfootTableusingTablePlugin {
    my $this = shift;

    my $cgi = $this->{twiki}->{cgiQuery};
    my $url = $cgi->url . $cgi->path_info();
    $url =~ s/\&/\&amp;/go;

    my $expected = <<EXPECTED;
<nop>
<nop>
<nop>
<nop>
<nop>
<table cellspacing="0" cellpadding="0" class="twikiTable" border="1"><thead><tr class="twikiTableEven"><th bgcolor="#6b7f93" valign="top" class="twikiFirstCol" maxcols="0"> <font color="#ffffff">a</font> </th><th bgcolor="#6b7f93" valign="top" maxcols="0"> <font color="#ffffff">b</font> </th></tr></thead>
<thead><tr class="twikiTableOdd"><th bgcolor="#6b7f93" valign="top" class="twikiFirstCol" maxcols="0"> <a rel="nofollow" href="http://localhost/TemporaryTableFormattingTestWebTableFormatting/TestTopicTableFormatting?sortcol=0;table=1;up=0#sorted_table" title="Sort by this column"><font color="#ffffff">c</font></a> </th><th bgcolor="#6b7f93" valign="top" maxcols="0"> <a rel="nofollow" href="http://localhost/TemporaryTableFormattingTestWebTableFormatting/TestTopicTableFormatting?sortcol=1;table=1;up=0#sorted_table" title="Sort by this column"><font color="#ffffff">c</font></a> </th></tr></thead>
<tr class="twikiTableEven"><td bgcolor="#ffffff" valign="top" class="twikiFirstCol"> 2 </td><td bgcolor="#ffffff" valign="top"> 3 </td></tr>
<tfoot><tr class="twikiTableOdd"><th bgcolor="#6b7f93" valign="top" class="twikiFirstCol twikiLast" maxcols="0"> <font color="#ffffff">ok</font> </th><th bgcolor="#6b7f93" valign="top" class="twikiLast" maxcols="0"> <font color="#ffffff">bad</font> </th></tr></tfoot>
</table>
EXPECTED
    my $actual = <<ACTUAL;
%TABLE{headerrows="2" footerrows="1"}%
| *a* | *b* |
| *c* | *c* |
| 2 | 3 |
| *ok* | *bad* |
ACTUAL
    $this->do_test($expected, $actual);
}



1;
