#!/bin/sh
# Cron script that refreshes the develop installs

ROOT=$HOME
COMMIT_FLAG=$ROOT/svncommit
UPDATE=pub/latest_$USER.txt

WEBS="Main TWiki Sandbox _default Trash TestCases"

# make sure we know where we are
cd $ROOT/twikisvn

echo -n "Update started at "
date

echo -n "Last update was to "
cat $UPDATE

# /tmp/svncommit is created by an svn hook on a checkin
# See post-commit.pl
if [ ! -e $COMMIT_FLAG ]; then
    echo "No new updates; exiting"
    exit;
fi
rev=`cat $COMMIT_FLAG`
rm -f $COMMIT_FLAG

# Uninstall plugins *before* the update, in case MANIFESTs change
perl pseudo-install.pl -uninstall default>>/dev/null

# Cleanup.
# Delete wrongly created files in shipped webs
# Revert modified files
for web in $WEBS; do
    # Note: ignores changes to properties
    svn status --no-ignore data/$web pub/$web \
        | egrep '^(I|\?|M|C)' \
        | sed 's/^\(I\|\?\)...../rm -rf/' \
        | sed 's/^\(M\|C\)...../svn revert/' \
        | sh
done

/usr/bin/svn update
perl pseudo-install.pl -link default >>/dev/null

cat bin/LocalLib.cfg.txt \
    | sed 's#^$twikiLibPath.*$#$twikiLibPath="'$ROOT'/twikisvn/lib";#g' \
    > bin/LocalLib.cfg

echo "Updated to $rev"
echo $rev > $UPDATE
