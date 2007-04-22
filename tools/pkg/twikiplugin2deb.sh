#!/bin/sh -e
#
# this script downloads twiki plugins 
# and turns them into debian packages
#
# Christopher Huhn, GSI <C.Huhn@gsi.de>, 2005
#

CURL=/usr/bin/curl

if [ ! -x $CURL ]
then
    echo "Error : $CURL not found" >&2
    exit 1
fi

# quick'n'dirty list of all plugins:
# curl http://twiki.org/cgi-bin/view/Plugins/WebTopicList?skin=rss | \
#      grep "Plugin$" | cut -f 2 -d ' '


PLUGIN=$1
TWIKI_HOMEURL=http://twiki.org
TWIKI_SCRIPTURLPATH=/cgi-bin
TWIKI_PUBURLPATH=/p/pub/
PLUGINURL=$TWIKI_HOMEURL$TWIKI_PUBURLPATH/Plugins/$PLUGIN/$PLUGIN.zip
PACKAGE=twiki-$(echo $PLUGIN | tr 'A-Z' 'a-z')
# TODO: 
#VERSION=$(date +%Y%m%d)
LAST_MODIFIED="$(HEAD $PLUGINURL | grep Last-Modified: | cut -f 2- -d ' ')"
echo "$PLUGINURL last modified : $LAST_MODIFIED"
 VERSION=$(date -d "$LAST_MODIFIED" +"%y%m%d")
echo "Version : $VERSION"

[ "$DEBEMAIL" ] || DEBEMAIL="$(whoami)@$(cat /etc/mailname)"
# TODO: get the fullname
[ "$DEBFULLNAME" ] || DEBFULLNAME="$(whoami)"


 if [ ! -e $PLUGIN-$VERSION.zip ]; then
        echo "$CURL $PLUGINURL -o $PLUGIN-$VERSION.zip"
       $CURL $PLUGINURL -o $PLUGIN-$VERSION.zip
        touch -d "$LAST_MODIFIED" $PLUGIN-$VERSION.zip
 fi

[ -d $PACKAGE-$VERSION ] || mkdir $PACKAGE-$VERSION

cd $PACKAGE-$VERSION

unzip -u ../$PLUGIN-$VERSION.zip

# Get some info from data/TWiki/$PLUGIN.txt
# Some plugins install to a different web (i. e. JavaDocPlugin). Is that a bug?
if [ -r data/TWiki/$PLUGIN.txt ]; then
	PLUGIN_TOPIC=data/TWiki/$PLUGIN.txt
elif [ -r data/Plugins/$PLUGIN.txt ]; then
	PLUGIN_TOPIC=data/Plugins/$PLUGIN.txt
fi

if [ "$PLUGIN_TOPIC" ]; then
	PLUGIN_AUTHOR=$(sed -ne "s/.* Plugin Author: .* \(TWiki\:\)\?Main[./]\(\S\+\).*/\1/p" $PLUGIN_TOPIC)
	PLUGIN_DESCRIPTION=$(sed -ne "s/.* Set SHORTDESCRIPTION = \(.*\)/\1/p" $PLUGIN_TOPIC)
	PLUGIN_VERSION=$(sed -ne "s/.* Plugin Version: | \(.*\)|/\1/p" $PLUGIN_TOPIC)
fi

#TODO: process dependencies of perl stuff:
# for PERL_MODULE in $(egrep -h "^\s*(use|require)" $(find lib/ -name *.pm) | sort | uniq); do ...; done

mkdir debian

##### debian/changelog ######

cat <<EOF > debian/changelog
$PACKAGE ($VERSION-1) unstable; urgency=low

  * Initial debianization with twikiplugin2deb

 -- $DEBFULLNAME <$DEBEMAIL>  $(date -R)

EOF

##### debian/control ######
#
# Versioned build-depend for dh_perl
#
cat <<EOF > debian/control
Source: $PACKAGE
Section: web
Priority: optional
Build-Depends: debhelper (>= 3.0.18)
Maintainer: $DEBFULLNAME  <$DEBEMAIL>
Standards-Version: 3.6.1.1

Package: $PACKAGE
Architecture: all
Depends: \${perl:Depends}, twiki
Description: $PLUGIN_DESCRIPTION
 .
 This TWiki plugin was debianized by twikiplugin2deb. 
 Take a look at $TWIKI_HOMEURL$TWIKI_SCRIPTURLPATH/view/Plugins/$PLUGIN
 for more info
EOF

cat <<EOF > debian/copyright
This package was debianized with twikiplugin2deb by $DEBFULLNAME <$DEBEMAIL> on
$(date -R)

It was downloaded from: $TWIKI_HOMEURL$TWIKI_SCRIPTURLPATH/view/Plugins/$PLUGIN

Upstream author: $(echo $PLUGIN_AUTHOR | sed -e "s/\(.\)\([A-Z]\)/\1 \2/g") <$TWIKI_HOMEURL$TWIKI_SCRIPTURLPATH/view/Main/$PLUGIN_AUTHOR>

Copyright 1999-2005 by the contributing authors. All material on this collaboration 
platform is the property of the contributing authors. 

You are free to distribute this software under the terms of
the GNU General Public License.
On Debian systems, the complete text of the GNU General Public
License can be found in the file /usr/share/common-licenses/GPL
EOF

##### debian/rules ######

cat <<EOF > debian/rules
#!/usr/bin/make -f

# Uncomment this to turn on verbose mode.
#export DH_VERBOSE=1

# This is the debhelper compatibility version to use.
export DH_COMPAT=4

build: build-stamp
build-stamp:
	dh_testdir
	touch build-stamp

clean:
	dh_testdir
	dh_testroot
	rm -f build-stamp
	dh_clean 

install: build
	dh_testdir
	dh_testroot
	dh_clean -k
	dh_installdirs
	dh_install bin/* usr/lib/cgi-bin/twiki
	dh_install data/* var/lib/twiki/data
	dh_install lib/* usr/share/perl5
	dh_install pub/* var/www/twiki/pub
	dh_install templates/* var/lib/twiki/templates
#	TODO: what's happening to arbitrary files 
#   TODO: call a script for package specific tasks?

binary-indep: build install
	dh_testdir
	dh_testroot
#	dh_installdebconf
	dh_installdocs
#	dh_installexamples
#	dh_installmenu
#	dh_installlogrotate
#	dh_installemacsen
#	dh_installpam
#	dh_installmime
#	dh_installinit
#	dh_installcron
#	dh_installman
#	dh_installinfo
#	dh_undocumented
	dh_installchangelogs 
	dh_link
	dh_strip
	dh_compress
	dh_fixperms
# 	dh_makeshlibs
	dh_installdeb
	dh_perl
	dh_shlibdeps
	dh_gencontrol
	dh_md5sums
	dh_builddeb

binary-arch:
binary: binary-indep binary-arch
.PHONY: build clean binary-indep binary-arch binary
EOF

chmod +x debian/rules

#fakeroot dpkg-buildpackage -uc -us
fakeroot dpkg-buildpackage -b -uc
