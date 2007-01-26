# Makefile for NativeTWikiSearch module
use ExtUtils::MakeMaker;
WriteMakefile(
   NAME => 'NativeTWikiSearch',
   OBJECT => 'NativeTWikiSearch.o cgrep.o',
   LIBS => [ "-lpcre" ],
   CCFLAGS => "-g",
);
