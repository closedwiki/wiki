#!/usr/bin/perl -w -I../../../lib

package TestVar;

use strict;

use TWiki::Vars;

use base qw(Test::Unit::TestCase);
use Data::Dumper;

sub new
{
    my $self = shift()->SUPER::new(@_);
    return $self;
}

sub handleVar1
{
    my ($self, $name, $text, $params, $parser) = @_; 
    $self->assert_equals($name, "VAR1"); 
    $self->{params} = $params;
    $self->{v1count}++;
    return "-V1-";
}

sub handleVar2
{
    my ($self, $name, $text, $params, $parser) = @_; 
    $self->{v2count}++;
    $text =~ s/VAR2/VAR1/g;
    $parser->substitute(\$text);
    return $text;
}

sub handleVar3
{
    my ($self, $name, $text, $params, $parser) = @_; 
    $self->{v3count}++;
    $parser->substitute(\$text);
    return $text;
}

sub set_up
{
    my ($self) = @_;
    $self->{parser} = TWiki::Vars::Parser->new();
    $self->{parser}->registerHandler("VAR1", \&handleVar1, $self);
    $self->{parser}->registerHandler("VAR2", \&handleVar2, $self);
    $self->{parser}->registerHandler("VAR3", \&handleVar3, $self);
    $self->{v1count} = $self->{v2count} = $self->{v3count} = 0;
}

sub test_register
{
    my ($self) = @_;
    my $handler = $self->{parser}->getHandler("VAR1");
    $self->assert_not_null($handler, "Handler registration unsuccessful.");
    $self->assert_equals(\&handleVar1, $handler->{function},
	"Registered handler fuction should match");
    $self->assert_equals($self, $handler->{instance},
	"Registered handler instance should match");

    my @testFailures = (
	["VAR1", \&handleVar1, $self],
	["NOTAVAR", undef, $self],
	["NOTAVAR", 42, $self],
	["NOTAVAR", \&handleVar1, undef],
	["52323", \&handleVar1, $self],
	[" NOTAVAR", \&handleVAR1, $self]
    );
    foreach my $badReg (@testFailures) {
	my ($name, $handler, $instance) = @$badReg;
	my $null = $self->{parser}->registerHandler($name, $handler, $instance);
	$self->assert_null($null, "Bad handler registration should fail");
    }
}

sub test_parse_args
{
    my ($self) = @_;
    my $p = $self->{parser};

    my @tests = (
	[undef, {}],
	["", {}],
	["test", { "*" => "test"} ],
	["\"test\"", { "*" => "test"} ],
	["default arg1=foo", {"*"=>"default", "arg1"=>"foo"}],
	["\"default\" arg1=\"foo\"", {"*"=>"default", "arg1"=>"foo"}],
	["arg1=foo arg2=\"bar\"", {"arg1"=>"foo", "arg2"=>"bar"}],
	["TEST=\"??\\\"?\"", {"test" => "??\"?"}],
	["baz=foo BAZ=bar", {"baz" => "bar"}]
    );
    foreach my $test (@tests) {
	my ($text, $params) = @$test;
	$params->{'%'} = $text if defined $text;
	my $result = $p->parseArgs($text);
	$text = "<undef>" unless defined $text;
	$self->assert_deep_equals($params, $result,
	    "Paramater hash not correct for {$text}\n" . Dumper($result));
    }
}

sub test_subst_simple
{
    my ($self) = @_;
    my $p = $self->{parser};
    
    my @tests = (
	"TEST",
	"\%NOTAVAR\%",
	"\%NOTAVAR{}\%",
	"\%NOTAVAR{\"foo\" arg=\"bar\"}\%",
	"blah blah \%NOTAVAR{\"foo\" arg=\"bar\"}\%  \%"
    );
    foreach my $test (@tests) {
	my $text = $test;
        my $outText = $p->substitute(\$text);
        $self->assert_equals(\$text, $outText);
        $self->assert_equals($test, $$outText);
    }
}

sub test_subst_var1
{
    my ($self) = @_;
    my $p = $self->{parser};
    
    my @tests = (
	["\%VAR1\%", "-V1-", 1, {'%' => ""}],
	["\%VAR1\% blah blah \%VAR1\%", "-V1- blah blah -V1-", 3, {'%' => ""}],
	["\%VAR1{}\%", "-V1-", 4, {'%' => ""}],
	["\%VAR1{\"default\" arg1=\"foo\" arg2=bar}\%", "-V1-", 5, {
	    "*" => "default",
	    "%" => "\"default\" arg1=\"foo\" arg2=bar",
	    "arg1" => "foo",
	    "arg2" => "bar"
	}],
	["\%VAR1{\"\\}???\\}\"}\%", "-V1-", 6, {"*"=>"}???}", "%"=>"\"}???}\""}]
    );

    foreach my $test (@tests) {
	my ($text, $result, $v1count, $params) = @$test;
	my $outText = $p->substitute(\$text);
	$self->assert_equals($result, $text, "\"$text\": \%VAR1\% not replaced by -V1-");
	$self->assert_equals($v1count, $self->{v1count}, "handleVar1 not called correct number of times");
	$self->assert_deep_equals($params, $self->{params},
	    "Parameter hash not correct:\n" . Dumper($self->{params}) );
    }
}

sub test_subst_var2
{
    my ($self) = @_;
    my $p = $self->{parser};
    
    my @tests = (
	['%VAR2{test}%', "-V1-", 1, 1, {'%' => "test", '*' => "test" }],
	['%VAR1% %VAR2{ }%', "-V1- -V1-", 2, 3, {'%' => ' '}]
    );

    foreach my $test (@tests) {
	my ($text, $result, $v2count, $v1count, $params) = @$test;
	$p->substitute(\$text);
	$self->assert_equals($v1count, $self->{v1count},
	    "handleVar1 not called corrent number of times");
	$self->assert_equals($v2count, $self->{v2count},
	    "handleVar2 not called corrent number of times");
	$self->assert_deep_equals($params, $self->{params},
	    "Parameter hash not correct:\n" . Dumper($self->{params}));
    }
}

sub test_subst_var3
{
    my ($self) = @_;
    my $p = $self->{parser};

    my $text = '%VAR3%';
    $p->substitute(\$text);

    $self->assert_equals(25, $self->{v3count}, "handleVar3 not called correct number of times: $self->{v3count}");
}

##########################################################################

package main;

use Test::Unit::TestRunner;

sub main {
   my $testRunner = Test::Unit::TestRunner->new(); 
   $testRunner->start("TestVar");
}

main() unless defined caller;

1;

