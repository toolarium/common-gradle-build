# common-gradle-build
[![License](https://img.shields.io/github/license/toolarium/common-gradle-build)](https://opensource.org/licenses/GPL-3.0)

<img align="right" height="110" src="docs/logo/common-gradle-build-small.png">

Defines common gradle build scripts.

This project helps you to have a fast and stable gradle build.

1. Install [gradle](https://gradle.org/install/) be sure you can call gradle on command line by typing `gradle`
2. Create a project directory, e.g. *my-java-lib*, `mkdir my-java-lib`
3. Change on command line into the directory, `cd my-java-lib`
4. Create a *build.gradle* file and start gradle:
   - On Windows `echo apply from: "https://git.io/JfDQT" > build.gradle & gradle`
   - On Linux or Mac `echo apply from: \"https://git.io/JfDQT\" > build.gradle && gradle`

   ***
   Alternative you can do this in two steps:
   Create a *build.gradle* file with content: 
   ```
   apply from: "https://raw.githubusercontent.com/toolarium/common-gradle-build/master/gradle/common.gradle"
   ```
   or as shorten URL:
   ```
   apply from: "https://git.io/JfDQT"
   ```
   Start *gradle*: ``` gradle ```
