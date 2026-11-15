// SystemMonitorWidget.swift
// iGet — OverlayEngine/Widgets
//
// Saniyede bir güncellenen canlı CPU ve RAM kullanım widget'ı.
//
// Veri kaynakları:
//   • CPU  → host_statistics64 (Mach kernel, IOKit gerekmez)
//   • RAM  → host_vm_info64    (Mach kernel)
//
// Güç optimizasyonu:
//   • Ekran kapalıyken (NSScreen.screens boşsa) timer duraklatılır.
//   • Uygulama arkaplandayken örnekleme hızı düşürülür.
//
// Target Membership: iGet
//
// Organization: TwoBit-Dev

import SwiftUI
import Combine
import Darwin   // Mach kernel çağrıları için

// MARK: - SystemStats

/// Anlık CPU ve RAM durumunu taşıyan değer tipi.
public struct SystemStats: Equatable {
    public let cpuUsage:      Double    // 0.0 – 1.0
    public let ramUsedGB:     Double    // Kullanılan RAM (GB)
    public let ramTotalGB:    Double    // Toplam RAM (GB)
    public let ramPressure:   Double    // 0.0 – 1.0 (wired + active / total)

    public var ramUsagePercent: Double { ramTotalGB > 0 ? ramUsedGB / ramTotalGB : 0 }

    public static let zero = SystemStats(
        cpuUsage: 0, ramUsedGB: 0, ramTotalGB: 0, ramPressure: 0
    )
}

// MARK: - SystemMonitor (ViewModel)

@MainActor
public final class SystemMonitor: ObservableObject {

    // MARK: Published

    @Published public private(set) var stats:        SystemStats  = .zero
    @Published public private(set) var cpuHistory:   [Double]     = Array(repeating: 0, count: 60)
    @Published public private(set) var ramHistory:   [Double]     = Array(repeating: 0, count: 60)
    @Published public private(set) var isRunning:    Bool         = false

    // MARK: Configuration

    public var updateInterval: TimeInterval = 1.0 {
        didSet { restart() }
    }

    // MARK: Private

    private var timer:              AnyCancellable?
    private var previousCPUInfo:    processor_info_array_t?
    private var previousCPUInfoSize: mach_msg_type_number_t = 0
    private var screenObserver:     NSObjectProtocol?
    private var appObserver:        NSObjectProtocol?

    // MARK: Init / Deinit

    public init(interval: TimeInterval = 1.0) {
        self.updateInterval = interval
    }

