@testMethodName:widgetScenario
@testerType:ScenarioState
Feature: color picker
  Background:
    Given scenario state is isolated

  Rule: Formatting hexadecimal colors

    @testMethodName:unitScenario
    Scenario: formatHex should render six digit uppercase hex when valid colors are supplied
      Given colors that need hexadecimal formatting
      When the colors are formatted as hexadecimal
      Then the result should render six digit uppercase hex

  Rule: Parsing hexadecimal colors

    @testMethodName:unitScenario
    Scenario: parseHex should return null when value is invalid
      Given invalid hexadecimal strings
      When the invalid strings are parsed
      Then the result should return null

    @testMethodName:unitScenario
    Scenario: parseHex should accept long and short hex when hex values are supplied
      Given long and short hexadecimal strings
      When the long and short strings are parsed
      Then the result should accept long and short hex

  Rule: Selecting colors

    Scenario: picking a color should call onChanged with the new color when hex values are supplied
      Given a red color picker with hexadecimal input
      When a green hexadecimal color is submitted
      Then the result should call onChanged with the new color

    Scenario: dragging the hue slider should change the selected color when hex values are supplied
      Given a red color picker with a hue slider
      When the hue slider is tapped
      Then the result should change the selected color
