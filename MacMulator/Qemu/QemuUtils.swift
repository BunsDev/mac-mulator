//
//  QemuUtils.swift
//  MacMulator
//
//  Created by Vale on 18/02/21.
//

import Cocoa

class QemuUtils {
    
    static func getDriveFormatDescription(_ format: String) -> String {
        if format == QemuConstants.FORMAT_RAW {
            return "(Plain data)";
        } else if format == QemuConstants.FORMAT_QCOW2 {
            return "(Qemu Copy On Write format)";
        }
        
        return "";
    }
    
    static func getDriveTypeDescription(_ driveType: String) -> String {
        if driveType == QemuConstants.MEDIATYPE_CDROM {
            return QemuConstants.CD;
        } else if driveType == QemuConstants.MEDIATYPE_EFI {
            return QemuConstants.EFI;
        } else if driveType == QemuConstants.MEDIATYPE_USB {
            return QemuConstants.USB;
        } else if driveType == QemuConstants.MEDIATYPE_USB_CDROM {
            return QemuConstants.USB_CDROM;
        } else if driveType == QemuConstants.MEDIATYPE_IPSW {
            return QemuConstants.IPSW;
        } else if driveType == QemuConstants.MEDIATYPE_NVRAM {
            return QemuConstants.NVRAM;
        } else if driveType == QemuConstants.MEDIATYPE_NVME {
            return QemuConstants.NVME;
        }else if driveType == QemuConstants.MEDIATYPE_NAND {
            return QemuConstants.NAND;
        }
        
        return QemuConstants.HD;
    }
    
    static func createDiskImage(path: String, virtualDrive: VirtualDrive, uponCompletion callback: @escaping (Int32) -> Void) {
        createDiskImage(path: path, name: virtualDrive.name + "." + MacMulatorConstants.DISK_EXTENSION, format: virtualDrive.format, size: String(virtualDrive.size) + "G", uponCompletion: callback)
    }
    
    static func createDiskImage(path: String, name: String, format: String, size: String, uponCompletion callback: @escaping (Int32) -> Void) {
        let qemuPath = UserDefaults.standard.string(forKey: MacMulatorConstants.PREFERENCE_KEY_QEMU_PATH)!;
        let shell = Shell();

        let command: String =
            QemuImgCommandBuilder(qemuPath:qemuPath)
            .withCommand(QemuConstants.IMAGE_CMD_CREATE)
            .withFormat(format)
            .withSize(size)
            .withName(name)
            .build();
        
        shell.runCommand(command, path, uponCompletion: callback);
    }
    
    static func resizeDiskImage(_ virtualDrive: VirtualDrive, _ path: String, shrink: Bool, uponCompletion callback: @escaping (Int32) -> Void) {
        let qemuPath = UserDefaults.standard.string(forKey: MacMulatorConstants.PREFERENCE_KEY_QEMU_PATH)!;
        let shell = Shell();
        
        let command = QemuImgCommandBuilder(qemuPath: qemuPath)
            .withCommand(QemuConstants.IMAGE_CMD_RESIZE)
            .withName(virtualDrive.path)
            .withShrinkArg(shrink)
            .withShortSize(String(virtualDrive.size) + "G")
            .build();
        
        shell.runCommand(command, path, uponCompletion: callback);
    }
    
    static func convertDiskImage(_ virtualDrive: VirtualDrive, _ path: String, oldFormat: String, uponCompletion callback: @escaping (Int32) -> Void) {
        let qemuPath = UserDefaults.standard.string(forKey: MacMulatorConstants.PREFERENCE_KEY_QEMU_PATH)!;
        let shell = Shell();
        
        let command = QemuImgCommandBuilder(qemuPath: qemuPath)
            .withCommand(QemuConstants.IMAGE_CMD_CONVERT)
            .withFormat(oldFormat)
            .withTargetFormat(virtualDrive.format)
            .withName(virtualDrive.path)
            .withTargetName(virtualDrive.path)
            .build();
        
        shell.runCommand(command, path, uponCompletion: callback);
    }
    