    deinit {
        [screenObserver, appObserver].compactMap { $0 }.forEach {
            NotificationCenter.default.removeObserver($0)
        }
        // Eski CPU bilgisini serbest bırak
        if let prev = previousCPUInfo {
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: prev), vm_size_t(previousCPUInfoSize))
        }
    }

    // MARK: - Lifecycle

    public func start() {
        guard !isRunning else { return }
        isRunning = true
        scheduleTimer()
        observeScreenAndApp()
    }

    public func stop() {
        isRunning = false
        timer?.cancel()
        timer = nil
    }

    public func restart() {
        stop()
        start()
    }

    // MARK: - Timer

    private func scheduleTimer() {
        timer = Timer.publish(every: updateInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                Task { @MainActor in
                    self.tick()
                }
            }
    }

    private func tick() {
        let cpu = readCPUUsage()
        let ram = readRAMInfo()

        stats = SystemStats(
            cpuUsage:    cpu,
            ramUsedGB:   ram.used,
            ramTotalGB:  ram.total,
            ramPressure: ram.pressure
        )

        // Geçmiş dizisini kaydır
        cpuHistory.removeFirst(); cpuHistory.append(cpu)
        ramHistory.removeFirst(); ramHistory.append(ram.used / max(ram.total, 1))
    }

    // MARK: - CPU Reading (host_processor_info)

    /// Mach kernel host_processor_info ile her çekirdek için CPU tik sayaçlarını okur.
    /// Önceki okuma ile fark alınarak kullanım yüzdesi hesaplanır.
    private func readCPUUsage() -> Double {
        var numCPUs: natural_t = 0
        var cpuInfo:   processor_info_array_t?
        var numCPUInfo: mach_msg_type_number_t = 0

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &numCPUs,
            &cpuInfo,
            &numCPUInfo
        )

        guard result == KERN_SUCCESS, let cpuInfo else { return 0 }

        var totalUsed:  Double = 0
        var totalTicks: Double = 0

        let count = Int(numCPUs)
        for i in 0..<count {
            let base = Int32(CPU_STATE_MAX) * Int32(i)

            let user   = Double(cpuInfo[Int(base) + Int(CPU_STATE_USER)])
            let system = Double(cpuInfo[Int(base) + Int(CPU_STATE_SYSTEM)])
            let nice   = Double(cpuInfo[Int(base) + Int(CPU_STATE_NICE)])
            let idle   = Double(cpuInfo[Int(base) + Int(CPU_STATE_IDLE)])

            if let prev = previousCPUInfo {
                let pUser   = Double(prev[Int(base) + Int(CPU_STATE_USER)])
                let pSystem = Double(prev[Int(base) + Int(CPU_STATE_SYSTEM)])
                let pNice   = Double(prev[Int(base) + Int(CPU_STATE_NICE)])
                let pIdle   = Double(prev[Int(base) + Int(CPU_STATE_IDLE)])

                let dUser   = user   - pUser
                let dSystem = system - pSystem
                let dNice   = nice   - pNice
                let dIdle   = idle   - pIdle
                let dTotal  = dUser + dSystem + dNice + dIdle

                if dTotal > 0 {
                    totalUsed  += dUser + dSystem + dNice
                    totalTicks += dTotal
                }
            }
        }

        // Eski belleği serbest bırak
        if let prev = previousCPUInfo {
            vm_deallocate(
                mach_task_self_,
                vm_address_t(bitPattern: prev),
                vm_size_t(previousCPUInfoSize)
            )
        }

        previousCPUInfo     = cpuInfo
        previousCPUInfoSize = numCPUInfo

        return totalTicks > 0 ? min(totalUsed / totalTicks, 1.0) : 0
    }

    // MARK: - RAM Reading (host_statistics64)

    private struct RAMInfo {
        var used: Double; var total: Double; var pressure: Double
    }

    /// Mach kernel host_statistics64 ile fiziksel bellek bilgisini okur.
    private func readRAMInfo() -> RAMInfo {
        var vmStats = vm_statistics64()
        var count   = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else { return RAMInfo(used: 0, total: 0, pressure: 0) }

        let pageSize  = Double(vm_page_size)
        let totalGB   = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824

        let active    = Double(vmStats.active_count)   * pageSize
        let wired     = Double(vmStats.wire_count)     * pageSize
        let compressed = Double(vmStats.compressor_page_count) * pageSize

        let usedBytes = active + wired + compressed
        let usedGB    = usedBytes / 1_073_741_824

        // Bellek baskısı: wired + active / total
        let pressureBytes = (wired + active) / (totalGB * 1_073_741_824)

        return RAMInfo(
            used:     min(usedGB,  totalGB),
            total:    totalGB,
            pressure: min(pressureBytes, 1.0)
        )
    }

    // MARK: - Power Optimization

    /// Ekran uyku/uyanış ve uygulama arka-plan geçişlerini izler.
    private func observeScreenAndApp() {
        // Ekran kapandığında duraklat
        screenObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.screensDidSleepNotification,
            object: nil, queue: .main
        ) { [weak self] _ in self?.timer?.cancel() }

        // Ekran açıldığında devam et
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.screensDidWakeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in self?.scheduleTimer() }

        // Uygulama arka plana geçince örnekleme hızını düşür
        appObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.timer?.cancel()
            self.timer = Timer.publish(every: 5.0, on: .main, in: .common)
                .autoconnect()
                .sink { [weak self] _ in self?.tick() }
        }

        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.scheduleTimer()
        }
    }
}

// MARK: - SystemMonitorWidgetView

/// Overlay katmanında gösterilen CPU + RAM canlı monitör arayüzü.
public struct SystemMonitorWidgetView: View {

    // MARK: Properties

    public let config: WidgetConfig
    @Environment(\.widgetTheme) private var theme
    @StateObject private var monitor: SystemMonitor

    // MARK: Init

