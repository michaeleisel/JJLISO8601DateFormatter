import SwiftUI
import BenchmarkCore
import Foundation
import Combine

@main
struct BenchmarkiOSApp: App {
    var body: some Scene {
        WindowGroup {
            BenchmarkView()
        }
    }
}

struct BenchmarkView: View {
    @StateObject private var model = BenchmarkViewModel()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Button(action: {
                        model.run()
                    }) {
                        Text(model.isRunning ? "Running..." : "Run Benchmarks")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.isRunning)

                    if let report = model.report {
                        BenchmarkSection(title: BenchmarkOperation.dateToString.rawValue, report: report, operation: .dateToString)
                        BenchmarkSection(title: BenchmarkOperation.stringToDate.rawValue, report: report, operation: .stringToDate)
                    } else {
                        Text("No results yet. Run the benchmarks on a physical iOS device in Release mode for accurate numbers.")
                            .foregroundColor(.secondary)
                    }

                    if let error = model.errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
                .padding()
            }
            .navigationTitle("JJL Benchmarks")
        }
    }
}

struct BenchmarkSection: View {
    let title: String
    let report: BenchmarkReport
    let operation: BenchmarkOperation

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            let baseline = report.result(for: operation, category: .iso8601DateFormatter)?.runsPerSecond ?? 0
            ForEach(BenchmarkCategory.allCases, id: \.rawValue) { category in
                if let result = report.result(for: operation, category: category) {
                    HStack {
                        Text(category.rawValue)
                        Spacer()
                        Text("\(String(format: "%.2f", result.runsPerSecond)) runs/sec")
                            .monospacedDigit()
                    }
                    if baseline > 0 {
                        let speedup = result.runsPerSecond / baseline
                        Text("Speedup vs ISO8601DateFormatter: \(String(format: "%.2fx", speedup))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}

@MainActor
final class BenchmarkViewModel: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var report: BenchmarkReport?
    @Published private(set) var errorMessage: String?

    func run() {
        guard !isRunning else { return }
        isRunning = true
        errorMessage = nil

        Task.detached { [iterationsPerBatch = 1000, targetSeconds = 1.0] in
            let runner = BenchmarkRunner(iterationsPerBatch: iterationsPerBatch, targetSeconds: targetSeconds)
            let report = runner.run()
            Self.logReport(report)
            await MainActor.run {
                self.report = report
                self.isRunning = false
            }
        }
    }

    nonisolated private static func logReport(_ report: BenchmarkReport) {
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
    }
}
