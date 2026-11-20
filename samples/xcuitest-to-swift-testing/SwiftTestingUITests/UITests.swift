import Testing
import XCUIAutomation

/// Parent suite. `.serialized` is applied to every suite nested in it.
@Suite(.serialized) enum UITests {}

/// Parent suite without `.serialized`, only for the parallel experiment.
@Suite enum UnserializedUITests {}
