1. do minimal changes that achieve the goal
2. write only important comments
3. `test` directory structure follows `lib` directory structure, except generated feature tests go directly in `test/features/`
4. 1 test file per 1 source file
5. the test name follows this pattern: {action} should {do what} when {what happen}
6. capture the flutter screenshots in the `features/screenshots/<page/component>` directory
7. capture the android screenshots in the `android/screenshots/<page/component>` directory
8. the flutter and android screenshot name follows this pattern: {page/component}_when_{what_happen}
9. capture the patrol screenshots in the `features/screenshots/e2e` directory
10. the patrol screenshot name follows this pattern: {2_digits_sequence}_{description}
11. use `powershell` to run shell command
12. in feature files, add a blank line before each When clause if it's after a Then clause
13. save failed screenshots beside their references with `_FAILED` before the file extension and include them in Git
14. Put all `.feature` files directly in `features/`; do not create subdirectories for feature files.
15. Put feature step files directly in `features/steps/<category>/`; do not create subdirectories inside a category.
16. For screen and widget features, use the feature filename without `.feature` as the step category. Keep the existing Patrol category `app_journey`.
17. Put shared Cucumber runner support directly in `features/steps/`; keep category-specific support directly in its category directory.
18. In feature files, group scenarios with similar actions under descriptive `Rule` blocks when this improves organization.
