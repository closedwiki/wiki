/* Copyright (C) 2007 WikiRing http://wikiring.com All Rights Reserved
 * Author: Crawford Currie
 * Fast grep function designed for use from Perl. Does not suffer from
 * limitations of `grep` viz. cost of spawning a subprocess, and
 * limits on command-line length.
 */
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include <pcreposix.h>

#define LINEBUFSIZE  4192
#define ERRBUFSIZE   256
#define MATCHBUFSIZE 1

/* Copy the static match buffer into heap memory, resizing as required */
char** _backup(int mc, char** m, char** r) {
    int curlen = 0;
    char** newR;
    if (!mc) {
        return r;
    }
    if (r) {
        while (r[curlen]) {
            curlen++;
        }
    }
    newR = (char**)safemalloc(sizeof(char*) * (curlen + mc + 1));
    if (curlen) {
        memcpy(newR, r, sizeof(char*) * curlen);
    }
    memcpy(&newR[curlen], m, sizeof(char*) * mc);
    newR[curlen + mc] = (char*)NULL;
    if (r) {
        safefree(r);
    }

    return newR; 
}

/* Do a grep. Arguments are provided in argv, options first, then the
 * pattern, then the file names. -i (case insensitive) and -l (report
 * matching file names only) are the only options supported. */
char** cgrep(char** argv) {
    char** argptr = argv;
    int reflags = REG_NOSUB;
    int justFiles = 0;
    FILE* f;
    regex_t pattern;
    regmatch_t match;
    char linebuf[LINEBUFSIZE];
    char* matchCache[MATCHBUFSIZE];
    int matchCacheSize = 0;
    char** result = (char**)NULL;
    int resultSize;
    char* fname;

    while (*argptr) {
        char* arg = *(argptr++);
        if (strcmp(arg, "-i") == 0) {
            reflags |= REG_ICASE;
            safefree(arg);
        } else if (strcmp(arg, "-l") == 0) {
            justFiles = 1;
            safefree(arg);
        } else {
            int ern;
            if (ern = regcomp(&pattern, arg, reflags)) {
                char erb[ERRBUFSIZE];
                regerror(ern, &pattern, erb, ERRBUFSIZE);
                warn(erb);
                safefree(arg);
                return (char**)NULL;
            }
            safefree(arg);
            break;
        }
    }
    while (*argptr) {
        fname = *(argptr++);
        f = fopen(fname, "r");
        if (f) {
            int ern;
            int mi;
            int size;
            char ch = 0;
            while (ch >= 0) {
                int chc = 0;
                while ((ch = fgetc(f)) >= 0) {
                    if (ch == '\n' || chc == LINEBUFSIZE - 1) {
                        break; /* got a lineful */
                    }
                    linebuf[chc++] = ch;
                }
                linebuf[chc] = '\0';
                if ((ern = regexec(&pattern, linebuf, 1, &match, 0)) == 0) {
                    /* Successful match */
                    if (matchCacheSize == MATCHBUFSIZE) {
                        result = _backup(matchCacheSize, matchCache, result);
                        matchCacheSize = 0;
                    }
                    mi = matchCacheSize++;
                    size = strlen(fname);
                    if (!justFiles) {
                        size += 1 + strlen(linebuf);
                    }
                    matchCache[mi] = (char*)safemalloc(size + 1);
                    strcpy(matchCache[mi], fname);
                    if (!justFiles) {
                        strcat(matchCache[mi], ":");
                        strcat(matchCache[mi], linebuf);
                        /* go to next matching line in this file */
                    }
                    if (justFiles) {
                        break; /* go to next file */
                    }
                }
            }        
            fclose(f);
            safefree(fname);
        } else {
            warn("Open failed");
        }
    }
    safefree(argv);
    result = _backup(matchCacheSize, matchCache, result);
    return result;
}

/* Next two functions taken from
 * http://search.cpan.org/src/TBUSCH/Lucene-0.06/Av_CharPtrPtr.cpp
 * and modified
 */
char ** XS_unpack_charPtrPtr(SV* rv )
{
	AV *av;
	SV **ssv;
	char **s;
	int avlen;
	int x;

	if( SvROK( rv ) && (SvTYPE(SvRV(rv)) == SVt_PVAV) )
		av = (AV*)SvRV(rv);
	else {
		warn("XS_unpack_charPtrPtr: rv was not an AV ref");
		return( (char**)NULL );
	}

	/* is it empty? */
	avlen = av_len(av);
	if( avlen < 0 ){
		warn("XS_unpack_charPtrPtr: array was empty");
		return( (char**)NULL );
	}

	/* av_len+2 == number of strings, plus 1 for an end-of-array sentinel.
	 */
	s = (char **)safemalloc( sizeof(char*) * (avlen + 2) );
	if( s == NULL ){
		warn("XS_unpack_charPtrPtr: unable to malloc char**");
		return( (char**)NULL );
	}
	for( x = 0; x <= avlen; ++x ){
		ssv = av_fetch( av, x, 0 );
		if( ssv != NULL ){
			if( SvPOK( *ssv ) ){
				s[x] = (char *)safemalloc( SvCUR(*ssv) + 1 );
				if( s[x] == NULL )
					warn("XS_unpack_charPtrPtr: unable to malloc char*");
				else
					strcpy( s[x], SvPV( *ssv, PL_na ) );
			}
			else
				warn("XS_unpack_charPtrPtr: array elem %d was not a string.", x );
		}
		else
			s[x] = (char*)NULL;
	}
	s[x] = (char*)NULL; /* sentinel */
	return( s );
}

/* Used by the OUTPUT typemap for char**.
 * Will convert a C char** to a Perl AV*, freeing the char** and the strings
 * stored in it
 */
void XS_pack_charPtrPtr(SV* st, char **s, int n)
{
	AV *av = newAV();
	SV *sv;
	char **c;

	for( c = s; *c != NULL; ++c ){
		sv = newSVpv( *c, 0 );
        safefree(*c);
		av_push( av, sv );
	}
	sv = newSVrv( st, NULL );	/* upgrade stack SV to an RV */
	SvREFCNT_dec( sv );         /* discard */
	SvRV( st ) = (SV*)av;       /* make stack RV point at our AV */
    safefree(s);
}

MODULE = NativeTWikiSearch     PACKAGE = NativeTWikiSearch

char**
cgrep(argv)
	char ** argv
    PREINIT:
        int count_charPtrPtr;
