use strict;

# tests for basic formatting

package TablePluginTests;

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
    $actual = $session->renderer->getRenderedVersion( $actual, $webName, $topicName );

    $this->assert_html_equals($expected, $actual);
}

sub test_simpleTableusing {
    my $this = shift;
    my $expected = <<EXPECTED;
<nop>
<nop>
<nop>
<table cellspacing="0" id="table1" cellpadding="0" class="twikiTable" rules="rows" border="1">
	<tbody>
		<tr class="twikiTableOdd twikiTableRowdataBgSorted0 twikiTableRowdataBg0">
			<td bgcolor="#ffffff" valign="top" class="twikiTableCol0 twikiFirstCol"> a </td>
			<td bgcolor="#ffffff" valign="top" class="twikiTableCol1 twikiLastCol"> b </td>
		</tr>
		<tr class="twikiTableEven twikiTableRowdataBgSorted1 twikiTableRowdataBg1">
			<td bgcolor="#edf4f9" valign="top" class="twikiTableCol0 twikiFirstCol"> 2 </td>
			<td bgcolor="#edf4f9" valign="top" class="twikiTableCol1 twikiLastCol"> 3 </td>
		</tr>
		<tr class="twikiTableOdd twikiTableRowdataBgSorted0 twikiTableRowdataBg0">
			<td bgcolor="#ffffff" valign="top" class="twikiTableCol0 twikiFirstCol twikiLast"> ok </td>
			<td bgcolor="#ffffff" valign="top" class="twikiTableCol1 twikiLastCol twikiLast"> bad </td>
		</tr>
	</tbody>
</table>
EXPECTED
    my $actual = <<ACTUAL;
| a | b |
| 2 | 3 |
| ok | bad |
ACTUAL
    $this->do_test($expected, $actual);
}


