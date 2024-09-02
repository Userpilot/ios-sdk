//
//  SettingsVerifing.swift
//  UserPilot SDK
//
//  Created by Motasem Hamed on 18/08/2024.
//  Copyright © 2021 UserPilot. All rights reserved.
//
// [Brief Description]
// SettingsVerifing to check customer state and getting customer base URL
//

import Foundation

protocol SettingsVerifing: AnyObject {
    func verifySettings(completion: @escaping () -> Void)
}

class SettingsVerifier {

    // MARK: - Properties
    let config: UserPilot.Config
    let networking: Networking
    let dataStoring: DataStoring

    // MARK: - init
    init(container: DIContainer) {
        self.config = container.resolve(UserPilot.Config.self)
        self.networking = container.resolve(Networking.self)
        self.dataStoring = container.resolve(DataStoring.self)
    }

}

// MARK: - SettingsVerifing
extension SettingsVerifier: SettingsVerifing {

    func verifySettings(completion: @escaping () -> Void) {
        networking.get(from: SettingsEndpoint.settings) { [weak self] (result: Result<SdkSettings, Error>) in
            switch result {
            case .success(let sdkSettings):
                self?.config.logger.info("Customer API URL: %{private}@ optained", sdkSettings.services.customerApi)
                self?.dataStoring.socketURL = sdkSettings.services.customerApi
                completion()
            case .failure(let error):
                self?.config.logger.info("Settings API error: %{public}@", error.localizedDescription)
            }
        }
    }

}
