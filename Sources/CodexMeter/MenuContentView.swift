import AppKit
import ServiceManagement
import SwiftUI

struct MenuContentView: View {
    @ObservedObject var store: UsageStore
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginItemError: String?
    @State private var isDailyUsageInfoPresented = false

    var body: some View {
        VStack(spacing: 16) {
            header

            if let snapshot = store.snapshot {
                usageCard(snapshot)
                tokenCards(snapshot)
            } else if store.isLoading {
                loadingView
            } else {
                emptyView
            }

            if let error = store.errorMessage {
                errorView(error)
            }

            footer
        }
        .padding(16)
        .frame(width: 340, height: 322, alignment: .top)
        .task {
            if store.snapshot == nil {
                await store.refresh()
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text("Codex Meter")
                    .font(.headline)
                Text(statusSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let plan = store.snapshot?.planType {
                Text(plan.uppercased())
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.blue.opacity(0.12), in: Capsule())
                    .foregroundStyle(.blue)
            }
        }
    }

    private func usageCard(_ snapshot: UsageSnapshot) -> some View {
        HStack(spacing: 16) {
            Gauge(value: Double(snapshot.usedPercent), in: 0...100) {
                EmptyView()
            } currentValueLabel: {
                Text("\(snapshot.usedPercent)%")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .tint(gaugeColor(for: snapshot.usedPercent))
            .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 6) {
                Text(snapshot.windowLabel)
                    .font(.subheadline.weight(.semibold))
                Text("\(snapshot.remainingPercent)% 남음")
                    .font(.title3.weight(.bold))
                if let resetsAt = snapshot.resetsAt {
                    Text("초기화까지 \(resetsAt, style: .relative)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(14)
        .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 14))
    }

    private func tokenCards(_ snapshot: UsageSnapshot) -> some View {
        HStack(spacing: 10) {
            metricCard(
                title: "일일 토큰",
                value: compact(snapshot.todayTokens),
                icon: "bolt.fill",
                color: .orange,
                infoText: "OpenAI 일일 사용량은 태평양 시간(PT) 기준으로 집계됩니다. 한국 시간으로는 오후 4시(서머타임) 또는 오후 5시에 날짜가 변경됩니다."
            )
            metricCard(
                title: "누적 토큰",
                value: snapshot.lifetimeTokens.map(compact) ?? "-",
                icon: "sum",
                color: .purple
            )
            metricCard(
                title: "연속 사용",
                value: snapshot.currentStreakDays.map { "\($0)일" } ?? "-",
                icon: "flame.fill",
                color: .red
            )
        }
    }

    private func metricCard(
        title: String,
        value: String,
        icon: String,
        color: Color,
        infoText: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(value)
                .font(.subheadline.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            HStack(spacing: 3) {
                Text(title)
                if let infoText {
                    Button {
                        isDailyUsageInfoPresented.toggle()
                    } label: {
                        Image(systemName: "info.circle")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("일일 토큰 집계 기준")
                    .popover(isPresented: $isDailyUsageInfoPresented, arrowEdge: .bottom) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("일일 토큰 집계 기준")
                                .font(.headline)

                            Text(infoText)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        .padding(14)
                        .frame(width: 280, alignment: .leading)
                        .onDisappear {
                            isDailyUsageInfoPresented = false
                        }
                    }
                }
            }
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 11))
    }

    private var loadingView: some View {
        VStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
            Text("Codex 사용량을 불러오는 중…")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
    }

    private var emptyView: some View {
        VStack(spacing: 10) {
            Image(systemName: "gauge.open.with.lines.needle.33percent")
                .font(.title)
                .foregroundStyle(.secondary)
            Text("아직 불러온 사용량이 없습니다.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("사용량 불러오기") {
                Task { await store.refresh() }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 120)
    }

    private func errorView(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
    }

    private var footer: some View {
        VStack(spacing: 8) {
            Divider()
            HStack {
                Button {
                    Task { await store.refresh() }
                } label: {
                    Label("새로고침", systemImage: "arrow.clockwise")
                }
                .disabled(store.isLoading)

                Spacer()

                Menu {
                    Button {
                        toggleLaunchAtLogin()
                    } label: {
                        Label(
                            launchAtLogin ? "로그인 시 실행 끄기" : "로그인 시 실행",
                            systemImage: launchAtLogin ? "checkmark.circle.fill" : "circle"
                        )
                    }
                    Divider()
                    Button("Codex Meter 종료") {
                        NSApplication.shared.terminate(nil)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }

            if let loginItemError {
                Text(loginItemError)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var statusSubtitle: String {
        if store.isLoading { return "업데이트 중" }
        if let lastUpdated = store.lastUpdated {
            return "업데이트 \(lastUpdated.formatted(date: .omitted, time: .shortened))"
        }
        return "메뉴 막대 사용량 확인"
    }

    private func compact(_ value: Int64) -> String {
        value.formatted(.number.notation(.compactName).precision(.fractionLength(0...1)))
    }

    private func gaugeColor(for usedPercent: Int) -> Color {
        switch usedPercent {
        case 85...: return .red
        case 60...: return .orange
        default: return .blue
        }
    }

    private func toggleLaunchAtLogin() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
            launchAtLogin = SMAppService.mainApp.status == .enabled
            loginItemError = nil
        } catch {
            loginItemError = "로그인 항목 변경 실패: \(error.localizedDescription)"
        }
    }
}
