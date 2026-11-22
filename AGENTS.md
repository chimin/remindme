1. do minimal changes that achieve the goal
2. write only important comments
3. `test` directory structure follows `lib` directory structure
4. 1 test file per 1 source file
5. the test name follows this pattern: {action} should {do what} when {what happen}
6. capture the flutter screenshots in the `screenshots/<page/component>` directory
7. capture the android screenshots in the `android/screenshots/<page/component>` directory
8. the flutter and android screenshot name follows this pattern: {page/component}_when_{what_happen}
9. capture the patrol screenshots in the `screenshots/e2e` directory
10. the patrol screenshot name follows this pattern: {2_digits_sequence}_{description}
11. use `powershell` to run shell command
12. in feature files, add a blank line before each When clause if it's after a Then clause
