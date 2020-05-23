# common-gradle-build
Defines common gradle build scripts.

This project helps you to have a fast and stable gradle build.

1. Install [gradle](https://gradle.org/install/)
2. Create a project directory, e.g. *my-java-lib*
3. Create a *build.gradle* file with content: 
```
apply from: "https://raw.githubusercontent.com/toolarium/common-gradle-build/master/gradle/java-library.gradle"
```
4. Start *gradle*: ``` gradle ```
