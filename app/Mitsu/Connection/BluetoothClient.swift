import CoreBluetooth
import Foundation

struct AdapterDevice: Identifiable { let id: UUID; let name: String; let rssi: Int }

@MainActor final class BluetoothClient: NSObject, ObservableObject, @preconcurrency CBCentralManagerDelegate, @preconcurrency CBPeripheralDelegate {
    @Published var devices: [AdapterDevice] = []
    @Published private(set) var status = "Not connected"
    @Published private(set) var ready = false
    @Published private(set) var scanning = false
    var sourceMode:SampleSource = .live {
        didSet{if !sourceMode.permitsVehicleConnection{disconnect();devices=[];found=[:]}}
    }
    var onReady: (() -> Void)?
    var onDisconnect: (() -> Void)?
    private var manager: CBCentralManager?
    private var found: [UUID:CBPeripheral] = [:]
    private var peripheral: CBPeripheral?
    private var tx: CBCharacteristic?
    private var rx: CBCharacteristic?
    private var response: CheckedContinuation<String,Error>?
    private var buffer = PromptBuffer()
    private var timeout: Task<Void,Never>?
    private var connectionTimeout: Task<Void,Never>?
    private var generation=UUID()
    private var lifecycle=BLELifecycle()

    func scan() {
        guard sourceMode.permitsVehicleConnection else{return}
        guard lifecycle.idle else{status="Disconnect the current session before searching again.";return}
        disconnect()
        devices=[]; found=[:]; scanning=true; status="Finding your adapter…"
        if manager == nil { manager=CBCentralManager(delegate:self,queue:.main) }
        else if manager?.state == .poweredOn { startScan() }
        else { centralManagerDidUpdateState(manager!) }
    }
    private func startScan() {
        manager?.scanForPeripherals(withServices:nil,options:[CBCentralManagerScanOptionAllowDuplicatesKey:false])
        let current=generation
        connectionTimeout=Task { try? await Task.sleep(nanoseconds:12_000_000_000); guard !Task.isCancelled, self.generation == current else { return }; self.stopScan() }
    }
    func stopScan() { manager?.stopScan(); scanning=false; if !ready { status=devices.isEmpty ? "No KONNWEI found. Check the adapter's power." : "Choose your KONNWEI adapter" } }
    func connect(_ id: UUID) {
        guard sourceMode.permitsVehicleConnection else{return}
        guard let device=found[id], manager?.state == .poweredOn else { return }
        guard lifecycle.begin(id) else{return}
        connectionTimeout?.cancel(); manager?.stopScan(); scanning=false
        generation=UUID(); peripheral=device; device.delegate=self; status="Connecting…"
        manager?.connect(device,options:nil)
        let current=generation
        connectionTimeout=Task { try? await Task.sleep(nanoseconds:12_000_000_000); guard !Task.isCancelled, self.generation == current, !self.ready else { return }; self.fail("Connection timed out. Try again.") }
    }
    func disconnect() {
        generation=UUID(); connectionTimeout?.cancel(); timeout?.cancel(); manager?.stopScan(); scanning=false
        finishCommand(.failure(CancellationError()))
        ready=false; tx=nil; rx=nil
        if let p=peripheral {
            lifecycle.disconnect(p.identifier)
            if p.state == .disconnected{_=lifecycle.disconnected(p.identifier);peripheral=nil}
            else{manager?.cancelPeripheralConnection(p)}
        }
        status="Not connected"; onDisconnect?()
    }
    private func fail(_ message: String) { disconnect(); status=message }
    func send(_ command: String) async throws -> String {
        guard sourceMode.permitsVehicleConnection else{throw DiagnosticError.invalid("Preview cannot connect to the car")}
        guard ReadPolicy.allowed(command,vehicle:true) else { throw DiagnosticError.invalid("Command is outside the read policy") }
        guard ready, let p=peripheral,lifecycle.phase == .ready(p.identifier), let tx, response == nil, p.canSendWriteWithoutResponse else { throw DiagnosticError.invalid("Adapter is not ready") }
        try Task.checkCancellation()
        let current=generation
        return try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                response=continuation; buffer=PromptBuffer()
                p.writeValue(Data((command+"\r").utf8),for:tx,type:.withoutResponse)
                timeout=Task { try? await Task.sleep(nanoseconds:4_000_000_000); guard !Task.isCancelled, self.generation == current else { return }; self.fail("Adapter reply timed out. Reconnect to resume.") }
            }
        }, onCancel: { Task { @MainActor [weak self] in guard self?.generation == current else { return }; self?.disconnect() } })
    }
    private func finishCommand(_ result: Result<String,Error>) {
        timeout?.cancel(); timeout=nil
        let c=response; response=nil; c?.resume(with:result)
    }
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn: if scanning { startScan() }
        case .unauthorized: fail("Allow Mitsu to use Bluetooth in iPad Settings.")
        case .poweredOff: fail("Turn Bluetooth on in iPad Settings.")
        case .unsupported: fail("Bluetooth is unavailable here. Use Preview in the simulator.")
        case .resetting: fail("Bluetooth is restarting. Try again shortly.")
        default: status="Checking Bluetooth…"
        }
    }
    func centralManager(_ central: CBCentralManager, didDiscover p: CBPeripheral, advertisementData: [String:Any], rssi RSSI: NSNumber) {
        let name=(advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? p.name ?? ""
        guard scanning, name.uppercased().contains("KONNWEI") else { return }
        found[p.identifier]=p
        if !devices.contains(where:{$0.id == p.identifier}) { devices.append(AdapterDevice(id:p.identifier,name:name,rssi:RSSI.intValue)) }
    }
    func centralManager(_ central: CBCentralManager, didConnect p: CBPeripheral) {
        guard p === peripheral,lifecycle.connected(p.identifier) else { return }
        status="Checking adapter services…"; p.discoverServices([CBUUID(string:"FFF0")])
    }
    func centralManager(_ central: CBCentralManager, didFailToConnect p: CBPeripheral, error: Error?) { guard p === peripheral else { return }; fail("Could not connect. Disconnect other OBD apps and retry.") }
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral p: CBPeripheral, error: Error?) {
        guard p === peripheral else{return}
        let expected=lifecycle.phase == .disconnecting(p.identifier)
        guard lifecycle.disconnected(p.identifier) else{return}
        peripheral=nil
        if !expected{fail("Adapter disconnected. Reconnect when ready.")}
    }
    func peripheral(_ p: CBPeripheral, didDiscoverServices error: Error?) {
        guard p === peripheral else { return }
        guard lifecycle.phase == .services(p.identifier) else{return}
        guard error == nil, let service=p.services?.first(where:{$0.uuid == CBUUID(string:"FFF0")}) else { fail("This adapter does not expose the expected KONNWEI service."); return }
        guard lifecycle.services(p.identifier) else{return}
        p.discoverCharacteristics([CBUUID(string:"FFF1"),CBUUID(string:"FFF2")],for:service)
    }
    func peripheral(_ p: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard p === peripheral else { return }
        guard lifecycle.phase == .characteristics(p.identifier) else{return}
        guard error == nil, let chars=service.characteristics,
              let receive=chars.first(where:{$0.uuid == CBUUID(string:"FFF1") && $0.properties.contains(.notify)}),
              let send=chars.first(where:{$0.uuid == CBUUID(string:"FFF2") && $0.properties.contains(.writeWithoutResponse)}) else { fail("Adapter channel validation failed."); return }
        guard lifecycle.characteristics(p.identifier) else{return}
        rx=receive; tx=send; p.setNotifyValue(true,for:receive)
    }
    func peripheral(_ p: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        guard p === peripheral, characteristic === rx else { return }
        guard lifecycle.phase == .notifications(p.identifier) else{return}
        guard error == nil, characteristic.isNotifying else { fail("Could not enable adapter replies."); return }
        guard lifecycle.notifications(p.identifier) else{return}
        connectionTimeout?.cancel(); ready=true; status="Adapter connected"; onReady?()
    }
    func peripheral(_ p: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard p === peripheral, characteristic === rx else { return }
        guard error == nil, let data=characteristic.value else { fail("Bluetooth reply failed."); return }
        guard response != nil else { if !data.allSatisfy({[9,10,13,32].contains($0)}) { fail("Unexpected adapter traffic. Reconnect to resynchronise.") }; return }
        do { if let text=try buffer.feed(data) { finishCommand(.success(text)) } }
        catch { fail(error.localizedDescription) }
    }
}
