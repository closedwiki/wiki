#!/bin/sh
here=`pwd`/
for dir in twikiplugins/*Plugin; do
    plugin=`basename dir`
    if [ -d twikiplugins/$plugin/pub/TWiki/$plugin ]; then
        link=pub/TWiki/$plugin
        if [ -L pub/TWiki/$plugin ]; then
            rm $link
        fi
        ln -s $heretwikiplugins/$plugin/pub/TWiki/$plugin $link
    fi
    if [ -d twikiplugins/$plugin/data/TWiki ]; then
        for txt in twikiplugins/$plugin/data/TWiki/*.txt; do
            link=data/TWiki/`basename $txt`
            if [ -L $link ]; then
                rm $link
            fi
            ln -s $here/$txt $link
        done
    fi
    if [ -d twikiplugins/$plugin/templates ]; then
        for tmpl in twikiplugins/$plugin/templates/*.tmpl; do
            link=templates/`basename $tmpl`
            if [ -L $link ]; then
                rm $link
            fi
            ln -s $here$tmpl $link
        done
    fi
done
