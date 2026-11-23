import CancelLab
import Foundation

let logDirectory = ProcessInfo.processInfo.environment["CANCEL_LAB_LOG_DIR"].map { URL(fileURLWithPath: $0) }

let runs: [(String, String, (Log) async -> Outcome)] = [
    ("1", "cancel, then remove right away", Experiments.cancelThenRemove),
    ("2a", "check Task.isCancelled before writing, cancel then remove", Experiments.checkedBeforeWrite),
    ("2b", "check Task.isCancelled, but cancel+remove land after the check", Experiments.checkedButInterrupted),
    ("3", "cancel, await task.value, then remove", Experiments.awaitThenRemove),
    ("4", "generation gate, same interruption as 2b", Experiments.generationGate),
    ("5a", "removal lands before the job starts, generation read inside the task", Experiments.generationReadInsideTask),
    ("5b", "removal lands before the job starts, generation read before the task", Experiments.generationReadBeforeTask),
]

var summary: [String] = []
for (name, title, run) in runs {
    print("=== Experiment \(name): \(title)")
    let outcome = await run(Log(name: "experiment-\(name)", directory: logDirectory))
    summary.append("\(name): key \(outcome.keyIsBack ? "IS BACK" : "stays removed")")
    print()
}
print("=== Summary")
summary.forEach { print($0) }
