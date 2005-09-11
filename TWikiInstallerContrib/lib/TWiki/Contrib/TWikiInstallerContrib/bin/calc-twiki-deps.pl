#! /usr/bin/perl -w
use strict;

(my $deps = <<'__MODULES__') =~ s/\n/ /gsm;
^Data::UUID$
^Date::Handler$
^CGI::Session
^File::Temp$
^List::Permutor$
^Text::Diff$
^Algorithm::Diff$
^HTML::Diff$
^Pod::Escapes$
^Pod::Simple$
^Clone$
^Algorithm::Annotate$
^Regexp::Shellish$
^IO::Digest$
^PerlIO::via::dynamic$
^Data::Hierarchy$
^PerlIO::via::symlink$
^Time::ParseDate$
^Test::Harness$
^Test::More$
^YAML
^Safe$
^XML::Simple$
^XML::Parser$
Prolog
^GD
^SOAP
^XMLRPC
^Date::Handler$
^Date::Parse
^Date::Calc$
^Bit::Vector$
^Carp::Clan$
^HTML::CalendarMonthSimple$
^Image::LibRSVG$
^Error$
^Class::Inner$
^Devel::Symdump$
^URI$
^HTML::Parser$
^HTML::Tagset$
^Digest::
^Storable$
^Test::Unit$
^LWP::Simple$
^Weather::Com$
^Barcode::Code128$
WWW::Mechanize
^File::Find
^File::Slurp
^Text::Glob$
^Number::Compare$
^XML::SAX$
^XML::NamespaceSupport$
^XML::LibXML
^XML::LibXSLT$
^Cache::Cache$
^String::CRC$
^Time::HiRes$
^Archive::
^IO::String$
^File::AnySpec$
^Math::BigInt$
^File::Package$
^Data::Startup$
^Tie::Gzip$
^Tie::IxHash$
^File::Where$
^Class::ISA$
^Class::Virtually::Abstract$
^Carp::Assert$
^Class::Data::Inheritable$
^IO::Zlib$
^LWP::UserAgent::TWiki
^HTML::TableExtract$
^CPAN
^Compress
^Module::Depends$
^Test::Pod$
^Pod::Escapes$
^Pod::Simple$
^Test::Builder::Tester$
^Test::Memory::Cycle$
^Test::Warn$
^Devel::Cycle$
^Test::Exception$
^Sub::Uplevel$
^Array::Compare$
^Tree::DAG_Node$
^Pod::Coverage$
^Module::Build$
^Module::Signature$
^IO::Zlib$
^IO::String$
^Archive::Tar$
^ExtUtils::CBuilder$
^ExtUtils::ParserXS$
^ExtUtils::MakeMaker$
^String::Interpolate$
TWiki
^Number::Compare$
^Text::Glob$
^File::Find::Rule$
^IPC::Run$
^GraphViz
SVK
^SVN::
^File::Type$
^Encode$
^IO::Pager$
^Class::Autouse$
^FreezeThaw$
^PerlIO::eol$
^Locale::Maketext
^Term::ReadKey$
^File::chdir$
^Class::Accessor$
^HTML::TreeBuilder$
^Image::Info$
^Locale::Maketext::Lexicon$
^Text:IConv$
__MODULES__

print $deps, "\n";

__END__
