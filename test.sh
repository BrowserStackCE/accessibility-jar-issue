BROWSERSTACK_JAR=$(find ~/.m2/repository -name "*browserstack-java-sdk*.jar" | head -1)

# Build classpath
CLASSPATH="target/classes:$(mvn dependency:build-classpath -Dmdep.outputFile=/dev/stdout -q)"

echo $CLASSPATH

# Run with javaagent
java -javaagent:$BROWSERSTACK_JAR -Dcucumber.publish.quiet=true -cp "$CLASSPATH" com.browserstack.tests.RunCucumberTest