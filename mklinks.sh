#!/bin/sh
# Usage:
# mklinks.sh [-cp|-echo] <plugin> ...
# Make links from the core into twikiplugins, to pseudo-install these
# components into a subversion checkout area. Default is to process
# all plugins and contribs, or you can do just a subset. You can also
# request a cp instead of ln -s.
#    -cp - copy files from the twikiplugins area instead of linking them.
#    -echo - just print the names of files that would be linked/copied
#    <plugin>... list of plugins and contribs to link into the core.
#    Example: CommentPlugin RenderListPlugin JSCalendarContrib
#    Optional, defaults to all plugins and contribs.
shopt -s nullglob

function mklink () {
    link=`echo $1 | sed -e 's#twikiplugins/[A-Za-z0-9]*/##'`
    if [ -L $link ]; then
        $destroy $link
    fi
    if [ -e $link ]; then
        x=`diff -q $1 $link`
        if [ "$x" = "" ]; then
            $destroy $link
        else
            echo "diff $1 $link different - Keeping $link intact"
        fi
    else
        $build `pwd`/$1 $link
    fi
}

# Main program
if [ "$1" = "-cp" ]; then
    shift;
    # must be -r to catch dirs
    build="cp -r"
    destroy="rm -r"
elif [ "$1" = "-echo" ]; then
    shift;
    build="echo"
    destroy="echo"
else
    build="ln -s"
    destroy="rm"
fi

# examine remaining params
params=""
for param in $* ; do
    params="$params twikiplugins/$param"
done

# default is to do all plugins and contribs
if [ "$params" = "" ]; then
    for param in twikiplugins/*Contrib ; do
        params="$params $param"
    done
    for param in twikiplugins/*Plugin ; do
        params="$params $param"
    done
fi

echo $build $params
for dir in $params; do
    module=`basename $dir`
    if [ -d $dir/pub/TWiki/$module ]; then
        mklink $dir/pub/TWiki/$module
    fi
    if [ -d $dir/data/TWiki ]; then
        for txt in $dir/data/TWiki/*.txt; do
            mklink $txt
        done
    fi
    if [ -d $dir/templates ]; then
        for tmpl in $dir/templates/*.tmpl; do
            mklink $tmpl
        done
    fi
done

