package chimin.remindme.support

import io.cucumber.junit.CucumberOptions

@CucumberOptions(
    features = ["features"],
    glue = ["chimin.remindme.steps", "chimin.remindme.support"],
    plugin = ["pretty"],
)
class NativeCucumberOptions
