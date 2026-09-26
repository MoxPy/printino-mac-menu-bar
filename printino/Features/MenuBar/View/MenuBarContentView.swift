//
//  MenuBarContentView.swift
//  printino
//
//

import AppKit
import SwiftUI

struct ContentView: View {
    @Bindable var viewModel: MenuBarViewModel
    @State private var dragOrigin: CGSize = .zero

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Circle()
                        .fill(viewModel.isConnected ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(viewModel.statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let battery = viewModel.batteryLevel {
                        Text("\(battery)%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if !viewModel.isConnected {
                        Button("Cerca") {
                            viewModel.scan()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    } else {
                        Button("Scollega") {
                            viewModel.disconnect()
                        }
                        .controlSize(.small)
                    }
                }

                Text("Modello: \(viewModel.printerModel)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Divider()

                GroupBox("Testo e emoticon") {
                    VStack(alignment: .leading, spacing: 10) {
                        TextField("Scrivi il testo...", text: $viewModel.labelText, axis: .vertical)
                            .lineLimit(2...5)
                            .textFieldStyle(.roundedBorder)

                        HStack(spacing: 6) {
                            ForEach(viewModel.quickEmojis, id: \.self) { emoji in
                                Button(emoji) {
                                    viewModel.insertEmoji(emoji)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Dimensione font: \(Int(viewModel.fontSize)) pt")
                                .font(.caption)
                            Slider(value: $viewModel.fontSize, in: 16...48, step: 2)
                        }
                    }
                    .padding(.vertical, 4)
                }

                GroupBox("Immagine") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Button("Scegli immagine") {
                                viewModel.pickImage()
                            }
                            .buttonStyle(.bordered)

                            if viewModel.selectedImage != nil {
                                Button("Rimuovi") {
                                    viewModel.removeImage()
                                }
                                .buttonStyle(.bordered)
                            }
                        }

                        if let name = viewModel.selectedImageName {
                            Text(name)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                GroupBox("QR code") {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Contenuto QR", text: $viewModel.qrCodeText)
                            .textFieldStyle(.roundedBorder)
                    }
                    .padding(.vertical, 4)
                }

                GroupBox("Codice a barre") {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Contenuto codice a barre", text: $viewModel.barcodeText)
                            .textFieldStyle(.roundedBorder)
                    }
                    .padding(.vertical, 4)
                }

                GroupBox("Impostazioni stampa") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(viewModel.labelSizeDescription)
                                    .font(.caption)
                                Text("Trascina il contenuto nell'anteprima per posizionarlo")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button("Centra") {
                                viewModel.resetContentOffset()
                                dragOrigin = .zero
                            }
                            .buttonStyle(.bordered)
                        }

                        Picker("Densità", selection: $viewModel.density) {
                            Text("Leggera").tag(PrintDensity.light)
                            Text("Media").tag(PrintDensity.medium)
                            Text("Forte").tag(PrintDensity.thick)
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.vertical, 4)
                }

                GroupBox("Anteprima di stampa") {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(nsColor: .windowBackgroundColor))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(.quaternary, lineWidth: 1)
                            )

                        if let previewImage = viewModel.previewImage {
                            Image(nsImage: previewImage)
                                .resizable()
                                .interpolation(.none)
                                .scaledToFit()
                                .padding(12)
                        } else {
                            VStack(spacing: 8) {
                                Image(systemName: "doc.text.magnifyingglass")
                                    .font(.title2)
                                Text("Nessun contenuto da anteprimare")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                        }

                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        viewModel.contentOffset = CGSize(
                                            width: dragOrigin.width + value.translation.width,
                                            height: dragOrigin.height + value.translation.height
                                        )
                                    }
                                    .onEnded { _ in
                                        dragOrigin = viewModel.contentOffset
                                    }
                            )
                    }
                    .frame(minHeight: 220)
                    .padding(.vertical, 4)
                }

                Button(action: {
                    viewModel.printCurrentLabel()
                }) {
                    Label("Stampa Etichetta", systemImage: "printer")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!viewModel.canPrint)

                Button("Esci") {
                    NSApplication.shared.terminate(nil)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding()
        }
        .frame(width: 360, height: 680)
    }
}