sub test_simpleTheadTableUsingTablePlugin {
    my $this = shift;

    my $cgi = $this->{request};
    my $url = $cgi->url(-absolute => 1);

    my $expected = <<EXPECTED;
<nop>
<nop>
<nop>
<table cellspacing="0" id="table1" cellpadding="0" class="twikiTable" rules="rows" border="1">
	<thead>
		<tr class="twikiTableOdd twikiTableRowdataBgSorted0 twikiTableRowdataBg0">
			<th bgcolor="#687684" valign="top" class="twikiTableCol0 twikiFirstCol"> <a rel="nofollow" href="$url/TemporaryTableFormattingTestWebTableFormatting/TestTopicTableFormatting?sortcol=0;table=1;up=0#sorted_table" title="Sort by this column"><font color="#ffffff">a</font></a> </th>
			<th bgcolor="#687684" valign="top" class="twikiTableCol1 twikiLastCol"> <a rel="nofollow" href="$url/TemporaryTableFormattingTestWebTableFormatting/TestTopicTableFormatting?sortcol=1;table=1;up=0#sorted_table" title="Sort by this column"><font color="#ffffff">b</font></a> </th>
		</tr>
	</thead>
	<tbody>
		<tr class="twikiTableEven twikiTableRowdataBgSorted0 twikiTableRowdataBg0">
			<td bgcolor="#ffffff" valign="top" class="twikiTableCol0 twikiFirstCol"> 2 </td>
			<td bgcolor="#ffffff" valign="top" class="twikiTableCol1 twikiLastCol"> 3 </td>
		</tr>
		<tr class="twikiTableOdd twikiTableRowdataBgSorted1 twikiTableRowdataBg1">
			<td bgcolor="#edf4f9" valign="top" class="twikiTableCol0 twikiFirstCol twikiLast"> ok </td>
			<td bgcolor="#edf4f9" valign="top" class="twikiTableCol1 twikiLastCol twikiLast"> bad </td>
		</tr>
	</tbody>
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
<table cellspacing="0" id="table1" cellpadding="0" class="twikiTable" rules="rows" border="1">
	<tfoot>
		<tr class="twikiTableOdd twikiTableRowdataBgSorted0 twikiTableRowdataBg0">
			<th bgcolor="#687684" valign="top" class="twikiTableCol0 twikiFirstCol twikiLast"> <font color="#ffffff">ok</font> </th>
			<th bgcolor="#687684" valign="top" class="twikiTableCol1 twikiLastCol twikiLast"> <font color="#ffffff">bad</font> </th>
		</tr>
	</tfoot>
	<tbody>
		<tr class="twikiTableOdd twikiTableRowdataBgSorted0 twikiTableRowdataBg0">
			<td bgcolor="#ffffff" valign="top" class="twikiTableCol0 twikiFirstCol"> a </td>
			<td bgcolor="#ffffff" valign="top" class="twikiTableCol1 twikiLastCol"> b </td>
		</tr>
		<tr class="twikiTableEven twikiTableRowdataBgSorted1 twikiTableRowdataBg1">
			<td bgcolor="#edf4f9" valign="top" class="twikiTableCol0 twikiFirstCol"> 2 </td>
			<td bgcolor="#edf4f9" valign="top" class="twikiTableCol1 twikiLastCol"> 3 </td>
		</tr>
	</tbody>
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

sub test_doubleTheadTableUsingTablePlugin {
    my $this = shift;

    my $cgi = $this->{request};
    my $url = $cgi->url(-absolute => 1);

    my $expected = <<EXPECTED;
<nop>
<nop>
<nop>
<nop>
<table cellspacing="0" id="table1" cellpadding="0" class="twikiTable" rules="rows" border="1">
	<thead>
		<tr class="twikiTableOdd twikiTableRowdataBgSorted0 twikiTableRowdataBg0">
			<th bgcolor="#687684" valign="top" class="twikiTableCol0 twikiFirstCol"> <a rel="nofollow" href="$url/TemporaryTableFormattingTestWebTableFormatting/TestTopicTableFormatting?sortcol=0;table=1;up=0#sorted_table" title="Sort by this column"><font color="#ffffff">a</font></a> </th>
			<th bgcolor="#687684" valign="top" class="twikiTableCol1 twikiLastCol"> <a rel="nofollow" href="$url/TemporaryTableFormattingTestWebTableFormatting/TestTopicTableFormatting?sortcol=1;table=1;up=0#sorted_table" title="Sort by this column"><font color="#ffffff">b</font></a> </th>
		</tr>
		<tr class="twikiTableEven twikiTableRowdataBgSorted0 twikiTableRowdataBg0">
			<th bgcolor="#687684" valign="top" class="twikiTableCol0 twikiFirstCol"> <font color="#ffffff">c</font> </th>
			<th bgcolor="#687684" valign="top" class="twikiTableCol1 twikiLastCol"> <font color="#ffffff">c</font> </th>
		</tr>
	</thead>
	<tbody>
		<tr class="twikiTableOdd twikiTableRowdataBgSorted0 twikiTableRowdataBg0">
			<td bgcolor="#ffffff" valign="top" class="twikiTableCol0 twikiFirstCol"> 2 </td>
			<td bgcolor="#ffffff" valign="top" class="twikiTableCol1 twikiLastCol"> 3 </td>
		</tr>
		<tr class="twikiTableEven twikiTableRowdataBgSorted1 twikiTableRowdataBg1">
			<td bgcolor="#edf4f9" valign="top" class="twikiTableCol0 twikiFirstCol twikiLast"> ok </td>
			<td bgcolor="#edf4f9" valign="top" class="twikiTableCol1 twikiLastCol twikiLast"> bad </td>
		</tr>
	</tbody>
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

    my $cgi = $this->{request};
    my $url = $cgi->url(-absolute => 1);

    my $expected = <<EXPECTED;
<nop>
<nop>
<nop>
<nop>
<nop>
<table cellspacing="0" id="table1" cellpadding="0" class="twikiTable" rules="rows" border="1">
	<thead>
		<tr class="twikiTableOdd twikiTableRowdataBgSorted0 twikiTableRowdataBg0">
				<th bgcolor="#687684" valign="top" class="twikiTableCol0 twikiFirstCol"> <font color="#ffffff">a</font> </th>
				<th bgcolor="#687684" valign="top" class="twikiTableCol1 twikiLastCol"> <font color="#ffffff">b</font> </th>
		</tr>
		<tr class="twikiTableEven twikiTableRowdataBgSorted0 twikiTableRowdataBg0">
				<th bgcolor="#687684" valign="top" class="twikiTableCol0 twikiFirstCol"> <a rel="nofollow" href="$url/TemporaryTableFormattingTestWebTableFormatting/TestTopicTableFormatting?sortcol=0;table=1;up=0#sorted_table" title="Sort by this column"><font color="#ffffff">c</font></a> </th>
				<th bgcolor="#687684" valign="top" class="twikiTableCol1 twikiLastCol"> <a rel="nofollow" href="$url/TemporaryTableFormattingTestWebTableFormatting/TestTopicTableFormatting?sortcol=1;table=1;up=0#sorted_table" title="Sort by this column"><font color="#ffffff">c</font></a> </th>
		</tr>
	</thead>
	<tfoot>
		<tr class="twikiTableEven twikiTableRowdataBgSorted1 twikiTableRowdataBg1">
				<th bgcolor="#687684" valign="top" class="twikiTableCol0 twikiFirstCol twikiLast"> <font color="#ffffff">ok</font> </th>
				<th bgcolor="#687684" valign="top" class="twikiTableCol1 twikiLastCol twikiLast"> <font color="#ffffff">bad</font> </th>
		</tr>
	</tfoot>
	<tbody>
		<tr class="twikiTableOdd twikiTableRowdataBgSorted0 twikiTableRowdataBg0">
				<td bgcolor="#ffffff" valign="top" class="twikiTableCol0 twikiFirstCol"> 2 </td>
				<td bgcolor="#ffffff" valign="top" class="twikiTableCol1 twikiLastCol"> 3 </td>
		</tr>
	</tbody>
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
