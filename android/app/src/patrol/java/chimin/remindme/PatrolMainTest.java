package chimin.remindme;

import androidx.test.platform.app.InstrumentationRegistry;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.junit.runners.Parameterized;
import org.junit.runners.Parameterized.Parameters;
import pl.leancode.patrol.PatrolJUnitRunner;

/** Explicitly selected by tool/run_patrol.dart; excludes screenshot fixtures. */
@RunWith(Parameterized.class)
public class PatrolMainTest {
    @Parameters(name = "{0}")
    public static Object[] testCases() {
        PatrolJUnitRunner runner =
            (PatrolJUnitRunner) InstrumentationRegistry.getInstrumentation();
        runner.setUp(MainActivity.class);
        runner.waitForPatrolAppService();
        return runner.listDartTests();
    }

    private final String dartTestName;

    public PatrolMainTest(String dartTestName) {
        this.dartTestName = dartTestName;
    }

    @Test
    public void runDartTest() {
        PatrolJUnitRunner runner =
            (PatrolJUnitRunner) InstrumentationRegistry.getInstrumentation();
        runner.runDartTest(dartTestName);
    }
}
