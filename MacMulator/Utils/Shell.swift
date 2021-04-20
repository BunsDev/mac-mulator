//
//  Shell.swift
//  MacMulator
//
//  Created by Vale on 03/02/21.
//

import Foundation

class Shell {
    let task = Process();
    let pipe_out = Pipe();
    let pipe_err = Pipe();
    
    func runCommand(_ command: String, uponCompletion callback: @escaping () -> Void) -> Void {
        
        DispatchQueue.global().async {
            print("Running " + command + " in " + self.task.currentDirectoryPath);
            do {
                try ObjC.catchException({
                    if (!self.task.isRunning) {
                        self.task.standardOutput = self.pipe_out;
                        self.task.standardError = self.pipe_err;
                        
                        self.task.arguments = ["-c", command];
                        self.task.launchPath = "/bin/zsh";
                        
                        self.task.terminationHandler = {process in callback() };
                        self.task.launch();
                    }
                })
            } catch {
                print(error.localizedDescription);
            }
        }
    }
    
    func setWorkingDir(_ path: String) {
        task.currentDirectoryPath = path;
    }
    
    func isRunning() -> Bool {
        return task.isRunning;
    }
    
    func waitForCommand() {
        task.waitUntilExit();
    }
    
    func getStandardOutput() -> String {
        let data = pipe_out.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)!
        return output;
    }
    
    func getStandardError() -> String {
        let data = pipe_err.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)!
        return output;
    }
}
