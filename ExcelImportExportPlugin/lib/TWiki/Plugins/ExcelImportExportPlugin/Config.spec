# ---+ Extensions
# ---++ ExcelImportExportPlugin
# **STRING**
# Change this to specify where to save a temporary excel file.
$TWiki::cfg{Plugins}{ExcelImportExportPlugin}{TmpDir} = '';
# **PERL H**
# This setting is required to enable executing the excel2topics
$TWiki::cfg{SwitchBoard}{excel2topics} = ['TWiki::Plugins::ExcelImportExportPlugin::Import', 'excel2topics', {}];
# **PERL H**
# This setting is required to enable executing the table2excel
$TWiki::cfg{SwitchBoard}{table2excel} = ['TWiki::Plugins::ExcelImportExportPlugin::Export', 'table2excel', {}];
# **PERL H**
# This setting is required to enable executing the topics2excel
$TWiki::cfg{SwitchBoard}{topics2excel} = ['TWiki::Plugins::ExcelImportExportPlugin::Export', 'topics2excel', {}];
# **PERL H**
# This setting is required to enable executing the uploadexcel2table
$TWiki::cfg{SwitchBoard}{uploadexcel} = ['TWiki::Plugins::ExcelImportExportPlugin::Import', 'uploadexcel2table', {}];

1;