    public init(config: WidgetConfig) {
        self.config = config
        let interval = Double(config.metadata["updateInterval"] ?? "1.0") ?? 1.0
        _monitor = StateObject(wrappedValue: SystemMonitor(interval: interval))
    }

    // MARK: Body

    public var body: some View {
        ZStack {
            // Arkaplan
            background

            VStack(alignment: .leading, spacing: 10) {
                header
                Divider().opacity(0.3)
                cpuSection
                ramSection
            }
            .padding(14)
        }
        .frame(width: config.size.size.width, height: config.size.size.height)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous))
        .onAppear  { monitor.start() }
        .onDisappear { monitor.stop()  }
    }

    // MARK: - Subviews

    private var background: some View {
        Group {
            if theme.blurBackground {
                VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
            } else {
                Color.black.opacity(theme.opacity)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "cpu")
                .foregroundStyle(theme.accentColor)
                .font(.system(size: 13, weight: .semibold))
            Text(config.title ?? "Sistem Monitörü")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
            Spacer()
            // Canlı göstergesi (yeşil nabız)
            Circle()
                .fill(.green)
                .frame(width: 7, height: 7)
                .opacity(monitor.isRunning ? 1 : 0.3)
        }
    }

    private var cpuSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label("CPU", systemImage: "cpu.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "%.1f%%", monitor.stats.cpuUsage * 100))
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(cpuColor)
            }

            // Gradient bar
            UsageBar(value: monitor.stats.cpuUsage, color: cpuColor)

            // Geçmiş sparkline
            SparklineView(values: monitor.cpuHistory, color: cpuColor)
                .frame(height: 20)
        }
    }

    private var ramSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label("RAM", systemImage: "memorychip.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "%.1f / %.0f GB", monitor.stats.ramUsedGB, monitor.stats.ramTotalGB))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(ramColor)
            }

            UsageBar(value: monitor.stats.ramUsagePercent, color: ramColor)

            SparklineView(values: monitor.ramHistory, color: ramColor)
                .frame(height: 20)
        }
    }

    // MARK: - Helpers

    private var cpuColor: Color {
        let v = monitor.stats.cpuUsage
        if v > 0.85 { return .red    }
        if v > 0.60 { return .orange }
        return theme.accentColor
    }

    private var ramColor: Color {
        let v = monitor.stats.ramUsagePercent
        if v > 0.90 { return .red    }
        if v > 0.70 { return .orange }
        return Color(hex: "#30D158")   // macOS yeşil
    }
}

// MARK: - UsageBar

/// Yüzde değerini animasyonlu bar olarak gösterir.
private struct UsageBar: View {
    let value: Double   // 0.0 – 1.0
    let color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.08))
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.7), color],
                            startPoint: .leading,
                            endPoint:   .trailing
                        )
                    )
                    .frame(width: geo.size.width * max(0, min(value, 1)))
                    .animation(.linear(duration: 0.4), value: value)
            }
        }
        .frame(height: 6)
    }
}

// MARK: - SparklineView

/// Son N değerden oluşan mini çizgi grafiği.
private struct SparklineView: View {
    let values: [Double]
    let color:  Color

    var body: some View {
        Canvas { ctx, size in
            guard values.count > 1 else { return }

            let stepX = size.width / Double(values.count - 1)
            let maxV  = max(values.max() ?? 1, 0.001)

            var path = Path()
            for (i, v) in values.enumerated() {
                let x = Double(i) * stepX
                let y = size.height * (1.0 - v / maxV)
                i == 0 ? path.move(to: CGPoint(x: x, y: y))
                       : path.addLine(to: CGPoint(x: x, y: y))
            }

            ctx.stroke(path, with: .color(color.opacity(0.8)), lineWidth: 1.5)
        }
    }
}

// MARK: - VisualEffectBlur (NSViewRepresentable)

/// NSVisualEffectView'ü SwiftUI'ya açar.
public struct VisualEffectBlur: NSViewRepresentable {
    public var material:     NSVisualEffectView.Material
    public var blendingMode: NSVisualEffectView.BlendingMode

    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material     = material
        view.blendingMode = blendingMode
        view.state        = .active
        return view
    }

    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material     = material
        nsView.blendingMode = blendingMode
    }
}
