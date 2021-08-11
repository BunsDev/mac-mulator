//
//  QemuUtils.swift
//  MacMulator
//
//  Created by Vale on 18/02/21.
//

import Foundation

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
        }
        
        return QemuConstants.HD;
    }
    
    static func createDiskImage(path: String, virtualDrive: VirtualDrive, uponCompletion callback: @escaping (Int32) -> Void) {
        let qemuPath = UserDefaults.standard.string(forKey: MacMulatorConstants.PREFERENCE_KEY_QEMU_PATH)!;
        let shell = Shell();

        let command: String =
            QemuImgCommandBuilder(qemuPath:qemuPath)
            .withCommand(QemuConstants.IMAGE_CMD_CREATE)
            .withFormat(virtualDrive.format)
            .withSize(virtualDrive.size)
            .withName(virtualDrive.name + "." + MacMulatorConstants.DISK_EXTENSION)
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
            .withShortSize(virtualDrive.size)
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
}
