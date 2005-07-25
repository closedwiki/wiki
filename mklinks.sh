#!/bin/sh
shopt -s nullglob
function mklink () {
    link=`echo $1 | sed -e 's#twikiplugins/[A-Za-z0-9]*Plugin/##'`
    if [ -L $link ]; then
        rm $link
    fi
    if [ -e $link ]; then
        x=`diff -q $1 $link`
        if [ "$x" = "" ]; then
            rm $link
        else
            echo "$1 and $link differ - Keeping $link intact"
        fi
    else
        ln -s `pwd`/$1 $link
    fi
}

for dir in twikiplugins/*Plugin; do
    plugin=`basename $dir`
    if [ -d twikiplugins/$plugin/pub/TWiki/$plugin ]; then
        mklink twikiplugins/$plugin/pub/TWiki/$plugin
    fi
    if [ -d twikiplugins/$plugin/data/TWiki ]; then
        for txt in twikiplugins/$plugin/data/TWiki/*.txt; do
            mklink $txt
        done
    fi
    if [ -d twikiplugins/$plugin/templates ]; then
        for tmpl in twikiplugins/$plugin/templates/*.tmpl; do
            mklink $tmpl
        done
    fi
done

