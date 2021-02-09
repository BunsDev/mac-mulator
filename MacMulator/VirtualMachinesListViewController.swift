//
//  VirtualMachinesListViewController.swift
//  MacMulator
//
//  Created by Vale on 28/01/21.
//

import Cocoa

class VirtualMachinesListViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource {
     
    @IBOutlet weak var table: NSTableView!
    @IBOutlet weak var rightClickmenu: NSMenu!
    
    var virtualMachines: [VirtualMachine] = [];
    var rootController: RootViewController?;
    
    func setRootController(_ rootController:RootViewController) {
        self.rootController = rootController;
    }
    
    func addVirtualMachine(_ virtualMachine: VirtualMachine) {
        virtualMachines.append(virtualMachine);
        self.table.reloadData();
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return virtualMachines.count;
    }
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 55.0;
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = tableView.makeView(withIdentifier: tableColumn!.identifier, owner: self) as! VirtualMachineTableCellView;
        cell.setVirtualMachine(virtualMachine: virtualMachines[row]);
        return cell;
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        let tableView = notification.object as! NSTableView;
        let selectedvm = virtualMachines[tableView.selectedRow];
        rootController!.setCurrentVirtualMachine(selectedvm);
    }
    
    override func viewDidLoad() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Edit", action: #selector(tableViewEditItemClicked(_:)), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Delete", action: #selector(tableViewDeleteItemClicked(_:)), keyEquivalent: ""))
        table.menu = menu
    }
    
    @objc func tableViewEditItemClicked(_ sender: AnyObject) {
        guard table.clickedRow >= 0 else { return }
        let item = virtualMachines[table.clickedRow];
        print("Edit " + item.displayName);
    }
    
    @objc func tableViewDeleteItemClicked(_ sender: AnyObject) {
        guard table.clickedRow >= 0 else { return }
        let row = table.clickedRow
        let removed = virtualMachines.remove(at: row);
        table.reloadData();
        
        rootController?.deleteVirtualMachine(removed);
    }
}
