import Testing
@testable import CancelLab

@Suite struct CancelLabTests {
    private func log() -> Log { Log(name: "test", echo: false) }

    @Test func cancelThenRemoveBringsTheKeyBack() async {
        #expect(await Experiments.cancelThenRemove(log: log()).keyIsBack)
    }

    @Test func checkingBeforeWriteWorksWhenNothingLandsInBetween() async {
        #expect(await Experiments.checkedBeforeWrite(log: log()).keyIsBack == false)
    }

    @Test func checkingBeforeWriteIsNotEnoughWhenCancelLandsInBetween() async {
        #expect(await Experiments.checkedButInterrupted(log: log()).keyIsBack)
    }

    @Test func awaitingTheTaskBeforeRemovingKeepsTheKeyRemoved() async {
        #expect(await Experiments.awaitThenRemove(log: log()).keyIsBack == false)
    }

    @Test func generationGateKeepsTheKeyRemoved() async {
        #expect(await Experiments.generationGate(log: log()).keyIsBack == false)
    }
}
