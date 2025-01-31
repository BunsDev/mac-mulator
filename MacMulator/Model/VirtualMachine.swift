//
//  VirtualMachine.swift
//  MacMulator
//
//  Created by Vale on 26/01/21.
//

import Foundation

class VirtualMachine: Codable, Hashable {
    
    var os: String
    var subtype: String
    var architecture: String
    var path: String = ""
    var displayName: String
    var description: String
    var cpus: Int
    var memory: Int32
    var displayResolution: String
    var displayOrigin: String?
    var networkDevice: String?
    var videoDevice: String?
    var drives: [VirtualDrive]
    var qemuPath: String?
    var qemuCommand: String?
    var hvf: Bool?
    var portMappings: [PortMapping]?
    var macAddress: String?
    var type: String?
    var pauseSupported: Bool? = false
    var bootMode: String?
    
    private enum CodingKeys: String, CodingKey {
        case os, subtype, architecture, displayName, description, cpus, memory, displayResolution, displayOrigin, networkDevice, videoDevice, drives, qemuPath, qemuCommand, hvf, portMappings, macAddress, type, bootMode;
    }
    
    init(os: String, subtype: String, architecture: String, path: String, displayName: String, description: String, memory: Int32, cpus: Int, displayResolution: String, displayOrigin: String, networkDevice: String, videoDevice: String, hvf: Bool, macAddress: String?, type: String, bootMode: String) {
        self.os = os
        self.subtype = subtype
        self.architecture = architecture
        self.path = path
        self.displayName = displayName
        self.description = description
        self.memory = memory
        self.cpus = cpus
        self.displayResolution = displayResolution
        self.displayOrigin = displayOrigin
        self.networkDevice = networkDevice
        self.videoDevice = videoDevice
        self.hvf = hvf
        self.drives = []
        self.portMappings = [PortMapping(name: NSLocalizedString("VirtualMachine.sshPortMapping", comment: ""), vmPort: 22, hostPort: Utils.random(digits: 2, suffix: 22))]
        self.macAddress = macAddress
        self.type = type
        self.bootMode = bootMode
    }
    
    func addVirtualDrive(_ drive: VirtualDrive) {
        drives.append(drive);
    }
    
    func removeVirtualDrive(_ path: String) {
        if let index = drives.firstIndex(where: { $0.path == path }) {
            drives.remove(at: index)
        }
    }
    
    func containsVirtualDrive(_ path: String) -> Bool {
        if let index = drives.firstIndex(where: { $0.path == path }) {
            return true
        }
        return false
    }
    
    func addPortMapping(_ portMapping: PortMapping) {
        portMappings?.append(portMapping);
    }
    
    static func readFromPlist(_ plistFilePath: String, _ plistFileName: String) -> VirtualMachine? {
        let fileManager = FileManager.default;
        do {
            let xml = fileManager.contents(atPath: plistFilePath + "/" + plistFileName);
            let vm = try PropertyListDecoder().decode(VirtualMachine.self, from: xml!);
            setupPaths(vm, plistFilePath);
            if vm.portMappings == nil {
                vm.portMappings = [PortMapping(name: NSLocalizedString("VirtualMachine.sshPortMapping", comment: ""), vmPort: 22, hostPort: Utils.random(digits: 2, suffix: 22))]
            }
            return vm;
        } catch {
            print(String(format: NSLocalizedString("VirtualMachine.infoPlistReadError", comment: ""), error.localizedDescription))
            return nil;
        }
    }
    
    static func setupPaths(_ vm: VirtualMachine, _ plistFilePath: String) {
        vm.path = plistFilePath;
        for drive in vm.drives {
            if drive.mediaType != QemuConstants.MEDIATYPE_CDROM {
                if drive.mediaType == QemuConstants.MEDIATYPE_DISK {
                    drive.path = plistFilePath + "/" + drive.name + "." + MacMulatorConstants.DISK_EXTENSION;
                } else if drive.mediaType == QemuConstants.MEDIATYPE_EFI || drive.mediaType == QemuConstants.MEDIATYPE_EFI_SECURE || drive.mediaType == QemuConstants.MEDIATYPE_EFI_VARS || drive.mediaType == QemuConstants.MEDIATYPE_EFI_SECURE_VARS {
                    drive.path = plistFilePath + "/" + drive.name + "." + MacMulatorConstants.EFI_EXTENSION;
                } else if drive.mediaType == QemuConstants.MEDIATYPE_OPENCORE {
                    drive.path = plistFilePath + "/" + drive.name + "." + MacMulatorConstants.IMG_EXTENSION;
                }
            }
        }
    }
    
    func writeToPlist(_ plistFilePath: String) {
        do {
            let data = try PropertyListEncoder().encode(self);
            try data.write(to: URL(fileURLWithPath: plistFilePath));
        } catch {
            print(String(format: NSLocalizedString("VirtualMachine.infoPlistWriteError", comment: ""), error.localizedDescription))
        }
    }
    
    func writeToPlist() {
        do {
            let data = try PropertyListEncoder().encode(self);
            try data.write(to: URL(fileURLWithPath: self.path + "/" + MacMulatorConstants.INFO_PLIST));
        } catch {
            print(String(format: NSLocalizedString("VirtualMachine.infoPlistWriteError", comment: ""), error.localizedDescription))
        }
    }
    
    static func == (lhs: VirtualMachine, rhs: VirtualMachine) -> Bool {
        return lhs.displayName == rhs.displayName;
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(displayName);
    }
}
