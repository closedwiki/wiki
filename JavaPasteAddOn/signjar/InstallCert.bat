call SetupEnv.bat

copy %SIGNEDJAR% %LOCALUSERPROFILEDIR%
copy %CERTIFICATEFILE% %LOCALUSERPROFILEDIR%

cd %LOCALUSERPROFILEDIR%
keytool -delete -alias user -keystore %KEYSTORE% -storepass %STOREPASS%
pause

keytool -import -alias user -file %CERTIFICATEFILE% -keystore %KEYSTORE% -storepass %STOREPASS%
pause