    static func convertVHDXToDiskImage(vhdxPath: String, vmPath: String, virtualDrive: VirtualDrive, uponCompletion callback: @escaping (Int32, Int32) -> Void) {
        let qemuPath = UserDefaults.standard.string(forKey: MacMulatorConstants.PREFERENCE_KEY_QEMU_PATH)!;
        let shell = Shell();
        
        let command = QemuImgCommandBuilder(qemuPath: qemuPath)
            .withCommand(QemuConstants.IMAGE_CMD_CONVERT)
            .withName(vhdxPath)
            .withTargetName(Utils.escape(virtualDrive.path))
            .build();
        
        shell.runCommand(command, vmPath, uponCompletion: {
            terminationCode in
            
            if terminationCode == 0 {
                QemuUtils.getDiskImageInfo(virtualDrive.path, vmPath, uponCompletion: {
                    infoCode, output in
                    if infoCode == 0 {
                        let driveSize = Utils.extractDriveSize(output)
                        if let driveSize = driveSize {
                            callback(infoCode, driveSize)
                        } else {
                            callback(infoCode, -1)
                        }
                    } else {
                        callback(infoCode, -1)
                    }
                })
            } else {
                callback(terminationCode, -1)
            }
            
        })
    }
    
    static func createAuxiliaryDriveFilesOnDisk(_ vm: VirtualMachine) {
        if Utils.getTPMForSubType(vm.os, vm.subtype) {
            try? FileManager.default.createDirectory(at: URL(fileURLWithPath: vm.path + "/tpm"), withIntermediateDirectories: false)
        }
  
        if vm.subtype == QemuConstants.SUB_WINDOWS_11 {
            let driversCdRom = VirtualDrive(
                path: vm.path + "/" + QemuConstants.MEDIATYPE_USB_CDROM + "-windows-drivers-0." + MacMulatorConstants.ISO_EXTENSION,
                name: QemuConstants.MEDIATYPE_USB_CDROM + "-windows-drivers-0",
                format: QemuConstants.FORMAT_RAW,
                mediaType: QemuConstants.MEDIATYPE_USB_CDROM,
                size: 0);
            vm.addVirtualDrive(driversCdRom)
            
            let sourceURL = URL(fileURLWithPath: Bundle.main.path(forResource: "windows-11-drivers.iso.zip", ofType: nil)!)
            let destinationURL = URL(fileURLWithPath: vm.path)
            try? FileManager.default.unzipItem(at: sourceURL, to: destinationURL, skipCRC32: true)
            
            // Rename unzipped image and clean up garbage empty folder
            try? FileManager.default.moveItem(atPath: vm.path + "/windows-11-drivers.iso", toPath: vm.path + "/usb-cdrom-windows-drivers-0.iso")
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: vm.path + "/__MACOSX"))
        }
        
        if QemuUtils.requiresOpenCore(vm) {
            let openCore = VirtualDrive(
                path: vm.path + "/" + QemuConstants.MEDIATYPE_OPENCORE + "-0." + MacMulatorConstants.IMG_EXTENSION,
                name: QemuConstants.MEDIATYPE_OPENCORE + "-0",
                format: QemuConstants.FORMAT_RAW,
                mediaType: QemuConstants.MEDIATYPE_OPENCORE,
                size: 0);
            vm.addVirtualDrive(openCore);
        }
                                
        if vm.os == QemuConstants.OS_IOS {
            try? FileManager.default.copyItem(atPath: Bundle.main.path(forResource: "bootrom_240_4", ofType: nil)!, toPath: vm.path + "/bootrom-0");
            try? FileManager.default.copyItem(atPath: Bundle.main.path(forResource: "nor_n72ap.bin", ofType: nil)!, toPath: vm.path + "/nor-0.bin");
            
            let virtualBootRom = VirtualDrive(
                path: vm.path + "/" + QemuConstants.MEDIATYPE_BOOTROM + "-0",
                name: QemuConstants.MEDIATYPE_BOOTROM + "-0",
                format: QemuConstants.FORMAT_RAW,
                mediaType: QemuConstants.MEDIATYPE_BOOTROM,
                size: 0);
            vm.addVirtualDrive(virtualBootRom)
            
            let virtualNor = VirtualDrive(
                path: vm.path + "/" + QemuConstants.MEDIATYPE_NOR + "-0." + MacMulatorConstants.BIN_EXTENSION,
                name: QemuConstants.MEDIATYPE_NOR + "-0",
                format: QemuConstants.FORMAT_RAW,
                mediaType: QemuConstants.MEDIATYPE_NOR,
                size: 0);
            vm.addVirtualDrive(virtualNor)
        }
    }
    
    static func deleteAuxiliaryDriveFilesOnDisk(_ vm: VirtualMachine) {
        if (vm.architecture == QemuConstants.ARCH_ARM64) {
            try? FileManager.default.removeItem(atPath: vm.path + "/efi-0.fd")
            let efiDrive = Utils.findEfiDrive(vm.drives)
            if let efiDrive = efiDrive {
                if let index = vm.drives.firstIndex(of: efiDrive) {
                    vm.drives.remove(at: index)
                }
            }
            
            try? FileManager.default.removeItem(atPath: vm.path + "/nvram-0")
            let nvramDrive = Utils.findNvramDrive(vm.drives)
            if let nvramDrive = nvramDrive {
                if let index = vm.drives.firstIndex(of: nvramDrive) {
                    vm.drives.remove(at: index)
                }
            }
        }
        
        if (vm.architecture == QemuConstants.ARCH_X64 && vm.os == QemuConstants.OS_MAC) {
            try? FileManager.default.removeItem(atPath: vm.path + "/efi-0.fd")
            try? FileManager.default.removeItem(atPath: vm.path + "/opencore-0")
        }
        
        if (vm.subtype == QemuConstants.SUB_WINDOWS_11) {
            try? FileManager.default.removeItem(atPath: vm.path + "/efi-secure-0.fd")
            try? FileManager.default.removeItem(atPath: vm.path + "/opencore-0")
        }
        
        if (vm.os == QemuConstants.OS_IOS) {
            try? FileManager.default.removeItem(atPath: vm.path + "/bootrom-0")
            try? FileManager.default.removeItem(atPath: vm.path + "/nor-0.bin")
        }
    }
    
    static func updateDiskImage(oldVirtualDrive: VirtualDrive, newVirtualDrive: VirtualDrive, path: String, uponCompletion callback: @escaping (Int32) -> Void) {
        if newVirtualDrive.size != oldVirtualDrive.size {
            resizeDiskImage(newVirtualDrive, path, shrink: (newVirtualDrive.size < oldVirtualDrive.size), uponCompletion: callback);
        }
        if newVirtualDrive.format != oldVirtualDrive.format {
            convertDiskImage(newVirtualDrive, path, oldFormat: oldVirtualDrive.format, uponCompletion: callback);
        }
    }
    
    static func getDiskImageInfo(_ virtualDrive: VirtualDrive, _ path: String, uponCompletion callback: @escaping (Int32, String) -> Void) -> Void {
        getDiskImageInfo(virtualDrive.path, path, uponCompletion: callback);
    }
    
    static func getDiskImageInfo(_ drivePath: String, _ path: String, uponCompletion callback: @escaping (Int32, String) -> Void) -> Void {
        let qemuPath = UserDefaults.standard.string(forKey: MacMulatorConstants.PREFERENCE_KEY_QEMU_PATH)!;
        let shell = Shell();
        
        let command = QemuImgCommandBuilder(qemuPath: qemuPath)
            .withCommand(QemuConstants.IMAGE_CMD_INFO)
            .withName(drivePath)
            .build();
        
        shell.runCommand(command, path, uponCompletion: { terminationCcode in
            callback(terminationCcode, shell.readFromStandardOutput());
        });
    }

    static func isBinaryAvailable(_ binary: String) -> Bool {
        let qemuPath = UserDefaults.standard.string(forKey: MacMulatorConstants.PREFERENCE_KEY_QEMU_PATH)!;
        let fileManager = FileManager.default;
        
        return fileManager.fileExists(atPath: qemuPath + "/" + binary);
    }
    
    static func getQemuVersion(qemuPath: String, uponCompletion callback: @escaping (String?) -> Void) {
        if !isBinaryAvailable(QemuConstants.QEMU_IMG) {
            callback(nil);
        } else {
            let shell = Shell();
            let command = QemuImgCommandBuilder(qemuPath: qemuPath)
                .withCommand(QemuConstants.IMAGE_CMD_VERSION)
                .build();
            shell.runCommand(command, NSHomeDirectory(), uponCompletion: { terminationCode in
                if terminationCode == 0 {
                    let result = shell.readFromStandardOutput();
                    if result.count > 22 {
                        let version = result[result.index(result.startIndex, offsetBy: 17)..<result.index(result.startIndex, offsetBy: 22)];
                        callback(String(version));
                    }
                } else {
                    callback(nil);
                }
            });
        }
    }
    
    static func populateOpenCoreConfig(virtualMachine: VirtualMachine, uponCompletion callback: @escaping (Int32) -> Void) {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: virtualMachine.path + "/opencore-0.img") {
            try? fileManager.removeItem(atPath: virtualMachine.path + "/opencore-0.img")
        }
        let sourceURL = URL(fileURLWithPath: Bundle.main.path(forResource: QemuConstants.OPENCORE + ".zip", ofType: nil)!)
        let destinationURL = URL(fileURLWithPath: virtualMachine.path)
        try? fileManager.unzipItem(at: sourceURL, to: destinationURL, skipCRC32: true)
        
        // Rename unzipped image and clean up garbage empty folder
        try? fileManager.moveItem(atPath: virtualMachine.path + "/" + QemuConstants.OPENCORE + ".img", toPath: virtualMachine.path + "/opencore-0.img")
        try? fileManager.removeItem(at: URL(fileURLWithPath: virtualMachine.path + "/__MACOSX"))
        let shell = Shell();
        shell.runCommand("hdiutil attach -noverify " + Utils.escape(virtualMachine.path) + "/opencore-0.img", virtualMachine.path) { terminationCode in
            
            let shell2 = Shell();
            shell2.runCommand("system_profiler SPHardwareDataType -json", virtualMachine.path, uponCompletion: { terminationCode in
                let json = shell2.stdout;
                print(json)
                let jsonData = json.data(using: .utf8)!
                
                var systemProfilerData : SystemProfilerData? = nil;
                do {
                    systemProfilerData = try JSONDecoder().decode(SystemProfilerData.self, from: jsonData);
                } catch {
                    print("ERROR while reading System Profiler data: " + error.localizedDescription);
                }
                
                let machineDetails = systemProfilerData?.SPHardwareDataType[0];
                    
                let shell3 = Shell();
                shell3.runCommand("cp /Volumes/OPENCORE/EFI/OC/config.plist /Volumes/OPENCORE/EFI/OC/config.plist.template", virtualMachine.path, uponCompletion: { terminationCode in
                    do {
                        var plistContent = try String(contentsOfFile: "/Volumes/OPENCORE/EFI/OC/config.plist.template");
                            
                        print("Replacing screen resolution in OpenCore config...")
                        plistContent = plistContent.replacingOccurrences(of: "{screenResolution}", with: Utils.getResolutionOnly(virtualMachine.displayResolution))
                        
                        print("Replacing product name in OpenCore config...")
                        plistContent = plistContent.replacingOccurrences(of: "{macProductName}", with: machineDetails?.machine_model ?? "MacPro7,1")
                        
                        print("Replacing serial number in OpenCore config...")
                        plistContent = plistContent.replacingOccurrences(of: "{serialNumber}", with: machineDetails?.serial_number ?? "ABCDEFG")
                        
                        print("Replacing hardware UUID in OpenCore config...")
                        plistContent = plistContent.replacingOccurrences(of: "{hardwareUUID}", with: machineDetails?.platform_UUID ?? "000-000")
                            
                        print("Writing to plist...")
                        try plistContent.write(toFile: "/Volumes/OPENCORE/EFI/OC/config.plist", atomically: false, encoding: .utf8);
                            
                        let shell4 = Shell();
                        shell4.runCommand("hdiutil detach /Volumes/OPENCORE -force", virtualMachine.path, uponCompletion: { terminationCode in
                            callback(terminationCode)
                        });
                    } catch {
                        print("ERROR while reading/writing OpenCore config.plist: " + error.localizedDescription);
                    }
                });
            });
        }
    }
    
    static func removeOpenCoreConfig(virtualMachine: VirtualMachine, uponCompletion callback: @escaping (Int32) -> Void) {
        try? FileManager.default.removeItem(at: URL(fileURLWithPath: virtualMachine.path + "/opencore-0.img"))
    }
    
    static func populateUEFIConfig(virtualMachine: VirtualMachine) {
        if (!virtualMachine.containsVirtualDrive(virtualMachine.path + "/efi-0.fd")) {
            let virtualEfi = VirtualDrive(
                path: virtualMachine.path + "/" + QemuConstants.MEDIATYPE_EFI + "-0." + MacMulatorConstants.EFI_EXTENSION,
                name: QemuConstants.MEDIATYPE_EFI + "-0",
                format: QemuConstants.FORMAT_RAW,
                mediaType: QemuConstants.MEDIATYPE_EFI,
                size: 0);
            virtualMachine.addVirtualDrive(virtualEfi)
            virtualMachine.writeToPlist()
        }
        if !FileManager.default.fileExists(atPath: virtualMachine.path + "/efi-0.fd") {
            if virtualMachine.architecture == QemuConstants.ARCH_X64 {
                try? FileManager.default.copyItem(atPath: Bundle.main.path(forResource: "EFI_x64.fd", ofType: nil)!, toPath: virtualMachine.path + "/efi-0.fd")
            } else if virtualMachine.architecture == QemuConstants.ARCH_ARM64 {
                try? FileManager.default.copyItem(atPath: Bundle.main.path(forResource: "EFI_ARM.fd", ofType: nil)!, toPath: virtualMachine.path + "/efi-0.fd")
            }
        }
        if (virtualMachine.architecture == QemuConstants.ARCH_ARM64) {
            if (!virtualMachine.containsVirtualDrive(virtualMachine.path + "/efi-vars-0.fd")) {
                let virtualEfi = VirtualDrive(
                    path: virtualMachine.path + "/" + QemuConstants.MEDIATYPE_EFI_VARS + "-0." + MacMulatorConstants.EFI_EXTENSION,
                    name: QemuConstants.MEDIATYPE_EFI_VARS + "-0",
                    format: QemuConstants.FORMAT_RAW,
                    mediaType: QemuConstants.MEDIATYPE_EFI_VARS,
                    size: 0);
                virtualMachine.addVirtualDrive(virtualEfi)
                virtualMachine.writeToPlist()
            }
            if !FileManager.default.fileExists(atPath: virtualMachine.path + "/efi-vars-0.fd") {
                try? FileManager.default.copyItem(atPath: Bundle.main.path(forResource: "EFI_VARS_ARM.fd", ofType: nil)!, toPath: virtualMachine.path + "/efi-vars-0.fd")
            }
        }
    }
    
    static func removeUEFIConfig(virtualMachine: VirtualMachine) {
        try? FileManager.default.removeItem(at: URL(fileURLWithPath: virtualMachine.path + "/efi-0.fd"))
        try? FileManager.default.removeItem(at: URL(fileURLWithPath: virtualMachine.path + "/efi-vars-0.fd"))
        virtualMachine.removeVirtualDrive(virtualMachine.path + "/efi-0.fd")
        virtualMachine.removeVirtualDrive(virtualMachine.path + "/efi-vars-0.fd")
        virtualMachine.writeToPlist()
    }
    
    static func populateUEFISecureConfig(virtualMachine: VirtualMachine) {
        if (!virtualMachine.containsVirtualDrive(virtualMachine.path + "/efi-secure-0.fd")) {
            let virtualEfi = VirtualDrive(
                path: virtualMachine.path + "/" + QemuConstants.MEDIATYPE_EFI_SECURE + "-0." + MacMulatorConstants.EFI_EXTENSION,
                name: QemuConstants.MEDIATYPE_EFI_SECURE + "-0",
                format: QemuConstants.FORMAT_RAW,
                mediaType: QemuConstants.MEDIATYPE_EFI_SECURE,
                size: 0);
            virtualMachine.addVirtualDrive(virtualEfi)
            virtualMachine.writeToPlist()
        }
        if !FileManager.default.fileExists(atPath: virtualMachine.path + "/efi-secure-0.fd") {
            if virtualMachine.architecture == QemuConstants.ARCH_X64 {
                try? FileManager.default.copyItem(atPath: Bundle.main.path(forResource: "SECURE_EFI_x64.fd", ofType: nil)!, toPath: virtualMachine.path + "/efi-secure-0.fd")
            } else if virtualMachine.architecture == QemuConstants.ARCH_ARM64 {
                try? FileManager.default.copyItem(atPath: Bundle.main.path(forResource: "SECURE_EFI_ARM.fd", ofType: nil)!, toPath: virtualMachine.path + "/efi-secure-0.fd")
            }
        }
        if (virtualMachine.architecture == QemuConstants.ARCH_ARM64) {
            if (!virtualMachine.containsVirtualDrive(virtualMachine.path + "/efi-secure-vars-0.fd")) {
                let virtualEfi = VirtualDrive(
                    path: virtualMachine.path + "/" + QemuConstants.MEDIATYPE_EFI_SECURE_VARS + "-0." + MacMulatorConstants.EFI_EXTENSION,
                    name: QemuConstants.MEDIATYPE_EFI_SECURE_VARS + "-0",
                    format: QemuConstants.FORMAT_RAW,
                    mediaType: QemuConstants.MEDIATYPE_EFI_SECURE_VARS,
                    size: 0);
                virtualMachine.addVirtualDrive(virtualEfi)
                virtualMachine.writeToPlist()
            }
            if !FileManager.default.fileExists(atPath: virtualMachine.path + "/efi-secure-vars-0.fd") {
                try? FileManager.default.copyItem(atPath: Bundle.main.path(forResource: "SECURE_EFI_VARS_ARM.fd", ofType: nil)!, toPath: virtualMachine.path + "/efi-secure-vars-0.fd")
            }
        }
    }
    
    static func removeUEFISecureConfig(virtualMachine: VirtualMachine) {
        try? FileManager.default.removeItem(at: URL(fileURLWithPath: virtualMachine.path + "/efi-secure-0.fd"))
        try? FileManager.default.removeItem(at: URL(fileURLWithPath: virtualMachine.path + "/efi-secure-vars-0.fd"))
        virtualMachine.removeVirtualDrive(virtualMachine.path + "/efi-secure-0.fd")
        virtualMachine.removeVirtualDrive(virtualMachine.path + "/efi-secure-vars-0.fd")
        virtualMachine.writeToPlist()
    }
    
    static func requiresOpenCore(_ vm: VirtualMachine) -> Bool {
        return (vm.os == QemuConstants.OS_MAC && vm.architecture == QemuConstants.ARCH_X64) // || (vm.subtype == QemuConstants.SUB_WINDOWS_11 && vm.architecture == QemuConstants.ARCH_X64)
    }
}
