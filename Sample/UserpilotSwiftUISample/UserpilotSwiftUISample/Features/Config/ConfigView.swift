//
//  ConfigView.swift
//  Userpilot SDK
//
//  Created by Userpilot on 13/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Lets sample users save an app token and SDK options for the next launch.
//

import SwiftUI

struct ConfigView: View {
    @State private var config = SampleConfig.load()
    @State private var saved = false

    var body: some View {
        Form {
            Section("App token") {
                TextField("Enter your app token", text: $config.token)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            Section("SDK options") {
                ForEach(ConfigFlag.allCases) { flag in
                    Toggle(isOn: Binding(get: { config[flag] }, set: { config[flag] = $0 })) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(flag.title)
                            Text(flag.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Section {
                Button("Save configuration") {
                    config.save()
                    saved = true
                }
                .disabled(config.token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } footer: {
                Text("Close and reopen the sample after saving. The current SDK instance keeps its launch settings.")
            }
        }
        .navigationTitle("Configuration")
        .alert("Configuration saved", isPresented: $saved) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Close and reopen the sample to apply these settings.")
        }
    }
}
