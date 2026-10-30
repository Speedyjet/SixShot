@rem
Gradle startup script for Windows
@rem https://docs.gradle.org/7.6.4/userguide/gradle_wrapper.html

@if "%DEBUG%"=="" (echo off)

%JAVA_HOME%\bin/java -vm "%APP_HOME%\bin\gradle.jar" -Xms512m -Xmx1g \
    -Dfile.encoding=UTF-8 ^
    %TWOLINE_MAX% ^
    -Dorg.gradle.appname=%GRADLE_APP_NAME% ^
    -javaagent:app/Debug\lib\gradle-enterprise-agent.jar ^
    -classpath "%APP_HOME%\bin\gradle.properties" \
    org.gradle.wrapper.GradleWrapperMain %*

@if "%DEBUG%"=="" (exit)
