package com.browserstack.tests.StepDef;

import io.cucumber.java.After;
import io.cucumber.java.Before;
import io.cucumber.java.en.Given;
import io.cucumber.java.en.Then;
import org.junit.Assert;
import org.openqa.selenium.By;
import org.openqa.selenium.MutableCapabilities;
import org.openqa.selenium.WebDriver;
import org.openqa.selenium.remote.RemoteWebDriver;

import java.net.MalformedURLException;
import java.net.URL;
import java.util.HashMap;
import java.util.Set;

public class GoogleSteps {

    private WebDriver driver;

    @Before
    public void setUp() throws MalformedURLException {
        // This hook runs before each scenario
        //WebDriverManager.chromedriver().setup();
        MutableCapabilities capabilities = new MutableCapabilities();
        HashMap<String, Object> bstackOptions = new HashMap<String, Object>();
        capabilities.setCapability("browserName", "Chrome");
        bstackOptions.put("os", "Windows");
        bstackOptions.put("osVersion", "10");
        bstackOptions.put("browserVersion", "140.0");
        bstackOptions.put("userName", System.getenv("BROWSERSTACK_USERNAME"));
        bstackOptions.put("accessKey",  System.getenv("BROWSERSTACK_ACCESS_KEY"));
        bstackOptions.put("consoleLogs", "info");
        capabilities.setCapability("bstack:options", bstackOptions);
        //driver = new ChromeDriver();
        driver = new RemoteWebDriver(
                new URL("https://hub.browserstack.com/wd/hub"), capabilities);

    }

    @Given("I open the Google homepage")
    public void iOpenTheGoogleHomepage() {
        driver.get("https://www.bstackdemo.com");
    }

    @Then("I should see the title {string}")
    public void iShouldSeeTheTitle(String expectedTitle) throws InterruptedException {
       /* String actualTitle = driver.getTitle();
        Assertions.assertEquals(expectedTitle, actualTitle, "The page title is not as expected");*/

        // Check the title
        Assert.assertTrue(driver.getTitle().matches("StackDemo"));

        // Save the text of the product for later verify
        String productOnScreenText = driver.findElement(By.xpath("//*[@id=\"1\"]/p")).getText();
        // Click on add to cart button
        driver.findElement(By.xpath("//*[@id=\"1\"]/div[4]")).click();

        // See if the cart is opened or not
        Assert.assertTrue(driver.findElement(By.cssSelector(".float\\-cart__content")).isDisplayed());

        String productOnCartText = driver.findElement(By.cssSelector(".float-cart__content .title")).getText();
        Assert.assertEquals(productOnScreenText, productOnCartText);

        Thread.sleep(3000);

        String originalWindow = driver.getWindowHandle();

// Get all window handles
        Set<String> allWindows = driver.getWindowHandles();

// Iterate through all handles
        for (String windowHandle : allWindows) {
            driver.switchTo().window(windowHandle);
            String title= driver.getTitle();
            if(title.contains("DevTools"))
            {
                System.out.println("inside Devtools window");
                // Switch back to the original window
                driver.switchTo().window(originalWindow);

            }else
            {
                System.out.println("not a Devtools window ");
            }
            System.out.println("Window Handle: " + windowHandle);
            System.out.println("Window Title: " + driver.getTitle());
        }


        Thread.sleep(3000);

    }

    @After
    public void tearDown() {
        // This hook runs after each scenario
        if (driver != null) {
            driver.quit();
        }
    }
}
