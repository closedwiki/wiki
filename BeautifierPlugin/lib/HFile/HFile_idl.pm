package HFile::HFile_idl;

use Beautifier::HFile;
@ISA = qw(HFile);
sub new
{
	my( $class ) = @_;
	my $self = {};
	bless $self, $class;

	# Flags
	$self->{nocase}            	= "1";
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
	$self->{delimiters}        	= [ "~", "!", "@", "%", "^", "&", "*", "(", ")", "-", "+", "=", "|", "\\", "/", "{", "}", "[", "]", ":", ";", "\"", "'", "<", ">", " ", ",", "	", ".", "?" ];
	$self->{escchar}           	= "";

	# Comment settings
	$self->{linecommenton}     	= [ "//" ];
	$self->{blockcommenton}    	= [ "/*" ];
	$self->{blockcommentoff}   	= [ "*/" ];

	# Keywords (keyword mapping to colour number)
	$self->{keywords}          	= {
			"any" => "1", 
			"attribute" => "1", 
			"boolean" => "1", 
			"context" => "1", 
			"exception" => "1", 
			"FALSE" => "1", 
			"in" => "1", 
			"inout" => "1", 
			"Object" => "1", 
			"octet" => "1", 
			"oneway" => "1", 
			"out" => "1", 
			"raises" => "1", 
			"readonly" => "1", 
			"sequence" => "1", 
			"string" => "1", 
			"TRUE" => "1", 
			"auto" => "2", 
			"break" => "2", 
			"case" => "2", 
			"char" => "2", 
			"const" => "2", 
			"continue" => "2", 
			"default" => "2", 
			"do" => "2", 
			"double" => "2", 
			"else" => "2", 
			"enum" => "2", 
			"extern" => "2", 
			"float" => "2", 
			"for" => "2", 
			"goto" => "2", 
			"if" => "2", 
			"int" => "2", 
			"long" => "2", 
			"register" => "2", 
			"return" => "2", 
			"short" => "2", 
			"signed" => "2", 
			"sizeof" => "2", 
			"static" => "2", 
			"struct" => "2", 
			"switch" => "2", 
			"typedef" => "2", 
			"union" => "2", 
			"unsigned" => "2", 
			"void" => "2", 
			"volatile" => "2", 
			"while" => "2", 
			"__asm" => "2", 
			"__fastcall" => "2", 
			"__self" => "2", 
			"__segment" => "2", 
			"__based" => "2", 
			"__segname" => "2", 
			"__fortran" => "2", 
			"__cdecl" => "2", 
			"__huge" => "2", 
			"__far" => "2", 
			"__saveregs" => "2", 
			"__export" => "2", 
			"__pascal" => "2", 
			"__near" => "2", 
			"__loadds" => "2", 
			"__interrupt" => "2", 
			"__inline" => "2", 
			"#define" => "2", 
			"#error" => "2", 
			"#include" => "2", 
			"#elif" => "2", 
			"#if" => "2", 
			"#line" => "2", 
			"#else" => "2", 
			"#ifdef" => "2", 
			"#pragma" => "2", 
			"#endif" => "2", 
			"#ifndef" => "2", 
			"#undef" => "2", 
			"class" => "3", 
			"delete" => "3", 
			"friend" => "3", 
			"inline" => "3", 
			"new" => "3", 
			"operator" => "3", 
			"private" => "3", 
			"protected" => "3", 
			"public" => "3", 
			"this" => "3", 
			"try" => "3", 
			"virtual" => "3", 
			"__multiple_inheritance" => "3", 
			"__single_inheritance" => "3", 
			"__virtual_inheritance" => "3", 
			"interface" => "4", 
			"module" => "4"};

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
