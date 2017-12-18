
// MARK: Example - Conforming to AppUpgradable

enum UserDefaultsError: Error {
    case lostVolumeSetting
}
enum DataMigrationError: Error {
    case failedToRetainUserSettings
    case failedToUpdateiCloud
}

class AppUpgrader: AppUpgradable {
    var currentVersion = Version.v0_0
    
    enum Version: Int {
        case v0_0
        case v1_0
        case v1_1
        case v2_0
        case v2_1
        case v3_0
        case v4_0
    }
    
    func getCurrentVersion() -> Version {
        return currentVersion
    }
    func setCurrentVersion(version: Version) {
        print("\n* setting the current version to \(version)\n")
        currentVersion = version
    }
    
    func upgradeClosure(toVersion version: Version) -> () -> UpgradeResult {
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
    
    func upgradeToVersion_1_0() -> UpgradeResult {
        print("doing stuff for 0.0 to 1.0 initial launch")
        print("- like setup user defaults")
        
        return .success
    }
    
    func upgradeToVersion_1_1() -> UpgradeResult {
        print("doing stuff for 1.0 to 1.1 upgrade")
        print("- updating user settings")
        print("-- (non-fatal) couldn't retain the user's volume setting")
        
        return .nonFatalError(UserDefaultsError.lostVolumeSetting)
    }
    
    func upgradeToVersion_2_0_original() -> UpgradeResult {
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

    func upgradeToVersion_2_0_new() -> UpgradeResult {
        print("doing stuff for 1.1 to 2.1 upgrade (avoiding the mistake in 2.0)")
        print("- pushing files to the cloud")
        print("-- correctly pushing files to the cloud")
        
        return UpgradeResult.success.jump(toVersion: Version.v2_1)
    }

    func upgradeToVersion_2_1() -> UpgradeResult {
        print("doing stuff for 2.0 to 2.1 upgrade")
        print("- fixing issue caused by 2.0 upgrade")
        
        return .success
    }
    
    func upgradeToVersion_3_0_original() -> UpgradeResult {
        print("doing stuff for 2.1 to 3.0 upgrade (original)")
        print("- change to a new file structure")
        
        return .success
    }
    
    func upgradeToVersion_3_0_new() -> UpgradeResult {
        print("doing stuff for 2.1 to 4.0 upgrade (avoid changing the file structure just to change it back)")
        print("- NOT changing to a new file structure")
        
        return UpgradeResult.success.jump(toVersion: Version.v4_0)
    }

    func upgradeToVersion_4_0() -> UpgradeResult {
        print("doing stuff for 3.0 to 4.0 upgrade")
        print("- 3.0 was a mistake, change file structure back to what it was")
        
        return .success
    }
}

// EXAMPLE - Upgrading the App

let myAppUpgrader = AppUpgrader()
myAppUpgrader.setCurrentVersion(version: .v0_0)

do {
    try myAppUpgrader.upgradeApp()
    print("Upgrade Completed Successfully")
    
} catch UpgradeError.Canceled(let rawVersion, let fatalErrors, let nonFatalErrors) {
    let version = AppUpgrader.Version(rawValue: rawVersion)!
    print("\nUpgrade Failed:")
    print("- on version \(version)")
    print("- FATAL errors \(fatalErrors)")
    print("- non-fatal errors \(nonFatalErrors)")
    
} catch UpgradeError.CompletedWithErrors(let errors) {
    print("Upgrade Completed: with errors \(errors)")
}

print("\nFinished Upgrade: new version \(myAppUpgrader.getCurrentVersion())")
