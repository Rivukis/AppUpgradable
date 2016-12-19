import Foundation

public enum UpgradeError : Error {
    case Canceled(rawVersion: Int, fatalErrors: [Error], nonFatalErrors: [Error])
    case CompletedWithErrors(errors: [Error])
}

public enum UpgradeResult {
    case success
    case errors([UpgradeResult])
    case fatalError(Error)
    case nonFatalError(Error)
    case _jumper([UpgradeResult], Int)
    
    func jump(toRawVersion rawVersion: Int) -> UpgradeResult {
        switch self {
        case .errors(let errors):
            return ._jumper(errors, rawVersion)
        case .fatalError,
             .nonFatalError,
             .success:
            return ._jumper([self], rawVersion)
        case ._jumper(let errors, _):
            return ._jumper(errors, rawVersion)
        }
    }
}

public protocol AppUpgradable {
    // Required
    associatedtype Version: RawRepresentable // <-- enum Version: Int {} (do NOT assign a value to any case)
    func upgradeBlock(forVersion version: Version) -> () -> UpgradeResult
    
    // Optional (defaults to use UserDefaults.standard with key 'UserDefaultsKey_CurrentVersion')
    var userDefaultsKey_CurrentVersion : String { get }
    func setCurrentVersion(version: Version)
    func getCurrentVersion() -> Version
    
    // Do NOT override
    func upgradeApp()
}

public extension AppUpgradable where Version.RawValue == Int {
    final public func upgradeApp() throws {
        func parseErrors(from upgradResults: [UpgradeResult]) -> (fatal: [Error], nonFatal: [Error]) {
            return upgradResults.reduce((fatal: [Error](), nonFatal: [Error]())) {
                var results = $0
                switch $1 {
                case .fatalError(let error):
                    results.fatal.append(error)
                case .nonFatalError(let error):
                    results.nonFatal.append(error)
                default: break
                }
                
                return results
            }
        }
        
        func upgrade(fromVersion version: Version) throws {
            var nextRawVersion = version.rawValue + 1
            var nonFatalErrors = [Error]()
            
            while let version = Version(rawValue: nextRawVersion) {
                var upgradedToVersion = version
                let result = upgradeBlock(forVersion: version)()
                
                switch result {
                case .success:
                    break
                    
                case .fatalError(let error):
                    throw UpgradeError.Canceled(rawVersion: version.rawValue, fatalErrors: [error], nonFatalErrors: nonFatalErrors)
                    
                case .nonFatalError(let error):
                    nonFatalErrors.append(error)
                    
                case ._jumper(let errors, let jumpVersion):
                    upgradedToVersion = Version(rawValue: jumpVersion)!
                    let parsedErrors = parseErrors(from: errors)
                    nonFatalErrors.append(contentsOf: parsedErrors.nonFatal)
                    
                    if parsedErrors.fatal.count > 0 {
                        throw UpgradeError.Canceled(rawVersion: version.rawValue, fatalErrors: parsedErrors.fatal, nonFatalErrors: nonFatalErrors)
                    }
                    
                case .errors(let errors):
                    let parsedErrors = parseErrors(from: errors)
                    nonFatalErrors.append(contentsOf: parsedErrors.nonFatal)
                    
                    if parsedErrors.fatal.count > 0 {
                        throw UpgradeError.Canceled(rawVersion: version.rawValue, fatalErrors: parsedErrors.fatal, nonFatalErrors: nonFatalErrors)
                    }
                }
                
                setCurrentVersion(version: upgradedToVersion)
                nextRawVersion = upgradedToVersion.rawValue + 1
            }
            
            if nonFatalErrors.count > 0 {
                throw UpgradeError.CompletedWithErrors(errors: nonFatalErrors)
            }
        }
        
        try upgrade(fromVersion: getCurrentVersion())
    }
    
    var userDefaultsKey_CurrentVersion: String {
        return "UserDefaultsKey_CurrentVersion"
    }
    
    func setCurrentVersion(version: Version) {
        UserDefaults.standard.set(version.rawValue, forKey: userDefaultsKey_CurrentVersion)
        UserDefaults.standard.synchronize()
    }
    
    func getCurrentVersion() -> Version {
        return UserDefaults.standard.object(forKey: userDefaultsKey_CurrentVersion) as? Version ?? Version(rawValue: 0)!
    }
}

public extension AppUpgradable {
    func upgradeApp() {
        fatalError("Version.RawValue must be of type Int. It's easiest if you make it an enum of type Int, listing out the versions in order without assigning any values")
    }
}





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
        print("* setting the current version to \(version)\n")
        currentVersion = version
    }
    
    func upgradeBlock(forVersion version: Version) -> () -> UpgradeResult {
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
        
        return UpgradeResult.success.jump(toRawVersion: Version.v2_1.rawValue)
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
        
        return UpgradeResult.success.jump(toRawVersion: Version.v4_0.rawValue)
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
