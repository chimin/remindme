import '../scenario_runner.dart';

Future<void> scenarioStateIsIsolated(ScenarioState state) async {
  state.initialize();
}

Future<void> colorsThatNeedHexadecimalFormatting(ScenarioState state) async {
  await state.prepare('0');
}

Future<void> theColorsAreFormattedAsHexadecimal(ScenarioState state) =>
    state.advance();

Future<void> theResultShouldRenderSixDigitUppercaseHex(ScenarioState state) =>
    state.advance();

Future<void> invalidHexadecimalStrings(ScenarioState state) async {
  await state.prepare('1');
}

Future<void> theInvalidStringsAreParsed(ScenarioState state) => state.advance();

Future<void> theResultShouldReturnNull(ScenarioState state) => state.advance();

Future<void> longAndShortHexadecimalStrings(ScenarioState state) async {
  await state.prepare('2');
}

Future<void> theLongAndShortStringsAreParsed(ScenarioState state) =>
    state.advance();

Future<void> theResultShouldAcceptLongAndShortHex(ScenarioState state) =>
    state.advance();

Future<void> aRedColorPickerWithHexadecimalInput(ScenarioState state) async {
  await state.prepare('3');
}

Future<void> aGreenHexadecimalColorIsSubmitted(ScenarioState state) =>
    state.advance();

Future<void> theResultShouldCallOnchangedWithTheNewColor(ScenarioState state) =>
    state.advance();

Future<void> aRedColorPickerWithAHueSlider(ScenarioState state) async {
  await state.prepare('4');
}

Future<void> theHueSliderIsTapped(ScenarioState state) => state.advance();

Future<void> theResultShouldChangeTheSelectedColor(ScenarioState state) =>
    state.advance();
