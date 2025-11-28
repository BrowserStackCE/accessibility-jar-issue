package com.browserstack.tests;

public class RunCucumberTest {

    public static void main(String[] args) {
        // We call Cucumber's built-in main method

        System.out.println("Starting Cucumber test execution from main()...");

        // These arguments are the same as what you'd pass on the command line
        String[] cucumberArgs = {
                // Specifies the package where step definitions are
                "--glue", "com.browserstack.tests.StepDef",

                // Specifies the path to the feature files
                "classpath:features"

                // You could add other arguments here, like:
                // "--plugin", "pretty",
                // "--tags", "@smoke"
        };

        try {
            // Run Cucumber
            // We use the classloader to ensure it finds features in /resources
            byte exitStatus = io.cucumber.core.cli.Main.run(
                    cucumberArgs,
                    Thread.currentThread().getContextClassLoader()
            );

            System.out.println("Cucumber execution finished. Exit status: " + exitStatus);

            // Optionally, explicitly exit with the status from Cucumber
            // This is useful for CI/CD pipelines
            System.exit(exitStatus);

        } catch (Throwable e) {
            System.err.println("Cucumber execution failed!");
            e.printStackTrace();
            System.exit(1); // Exit with a failure status
        }
    }
}

