package com.browserstack.tests;


import org.junit.Assert;
import org.openqa.selenium.By;
import org.openqa.selenium.WebDriver;
import org.openqa.selenium.chrome.ChromeDriver;
import org.openqa.selenium.support.ui.WebDriverWait;
import org.testng.annotations.AfterMethod;
import org.testng.annotations.BeforeMethod;
import org.testng.annotations.Test;
/*
import org.testng.annotations.AfterMethod;
import org.testng.annotations.BeforeMethod;
import org.testng.annotations.Test;
*/

import java.time.Duration;

public class SampleTest {
    public WebDriver driver;
    public WebDriverWait wait;

    @BeforeMethod
    public void startDriver(){
        driver = new ChromeDriver();
    }

    @Test
    public void searchesGoogle(){
        try {

            System.out.println("[[BSTACK_SET_CUSTOM_TAG||ID=TC-7291]]");
            wait = new WebDriverWait(driver, Duration.ofSeconds(30));

            driver.get("https://the-internet.herokuapp.com/windows");
            Assert.assertTrue(false);

            driver.findElement(By.cssSelector("#content > div > a")).click();

            for(String window:driver.getWindowHandles())
            {
                System.out.println("Window name =>"+window);
                if(!window.contains("DevTools"))
                {
                    driver.switchTo().window(window);
                }
            }

            Thread.sleep(3000);


        }catch(Exception e)
        {
            e.printStackTrace();
        }
    }

    @AfterMethod(alwaysRun = true)
    public void teardown() {
        if(driver !=null)
        {
            driver.quit();
        }
    }
}
