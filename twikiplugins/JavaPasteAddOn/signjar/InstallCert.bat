call SetupEnv.bat

copy %SIGNEDJAR% %LOCALUSERPROFILEDIR%
copy %CERTIFICATEFILE% %LOCALUSERPROFILEDIR%

cd %LOCALUSERPROFILEDIR%
keytool -import -alias user -file %CERTIFICATEFILE% -keystore %KEYSTORE% -storepass %STOREPASS%
pause
