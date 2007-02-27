/* Copyright (C) 2007 WikiRing http://wikiring.com All Rights Reserved
 * Author: Crawford Currie
 * Fast grep function designed for use from Perl. Does not suffer from
 * limitations of `grep` viz. cost of spawning a subprocess, and
 * limits on command-line length.
 */
#include <pcre.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>

#define DATABUFSIZE  4192
#define ERRBUFSIZE   256
#define MATCHBUFSIZE 1


/* Copy the static match buffer into heap memory, resizing as required */
char** _backup(int mc, char** m, char** r) {
    int curlen = 0;
    char** newR = NULL;
    if (!mc) {
        return r;
    }
    if (r) {
        while (r[curlen]) {
            curlen++;
        }
        newR = (char**)realloc(r, sizeof(char*) * (curlen + mc + 1));
    }

    if (!newR) {
        newR = (char**)malloc(sizeof(char*) * (mc + 1));
    }

    memcpy(newR + curlen, m, sizeof(char*) * mc);
    newR[curlen + mc] = NULL;

    return newR; 
}

/* Release memory used in the XS interface */
void cleanup(char** argv) {
    char** ptr = argv;

    while (*ptr) {
        free(*ptr);
        ptr++;
    }
    free(argv);
}

/* Do a grep. Arguments are provided in argv, options first, then the
 * pattern, then the file names. -i (case insensitive) and -l (report
 * matching file names only) are the only options supported. */
char** cgrep(char** argv) {
    char** argptr = argv;
    /* Check for UTF8 support using pcre_config */
    int erk;
    int reflags = PCRE_NO_AUTO_CAPTURE;
    int justFiles = 0;
    FILE* f;
    pcre* pattern;
    pcre_extra* study;
    int linebufsize = DATABUFSIZE;
    char* linebuf;
    char* matchCache[MATCHBUFSIZE];
    int matchCacheSize = 0;
    char** result = NULL;
    int resultSize;
    char* fname;
    const char* err;
    int errPos;

    if (pcre_config(PCRE_CONFIG_UTF8, &erk) && erk) {
        reflags |= PCRE_UTF8 | PCRE_NO_UTF8_CHECK;
    }
    while (*argptr) {
        char* arg = *(argptr++);
        if (strcmp(arg, "-i") == 0) {
            reflags |= PCRE_CASELESS;
        } else if (strcmp(arg, "-l") == 0) {
            justFiles = 1;
        } else {
            /* Convert \< and \> to \b in the pattern. GNU grep supports
               them, but pcre doesn't :-( */
            if (*arg) {
                for (linebuf = arg + 1; *linebuf; linebuf++) {
                    if (*linebuf == '\\' && *(linebuf-1) != '\\' &&
                        *(linebuf+1) == '<' || *(linebuf+1) == '>')
                        *(linebuf+1) = 'b';
                }
            }
            if (!(pattern = pcre_compile(arg, reflags, &err, &errPos, NULL))) {
                warn(err);
            }
            if (!pattern) {
                cleanup(argv);
                return NULL;
            }
            break;
        }
    }

    /* Study the pattern to accelerate matching */
    study = pcre_study(pattern, 0, &err);
    if (err) {
        warn(err);
        cleanup(argv);
        return NULL;
    }

    linebuf = malloc(linebufsize);
    while (*argptr) {
        fname = *(argptr++);
        f = fopen(fname, "r");
        if (f) {
            int ern;
            int mi;
            int size;
            char ch = 0;
            int ovec[30];
            int matchResult;
            int chc;
            while ((chc = getline(&linebuf, &linebufsize, f)) > 0) {
                matchResult = pcre_exec(pattern, study, linebuf,
                                        chc, 0, 0, ovec, 30);
                if (matchResult >= 0) {
                    /* Successful match */
                    if (matchCacheSize == MATCHBUFSIZE) {
                        /* Back up the cache if it's full */
                        result = _backup(matchCacheSize, matchCache, result);
                        matchCacheSize = 0;
                    }
                    mi = matchCacheSize++;
                    size = strlen(fname);
                    if (linebuf[strlen(linebuf)-1] == '\n') {
                        linebuf[strlen(linebuf)-1] = '\0';
                    }
                    if (!justFiles) {
                        size += 1 + strlen(linebuf);
                    }
                    matchCache[mi] = (char*)malloc(size + 1);
                    strcpy(matchCache[mi], fname);
                    if (!justFiles) {
                        strcat(matchCache[mi], ":");
                        strcat(matchCache[mi], linebuf);
                        /* go to next matching line in this file */
                    } else {
                        break; /* go to next file */
                    }
                }
            }        
            fclose(f);
        } else {
            warn("Open failed %d", errno);
        }
    }
    free(linebuf);
    result = _backup(matchCacheSize, matchCache, result);
    cleanup(argv);
    return result;
}
