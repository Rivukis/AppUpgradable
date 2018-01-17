enum UserDefaultsError: Error {
    case lostVolumeSetting
}

enum DataMigrationError: Error {
    case failedToRetainUserSettings
    case failedToUpdateiCloud
}

enum MyAppVersion: Int, AppVersion {
    case v0_0
    case v1_0
    case v1_1
    case v2_0
    case v2_1
    case v3_0
    case v4_0
}

class MyAppUpgrader: AppUpgradable {
    private let upgrader: AppUpgrader<MyAppVersion>
    
    init() {
        self.upgrader = AppUpgrader<MyAppVersion>(name: "com.company.myappversion")
    }
    
    func upgradeApp() throws {
        try upgrader.upgrade(toVersion: upgrader.getCurrentVersion(), upgradeClosure: upgradeToVersion)
    }
    
    func getCurrentVersion() -> AppVersion {
        return upgrader.getCurrentVersion()
    }
    
    // MARK: - Upgrade Methods
    
    private func upgradeToVersion(_ version: MyAppVersion) -> () -> UpgradeResult {
        switch version {
        case .v0_0: return { .success } // this is here to satisfy the switch statement without putting in 'default'
        case .v1_0: return upgradeToVersion_1_0
        case .v1_1: return upgradeToVersion_1_1
        case .v2_0: return upgradeToVersion_2_0_new // (issue)
        case .v2_1: return upgradeToVersion_2_1
        case .v3_0: return upgradeToVersion_3_0_new // (issue)
        case .v4_0: return upgradeToVersion_4_0
        }
    }

    private func upgradeToVersion_1_0() -> UpgradeResult {
        print("doing stuff for 0.0 to 1.0 initial launch")
        print("- like setup user defaults")
        
        return .success
    }
    
    private func upgradeToVersion_1_1() -> UpgradeResult {
        print("doing stuff for 1.0 to 1.1 upgrade")
        print("- updating user settings")
        print("-- (non-fatal) couldn't retain the user's volume setting")
        
        return .nonFatalError(UserDefaultsError.lostVolumeSetting)
    }
    
    private func upgradeToVersion_2_0_original() -> UpgradeResult {
        var errors = [UpgradeResult]()
        print("doing stuff for 1.1 to 2.0 upgrade (original)")
        print("- converting files")
        print("-- (non-fatal) couldn't retain user's last visited location")
        errors.append(.nonFatalError(DataMigrationError.failedToRetainUserSettings))
        print("- pushing files to the cloud")
        print("-- (FATAL) problem syncing with the server")
        errors.append(.fatalError(DataMigrationError.failedToUpdateiCloud))
        
        return .errors(errors)
    }
    
    private func upgradeToVersion_2_0_new() -> UpgradeResult {
        print("doing stuff for 1.1 to 2.1 upgrade (avoiding the mistake in 2.0)")
        print("- pushing files to the cloud")
        print("-- correctly pushing files to the cloud")
        
        return UpgradeResult.success.jump(toVersion: MyAppVersion.v2_1)
    }
    
    private func upgradeToVersion_2_1() -> UpgradeResult {
        print("doing stuff for 2.0 to 2.1 upgrade")
        print("- fixing issue caused by 2.0 upgrade")
        
        return .success
    }
    
    private func upgradeToVersion_3_0_original() -> UpgradeResult {
        print("doing stuff for 2.1 to 3.0 upgrade (original)")
        print("- change to a new file structure")
        
        return .success
    }
    
    private func upgradeToVersion_3_0_new() -> UpgradeResult {
        print("doing stuff for 2.1 to 4.0 upgrade (avoid changing the file structure just to change it back)")
        print("- NOT changing to a new file structure")
        
        return UpgradeResult.success.jump(toVersion: MyAppVersion.v4_0)
    }
    
    private func upgradeToVersion_4_0() -> UpgradeResult {
        print("doing stuff for 3.0 to 4.0 upgrade")
        print("- 3.0 was a mistake, change file structure back to what it was")
        
        return .success
    }
}

let myAppUpgrader = MyAppUpgrader()

do {
    try myAppUpgrader.upgradeApp()
    print("Upgrade Completed Successfully")
    
} catch UpgradeError.Canceled(let rawVersion, let fatalErrors, let nonFatalErrors) {
    let version = rawVersion
    print("\nUpgrade Failed:")
    print("- on version \(version)")
    print("- FATAL errors \(fatalErrors)")
    print("- non-fatal errors \(nonFatalErrors)")
    
} catch UpgradeError.CompletedWithErrors(let errors) {
    print("Upgrade Completed: with errors \(errors)")
} catch {
    print("Unknown error")
}

print("\nFinished Upgrade: new version \(myAppUpgrader.getCurrentVersion())")
