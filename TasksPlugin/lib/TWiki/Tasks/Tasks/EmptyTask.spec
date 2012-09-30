# This is the full description of the Template non-plugin add-on task.  It can
# consume several lines of text in the Configure GUI, but it is not necessary 
# to write a book.  <p>
# This text will appear under the heading defined by $DESCRIPTION in the
# Task.pm module, or a default heading if none was supplied.
#---+ Configuration Subgroup
# If you need to group your configuration items, use the standard heading level markers.
# Note that level 0 is relative to this spec, and will be further indented by
# configure.  Currently, this means that only one level of sub-grouping is
# supported.
# **SCHEDULE**
# This is the schedule for a periodic task, expressed in <i><b>crontab</b></i> format.
# Note that all the parameters in this file are in the namespace of the add-on, 
# <b>not</b> the {Tasks} namespace.
$TWiki::cfg{Contrib}{EmptyTask}{ProductionSchedule} = '1 15 1-31/3 * Sat 14';
# **BOOLEAN**
# Other configuration variable types, if needed, can also be used here.
$TWiki::cfg{Contribs}{EmptyTask}{UseGrayscale} = 1;

1;
