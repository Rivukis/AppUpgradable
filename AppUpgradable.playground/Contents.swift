import Foundation

public let kUserDefaultsKey_CurrentVersion = "UserDefaultsKey_CurrentVersion"

public enum UpgradeError : Error {
    case Canceled(rawVersion: Int, fatalErrors: [Error], nonFatalErrors: [Error])
    case CompletedWithErrors(errors: [Error])
}

public enum UpgradeResult {
    case greatSuccess
    case errors([UpgradeResult])
    case fatalError(Error)
    case nonFatalError(Error)
}

public protocol AppUpgradable {
    // Required
    associatedtype Version: RawRepresentable // <-- enum Version: Int {} (do NOT assign a value to any case)
    func upgradeBlock(forVersion version: Version) -> () -> UpgradeResult
    
    // Optional (defaults to use UserDefaults.standard)
    func setCurrentVersion(version: Version)
    func getCurrentVersion() -> Version
    
    // Do NOT override
    func upgradeApp()
}

public extension AppUpgradable where Version.RawValue == Int {
    final public func upgradeApp() throws {
        func parseErrors(from upgradResults: [UpgradeResult]) -> (fatal: [Error], nonFatal: [Error]) {
            let results = (fatal: [Error](), nonFatal: [Error]())
            return upgradResults.reduce(results) {
                var results = $0
                if case .fatalError(let error) = $1 {
                    results.fatal.append(error)
                }
                else if case .nonFatalError(let error) = $1 {
                    results.nonFatal.append(error)
                }
                
                return results
            }
        }
        
        func upgrade(fromVersion version: Version) throws {
            var nextRawVersion = version.rawValue + 1
            var nonFatalErrors = [Error]()
            
            while let version = Version(rawValue: nextRawVersion) {
                let result = upgradeBlock(forVersion: version)()
                
                switch result {
                case .greatSuccess:
                    break
                    
                case .fatalError(let error):
                    throw UpgradeError.Canceled(rawVersion: version.rawValue, fatalErrors: [error], nonFatalErrors: nonFatalErrors)
                    
                case .nonFatalError(let error):
                    nonFatalErrors.append(error)
                    
                case .errors(let errors):
                    let parsedErrors = parseErrors(from: errors)
                    nonFatalErrors.append(contentsOf: parsedErrors.nonFatal)
                    
                    if parsedErrors.fatal.count > 0 {
                        throw UpgradeError.Canceled(rawVersion: version.rawValue, fatalErrors: parsedErrors.fatal, nonFatalErrors: nonFatalErrors)
                    }
                }
                
                setCurrentVersion(version: version)
                nextRawVersion += 1
            }
            
            if nonFatalErrors.count > 0 {
                throw UpgradeError.CompletedWithErrors(errors: nonFatalErrors)
            }
        }
        
        try upgrade(fromVersion: getCurrentVersion())
    }
    
    func setCurrentVersion(version: Version) {
        UserDefaults.standard.set(version.rawValue, forKey: kUserDefaultsKey_CurrentVersion)
        UserDefaults.standard.synchronize()
    }
    
    func getCurrentVersion() -> Version {
        return UserDefaults.standard.object(forKey: kUserDefaultsKey_CurrentVersion) as? Version ?? Version(rawValue: 0)!
    }
}

public extension AppUpgradable {
    func upgradeApp() {
        fatalError("Version.RawValue must be of type Int")
    }
}





// MARK: Example - Conforming to AppUpgradable

enum V1_1_UserDefaultsSettings: Error {
    case lostVolumeSetting
}

enum V2_0_DataMigration: Error {
    case failedToRetainUserSettings
    case failedToUpdateiCloud
}

class AppDelegate: AppUpgradable {
    enum Version: Int {
        case v0_0
        case v1_0
        case v1_1
        case v2_0
        case v2_1
    }
    
    func getCurrentVersion() -> Version {
        return Version(rawValue: 0)!
    }
    
    func setCurrentVersion(version: AppDelegate.Version) {
        print("* setting the current version to \(version)\n")
    }
    
    func upgradeBlock(forVersion version: AppDelegate.Version) -> () -> UpgradeResult {
        switch version {
        case .v0_0: return { .greatSuccess } // this is here to satisfy the switch statement without putting in 'default'
        case .v1_0: return upgradeToVersion_1_0
        case .v1_1: return upgradeToVersion_1_1
        case .v2_0: return upgradeToVersion_2_0 // (issue)
        case .v2_1: return upgradeToVersion_2_1
        }
    }
    
    func upgradeToVersion_1_0() -> UpgradeResult {
        print("doing stuff for 1.0 initial launch")
        print("- like setup user defaults")
        print("")
        
        return .greatSuccess
    }
    
    func upgradeToVersion_1_1() -> UpgradeResult {
        print("doing stuff for 1.1 upgrade")
        print("- updating user settings")
        print("-- (non-fatal) couldn't retain the user's volume setting (non-fatal)")
        print("")
        
        return .nonFatalError(V1_1_UserDefaultsSettings.lostVolumeSetting)
    }
    
    func upgradeToVersion_2_0() -> UpgradeResult {
        var errors = [UpgradeResult]()
        print("doing stuff for 2.0 upgrade")
        print("- converting files")
        print("-- (non-fatal) couldn't retain user's last visited location")
        errors.append(.nonFatalError(V2_0_DataMigration.failedToRetainUserSettings))
        print("- pushing files to the cloud")
        print("-- (FATAL) problem syncing with the server")
        errors.append(.fatalError(V2_0_DataMigration.failedToUpdateiCloud))
        print("")
        
//        return .greatSuccess
        return .errors(errors)
    }
    
    func upgradeToVersion_2_1() -> UpgradeResult {
        print("doing stuff for 2.1 upgrade")
        print("- fixing issue caused by 2.0 upgrade")
        print("")
        
        return .greatSuccess
    }
}





// EXAMPLE - Upgrading the App

let myAppDelegate = AppDelegate()
print("current verison \(myAppDelegate.getCurrentVersion())")

do {
    print("")
    try myAppDelegate.upgradeApp()
    print("Upgrade Completed Successfully")
    
} catch UpgradeError.Canceled(let rawVersion, let fatalErrors, let nonFatalErrors) {
    let version = AppDelegate.Version(rawValue: rawVersion)!
    print("Upgrade Failed:")
    print("- on version \(version)")
    print("- FATAL errors \(fatalErrors)")
    print("- non-fatal errors \(nonFatalErrors)")
    
} catch UpgradeError.CompletedWithErrors(let errors) {
    print("Upgrade Completed: with errors \(errors)")
}
