import AppKit
import Combine
import Darwin
import IOKit.ps

struct ResourceSample: Equatable {
    var cpu: Double?
    var memoryGB: Double?
    var totalMemoryGB = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824
    var batteryPercent: Int?
    var charging = false
    var onAC = false
    var updatedAt: Date?
}

@MainActor
final class ResourceMonitor: ObservableObject {
    @Published private(set) var sample = ResourceSample()
    @Published private(set) var history: [Double] = []
    private var timer: Timer?
    private var systemEnabled = false
    private var batteryEnabled = false
    private var interval: TimeInterval = 3
    private var previousCPU: (UInt64, UInt64)?
    deinit { timer?.invalidate() }
    var isSampling: Bool { timer != nil }
    func configure(system: Bool, battery: Bool, interval: TimeInterval) {
        guard system != systemEnabled || battery != batteryEnabled || interval != self.interval else { return }
        if system && !systemEnabled { sample.cpu = nil }
        systemEnabled = system
        batteryEnabled = battery
        self.interval = interval
        timer?.invalidate()
        timer = nil
        if !system { previousCPU = nil }
        guard system || battery else { return }
        tick()
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        timer.tolerance = interval * 0.2
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }
    private func tick() {
        var value = sample
        if systemEnabled {
            var cpu = host_cpu_load_info()
            var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
            let result = withUnsafeMutablePointer(to: &cpu) { pointer in
                pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count) }
            }
            if result == KERN_SUCCESS {
                let ticks = cpu.cpu_ticks
                let used = UInt64(ticks.0) + UInt64(ticks.1) + UInt64(ticks.3)
                let total = used + UInt64(ticks.2)
                if let previousCPU, total > previousCPU.1, used >= previousCPU.0 {
                    value.cpu = min(1, Double(used - previousCPU.0) / Double(total - previousCPU.1))
                    history.append(value.cpu ?? 0)
                    if history.count > 40 { history.removeFirst(history.count - 40) }
                }
                previousCPU = (used, total)
            }
            var memory = vm_statistics64()
            var memoryCount = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
            let memoryResult = withUnsafeMutablePointer(to: &memory) { pointer in
                pointer.withMemoryRebound(to: integer_t.self, capacity: Int(memoryCount)) { host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &memoryCount) }
            }
            if memoryResult == KERN_SUCCESS {
                let pages = UInt64(memory.active_count) + UInt64(memory.wire_count) + UInt64(memory.compressor_page_count)
                value.memoryGB = Double(pages) * Double(vm_kernel_page_size) / 1_073_741_824
            }
        }
        if batteryEnabled, let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(), let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] {
            value.batteryPercent = nil
            value.onAC = true
            for source in list {
                guard let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                      let current = description[kIOPSCurrentCapacityKey] as? Int,
                      let maximum = description[kIOPSMaxCapacityKey] as? Int, maximum > 0 else { continue }
                value.batteryPercent = min(100, max(0, Int(Double(current) / Double(maximum) * 100)))
                value.charging = description[kIOPSIsChargingKey] as? Bool ?? false
                value.onAC = description[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue
                break
            }
        }
        value.updatedAt = Date()
        sample = value
    }
}
