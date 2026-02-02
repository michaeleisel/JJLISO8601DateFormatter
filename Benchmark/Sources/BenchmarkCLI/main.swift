import Foundation
import BenchmarkCore

let runner = BenchmarkRunner()
let report = runner.run()

print("JJLISO8601DateFormatter Benchmark")
print("==================================")
print("")
print("Iterations per batch: \(report.iterationsPerBatch)")
print("Target seconds: \(String(format: "%.2f", report.targetSeconds))")
print("Sample strings:")
for sample in report.sampleStrings {
    print("- \(sample)")
}

func printResults(for operation: BenchmarkOperation) {
    print("")
    print("== \(operation.rawValue) ==")
    let baseline = report.result(for: operation, category: .iso8601DateFormatter)?.runsPerSecond ?? 0
    for category in BenchmarkCategory.allCases {
        guard let result = report.result(for: operation, category: category) else { continue }
        let speedup = baseline > 0 ? result.runsPerSecond / baseline : 0
        print("\(category.rawValue): \(String(format: "%.2f", result.runsPerSecond)) runs/sec (\(String(format: "%.2fx", speedup)))")
    }
}

printResults(for: .dateToString)
printResults(for: .stringToDate)

print("")
print("Markdown tables (paste into README):")
print("")
print("### Date -> String")
print(report.markdownTable(operation: .dateToString))
print("")
print("### String -> Date")
print(report.markdownTable(operation: .stringToDate))
