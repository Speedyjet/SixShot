FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    wget \
    curl \
    git \
    unzip \
    openjdk-17-jdk \
    socat \
    && rm -rf /var/lib/apt/lists/*

ENV ANDROID_HOME=/opt/android-sdk
ENV PATH="${PATH}:${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools:${ANDROID_HOME}/emulator"

RUN mkdir -p ${ANDROID_HOME}/cmdline-tools \
    && cd ${ANDROID_HOME}/cmdline-tools \
    && wget -q https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip -O cmdline-tools.zip \
    && unzip -q cmdline-tools.zip \
    && rm cmdline-tools.zip \
    && mv cmdline-tools latest

RUN yes | sdkmanager --licenses \
    && sdkmanager \
       "platform-tools" \
       "platforms;android-29" \
	   "build-tools;30.0.3" \
       "build-tools;29.0.3"

# Download and install Gradle 7.6.4
RUN wget -q https://services.gradle.org/distributions/gradle-7.6.4-bin.zip \
    && unzip -q gradle-7.6.4-bin.zip -d /opt/gradle \
    && rm gradle-7.6.4-bin.zip

ENV GRADLE_HOME=/opt/gradle/gradle-7.6.4
ENV PATH="${GRADLE_HOME}/bin:${PATH}"

WORKDIR /workspace