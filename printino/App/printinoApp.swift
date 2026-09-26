//
//  printinoApp.swift
//  printino
//
//

import SwiftUI

@main
struct FicheroApp: App {
    @State private var viewModel: MenuBarViewModel

    init() {
        let manager = PrinterManager()
        _viewModel = State(initialValue: MenuBarViewModel(printerManager: manager))
    }

    var body: some Scene {
        MenuBarExtra("Printino", systemImage: "printer.dotmatrix.fill") {
            ContentView(viewModel: viewModel)
                .frame(width: 360, height: 680)
        }
        .menuBarExtraStyle(.window)
    }
}
