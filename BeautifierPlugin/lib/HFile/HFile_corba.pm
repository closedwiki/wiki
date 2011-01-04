package HFile::HFile_corba;

#*************************************
# Beautifier Highlighting Configuration File 
# CORBA IDL
#*************************************

use Beautifier::HFile;
@ISA = qw(HFile);
sub new
{
	my( $class ) = @_;
	my $self = {};
	bless $self, $class;

	# Flags
	$self->{nocase}            	= "0";
	$self->{notrim}            	= "0";
	$self->{perl}              	= "0";

	# Colours
	$self->{colours}        	= [ "blue", "purple", "gray", "brown" ];
	$self->{quotecolour}       	= "blue";
	$self->{blockcommentcolour}	= "green";
	$self->{linecommentcolour} 	= "green";

	# Indent Strings
	$self->{indent}            	= [ "{" ];
	$self->{unindent}          	= [ "}" ];

	# String characters and delimiters
	$self->{stringchars}       	= [ '"', "'" ];
	$self->{delimiters}        	= [ "~", "!", "@", "%", "^", "*", "(", ")", "-", "+", "=", "\\", "/", "{", "}", "[", "]", ":", ";", "\"", "'", "<", ">", " ", ",", "	", ".", "?" ];
	$self->{escchar}           	= "";

	# Comment settings
	$self->{linecommenton}     	= [ "//" ];
	$self->{blockcommenton}    	= [ "/*" ];
	$self->{blockcommentoff}   	= [ "*/" ];

	# Keywords (keyword mapping to colour number)
	$self->{keywords}          	= {
			"any" => "1", 
			"boolean" => "1", 
			"case" => "1", 
			"char" => "1", 
			"const" => "1", 
			"default" => "1", 
			"double" => "1", 
			"enum" => "1", 
			"exception" => "1", 
			"FALSE" => "1", 
			"fixed" => "1", 
			"float" => "1", 
			"in" => "1", 
			"inout" => "1", 
			"long" => "1", 
			"Object" => "1", 
			"octet" => "1", 
			"oneway" => "1", 
			"out" => "1", 
			"raises" => "1", 
			"readonly" => "1", 
			"sequence" => "1", 
			"short" => "1", 
			"string" => "1", 
			"struct" => "1", 
			"switch" => "1", 
			"TRUE" => "1", 
			"typedef" => "1", 
			"unsigned" => "1", 
			"union" => "1", 
			"void" => "1", 
			"wchar" => "1", 
			"wstring" => "1", 
			"attribute" => "2", 
			"context" => "2", 
			"interface" => "2", 
			"module" => "2", 
			"#define" => "3", 
			"#error" => "3", 
			"#include" => "3", 
			"#elif" => "3", 
			"#if" => "3", 
			"#line" => "3", 
			"#else" => "3", 
			"#ifdef" => "3", 
			"#pragma" => "3", 
			"#endif" => "3", 
			"#ifndef" => "3", 
			"#undef" => "3", 
			"#" => "3", 
			"##" => "3", 
			"!" => "3", 
			"||" => "3", 
			"&&" => "3", 
			";" => "4", 
			"{" => "4", 
			"}" => "4", 
			":" => "4", 
			"," => "4", 
			"=" => "4", 
			"+" => "4", 
			"-" => "4", 
			"(" => "4", 
			")" => "4", 
			"<" => "4", 
			">" => "4", 
			"[" => "4", 
			"]" => "4", 
			"'" => "4", 
			"\"" => "4", 
			"\\" => "4", 
			"^" => "4", 
			"*" => "4", 
			"/" => "4", 
			"%" => "4", 
			"~" => "4"};

	# Special extensions

	# Each category can specify a PHP function that returns an altered
	# version of the keyword.
	$self->{linkscripts} = {
			"1" => "donothing", 
			"2" => "donothing", 
			"3" => "donothing", 
			"4" => "donothing",
		    };

	return $self;
}


# DoNothing link function

sub donothing
{
    my ( $self ) = @_;
    return;
}

1;
