cd c:\eclipse\workspace\JavaPasteAddOn\signjar\
call InstallCertAndJarLocally.bat
cd c:\eclipse\workspace\JavaPasteAddOn\signjar\
copy %SIGNEDJAR% %ECLIPSEPROJECTDIR%
pause
