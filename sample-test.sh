BROWSERSTACK_JAR=$(find ~/.m2/repository -name "*browserstack-java-sdk*.jar" | head -1)

# Build classpath
CLASSPATH="target/classes:$(mvn dependency:build-classpath -Dmdep.outputFile=/dev/stdout -q)"

# Escape spaces in paths for exec:exec
CONFIG_PATH="$(pwd)/browserstack.yml"

mvn exec:exec \
  -Dexec.executable="java" \
  -Dexec.args="-javaagent:\"${BROWSERSTACK_JAR}\" -Dbrowserstack.config=\"${CONFIG_PATH}\" -Dbrowserstack.framework=selenium -Dbrowserstack.accessibility=true -Dcucumber.publish.quiet=true -cp \"${CLASSPATH}\" com.browserstack.tests.RunCucumberTest"