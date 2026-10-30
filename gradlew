#!/bin/sh

##############################################################################
# Gradle startup script for UNIX
##############################################################################

APP_HOME="`dirname "$0"`"
APP_NAME="Gradle"
APP_BASE_NAME=`basename "$0"`
APP_HOME=`cd "$APP_HOME" && pwd`

# Determine the Java command
if [ -n "$JAVA_HOME" ] ; then
    JAVA_EXE="$JAVA_HOME/bin/java"
else
    JAVA_EXE=java
fi
CLASSPATH="$APP_HOME/gradle/wrapper/gradle-wrapper.jar:$APP_HOME/lib/gradle-enterprise-agent.jar"

exec "$JAVA_EXE" -Xms512m -Xmx1g \
    -Dfile.encoding=UTF-8 \
    -classpath "$CLASSPATH" \
    org.gradle.wrapper.GradleWrapperMain "$@"
