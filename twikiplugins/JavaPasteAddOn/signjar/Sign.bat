@echo off
call SetupEnv.bat


jar cvf %UNSIGNEDJAR% %SOURCEFILES%
@echo on

keytool -genkey -alias %KEYSTOREALIAS% -keystore %KEYSTORE% -keypass %KEYPASS% -dname "cn=MRJC.COM" -storepass %STOREPASS%

jarsigner -keystore %KEYSTORE% -storepass %STOREPASS% -keypass %KEYPASS% -signedjar %SIGNEDJAR% %UNSIGNEDJAR% %KEYSTOREALIAS%
pause

