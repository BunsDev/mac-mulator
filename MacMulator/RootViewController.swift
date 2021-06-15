//
//  ViewController.swift
//  QManage
//
//  Created by Vale on 26/01/21.
//

import Cocoa

class RootViewController: NSSplitViewController {

  
    private var listController: VirtualMachinesListViewController?;
    private var vmController: VirtualMachineViewController?;
    
    var virtualMachines: [VirtualMachine] = [];
    var runningVMs: [VirtualMachine : QemuRunner] = [:];
    
    override func viewDidLoad() {
        super.viewDidLoad();
    
        let children = self.children;
        
        listController = children[0] as? VirtualMachinesListViewController;
        if let listController = self.listController {
            listController.setRootController(self);
        }
        
        vmController = children[1] as? VirtualMachineViewController;
        if let vmController = self.vmController {
            vmController.setRootController(self);
        }
        
        let delegate = NSApp.delegate as! AppDelegate;
        delegate.rootControllerDidFinishLoading(self);
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    func setCurrentVirtualMachine(_ currentVm: VirtualMachine?) {
        if let vm = currentVm {
            vmController?.setVirtualMachine(vm);
            listController?.selectElement(virtualMachines.firstIndex(of: vm) ?? -1);
        } else {
            vmController?.setVirtualMachine(nil);
            listController?.selectElement(-1);
        }
    }
    
    func addVirtualMachineFromFile(_ fileName: String) {
        let virtualMachine = VirtualMachine.readFromPlist(fileName, MacMulatorConstants.INFO_PLIST);
        if let vm = virtualMachine {
            self.addVirtualMachine(vm);
        }
    }
    
    func addVirtualMachine(_ virtualMachine: VirtualMachine) {
        if (!virtualMachines.contains(virtualMachine)) {
            virtualMachines.append(virtualMachine);
            listController?.refreshList();
        }
        
        self.setCurrentVirtualMachine(virtualMachine);
        
        let delegate = NSApp.delegate as! AppDelegate;
        delegate.addSavedVM(virtualMachine.path);
    }
    
    func getVirtualMachinesCount() -> Int {
        return virtualMachines.count;
    }
    
    func getVirtualMachineAt(_ index: Int) -> VirtualMachine {
        return virtualMachines[index];
    }
    
    func removeVirtualMachineAt(_ index: Int) -> VirtualMachine {
        if index > 0 {
            self.setCurrentVirtualMachine(virtualMachines[index - 1]);
        } else if virtualMachines.count > 1 {
            self.setCurrentVirtualMachine(virtualMachines[0]);
        } else {
            self.setCurrentVirtualMachine(nil);
        }
        
        let virtualMachine = virtualMachines.remove(at: index);
        
        let delegate = NSApp.delegate as! AppDelegate;
        delegate.removeSavedVM(virtualMachine.path);
        
        return virtualMachine;
    }
    
    func setRunningVM(_ vm: VirtualMachine, _ runner: QemuRunner) {
        runningVMs[vm] = runner;
    }
    
    func unsetRunningVM(_ vm: VirtualMachine) {
        runningVMs.removeValue(forKey: vm);
    }
    
    func getRunnerForRunningVM(_ vm: VirtualMachine) -> QemuRunner? {
        return runningVMs[vm];
    }
    
    func showAlert(_ message: String) {
        Utils.showAlert(window: view.window!, style: NSAlert.Style.warning, message: message);
    }
    
    func refreshViewForVM(_ virtualMachine: VirtualMachine) {
        self.listController?.refreshList();
        if (vmController?.vm == virtualMachine) {
            vmController?.setVirtualMachine(virtualMachine);
        }
    }
    
    func areThereRunningVMs() -> Bool {
        return runningVMs.count > 0;
    }
    
    func killAllRunningVMs() {
        for runner in runningVMs.values {
            runner.kill();
        }
    }
}

