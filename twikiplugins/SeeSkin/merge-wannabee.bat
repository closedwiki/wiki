@echo off
:: quick & dirty batch file to help merge the changes between 
:: \\wannabee and local cvs work directory

C:\local\WinMerge\WinMerge.exe j:\twiki\templates c:\docs\matt\Src\twiki\cvs-twikiplugins\seeskin\templates

C:\local\WinMerge\WinMerge.exe j:\twiki\pub\Plugins\SeeSkin c:\docs\matt\Src\twiki\cvs-twikiplugins\seeskin\pub\Plugins\SeeSkin
