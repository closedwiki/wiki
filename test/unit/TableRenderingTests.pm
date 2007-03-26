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

sub test_simpleTableusingTablePlugin {
    my $this = shift;
    my $expected = <<EXPECTED;
<nop>
<nop>
<nop>
<table style="border-width:1px;" cellspacing="0" cellpadding="0" class="twikiTable" border="1">
    <tr class="twikiTableEven">
        <td bgcolor="#ffffff" valign="top" style="vertical-align:top;" class="twikiFirstCol"> a </td><td bgcolor="#ffffff" valign="top" style="vertical-align:top;"> b </td>
    </tr>
    <tr class="twikiTableOdd">
        <td bgcolor="#edf4f9" valign="top" style="vertical-align:top;" class="twikiFirstCol"> 2 </td><td bgcolor="#edf4f9" valign="top" style="vertical-align:top;"> 3 </td>
    </tr>
    <tr class="twikiTableEven">
        <td bgcolor="#ffffff" valign="top" style="vertical-align:top;" class="twikiFirstCol twikiLast"> ok </td><td bgcolor="#ffffff" valign="top" style="vertical-align:top;" class="twikiLast"> bad </td>
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
    my $expected = <<EXPECTED;
<nop>
<nop>
<nop>
<table style="border-width:1px;" cellspacing="0" cellpadding="0" class="twikiTable" border="1">
    <thead>
        <tr class="twikiTableEven">
            <th bgcolor="#6b7f93" valign="top" style="vertical-align:top;" class="twikiFirstCol" maxcols="0"> <a rel="nofollow" href="http://localhost/TemporaryTableFormattingTestWebTableFormatting/TestTopicTableFormatting?sortcol=0;table=1;up=0#sorted_table" style="color:#ffffff" title="Sort by this column">a</a> </th><th bgcolor="#6b7f93" valign="top" style="vertical-align:top;" maxcols="0"> <a rel="nofollow" href="http://localhost/TemporaryTableFormattingTestWebTableFormatting/TestTopicTableFormatting?sortcol=1;table=1;up=0#sorted_table" style="color:#ffffff" title="Sort by this column">b</a> </th>
        </tr>
    </thead>
    <tr class="twikiTableOdd">
        <td bgcolor="#ffffff" valign="top" style="vertical-align:top;" class="twikiFirstCol"> 2 </td><td bgcolor="#ffffff" valign="top" style="vertical-align:top;"> 3 </td>
    </tr>
    <tr class="twikiTableEven">
        <td bgcolor="#edf4f9" valign="top" style="vertical-align:top;" class="twikiFirstCol twikiLast"> ok </td><td bgcolor="#edf4f9" valign="top" style="vertical-align:top;" class="twikiLast"> bad </td>
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
<table style="border-width:1px;" cellspacing="0" cellpadding="0" class="twikiTable" border="1">
    <tr class="twikiTableEven">
        <td bgcolor="#ffffff" valign="top" style="vertical-align:top;" class="twikiFirstCol"> a </td><td bgcolor="#ffffff" valign="top" style="vertical-align:top;"> b </td>
    </tr>
    <tr class="twikiTableOdd">
        <td bgcolor="#edf4f9" valign="top" style="vertical-align:top;" class="twikiFirstCol"> 2 </td><td bgcolor="#edf4f9" valign="top" style="vertical-align:top;"> 3 </td>
    </tr>
    <tfoot>
         <tr class="twikiTableEven">
            <th bgcolor="#6b7f93" valign="top" style="vertical-align:top;" class="twikiFirstCol twikiLast" maxcols="0"> <span style="color:#ffffff"> <strong> ok </strong> </span> </th><th bgcolor="#6b7f93" valign="top" style="vertical-align:top;" class="twikiLast" maxcols="0"> <span style="color:#ffffff"> <strong> bad </strong> </span> </th>
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
    my $expected = <<EXPECTED;
<nop>
<nop>
<nop>
<nop>
<table style="border-width:1px;" cellspacing="0" cellpadding="0" class="twikiTable" border="1"><thead><tr class="twikiTableEven"><th bgcolor="#6b7f93" valign="top" style="vertical-align:top;" class="twikiFirstCol" maxcols="0"> <a rel="nofollow" href="http://localhost/TemporaryTableFormattingTestWebTableFormatting/TestTopicTableFormatting?sortcol=0;table=1;up=0#sorted_table" style="color:#ffffff" title="Sort by this column">a</a> </th><th bgcolor="#6b7f93" valign="top" style="vertical-align:top;" maxcols="0"> <a rel="nofollow" href="http://localhost/TemporaryTableFormattingTestWebTableFormatting/TestTopicTableFormatting?sortcol=1;table=1;up=0#sorted_table" style="color:#ffffff" title="Sort by this column">b</a> </th></tr></thead>
<thead><tr class="twikiTableOdd"><th bgcolor="#6b7f93" valign="top" style="vertical-align:top;" class="twikiFirstCol" maxcols="0"> <span style="color:#ffffff"> <strong> c </strong> </span> </th><th bgcolor="#6b7f93" valign="top" style="vertical-align:top;" maxcols="0"> <span style="color:#ffffff"> <strong> c </strong> </span> </th></tr></thead>
<tr class="twikiTableEven"><td bgcolor="#ffffff" valign="top" style="vertical-align:top;" class="twikiFirstCol"> 2 </td><td bgcolor="#ffffff" valign="top" style="vertical-align:top;"> 3 </td></tr>
<tr class="twikiTableOdd"><td bgcolor="#edf4f9" valign="top" style="vertical-align:top;" class="twikiFirstCol twikiLast"> ok </td><td bgcolor="#edf4f9" valign="top" style="vertical-align:top;" class="twikiLast"> bad </td></tr>
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
    my $expected = <<EXPECTED;
<nop>
<nop>
<nop>
<nop>
<nop>
<table style="border-width:1px;" cellspacing="0" cellpadding="0" class="twikiTable" border="1">
    <thead>
        <tr class="twikiTableEven">
            <th bgcolor="#6b7f93" valign="top" style="vertical-align:top;" class="twikiFirstCol" maxcols="0"> <span style="color:#ffffff"> <strong> a </strong> </span> </th><th bgcolor="#6b7f93" valign="top" style="vertical-align:top;" maxcols="0"> <span style="color:#ffffff"> <strong> b </strong> </span> </th>
        </tr>
    </thead>
    <thead>
        <tr class="twikiTableOdd">
            <th bgcolor="#6b7f93" valign="top" style="vertical-align:top;" class="twikiFirstCol" maxcols="0"> <a rel="nofollow" href="http://localhost/TemporaryTableFormattingTestWebTableFormatting/TestTopicTableFormatting?sortcol=0;table=1;up=0#sorted_table" style="color:#ffffff" title="Sort by this column">c</a> </th><th bgcolor="#6b7f93" valign="top" style="vertical-align:top;" maxcols="0"> <a rel="nofollow" href="http://localhost/TemporaryTableFormattingTestWebTableFormatting/TestTopicTableFormatting?sortcol=1;table=1;up=0#sorted_table" style="color:#ffffff" title="Sort by this column">c</a> </th>
        </tr>
    </thead>
    <tr class="twikiTableEven">
        <td bgcolor="#ffffff" valign="top" style="vertical-align:top;" class="twikiFirstCol"> 2 </td><td bgcolor="#ffffff" valign="top" style="vertical-align:top;"> 3 </td>
    </tr>
    <tfoot>
        <tr class="twikiTableOdd">
            <th bgcolor="#6b7f93" valign="top" style="vertical-align:top;" class="twikiFirstCol twikiLast" maxcols="0"> <span style="color:#ffffff"> <strong> ok </strong> </span> </th><th bgcolor="#6b7f93" valign="top" style="vertical-align:top;" class="twikiLast" maxcols="0"> <span style="color:#ffffff"> <strong> bad </strong> </span> </th>
        </tr>
    </tfoot>
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
