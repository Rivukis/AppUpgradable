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

    public func jump<T: RawRepresentable>(toVersion version: T) -> UpgradeResult where T.RawValue == Int {
        switch self {
        case .errors(let errors):
            return ._jumper(errors, version.rawValue)
        case .fatalError,
             .nonFatalError,
             .success:
            return ._jumper([self], version.rawValue)
        case ._jumper(let errors, _):
            return ._jumper(errors, version.rawValue)
        }
    }
}

public protocol AppUpgradable {
    // Required
    associatedtype Version: RawRepresentable // <-- enum Version: Int {} (do NOT assign a value to any case)
    func upgradeClosure(toVersion version: Version) -> () -> UpgradeResult

    // Optional (defaults to use UserDefaults.standard with key 'UserDefaultsKey_CurrentVersion')
    func setCurrentVersion(version: Version)
    func getCurrentVersion() -> Version

    // Do NOT override
    func upgradeApp()
}

public extension AppUpgradable where Version.RawValue == Int {
    public func upgradeApp() throws {
        func upgrade(fromVersion version: Version) throws {
            var nextRawVersion = version.rawValue + 1
            var nonFatalErrors = [Error]()

            while let version = Version(rawValue: nextRawVersion) {
                var upgradedToVersion = version
                let result = upgradeClosure(toVersion: version)()

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

    private func parseErrors(from upgradResults: [UpgradeResult]) -> (fatal: [Error], nonFatal: [Error]) {
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
}

public extension AppUpgradable {
    func upgradeApp() {
        fatalError("Version.RawValue must be of type Int. It's easiest if you make it an enum of type Int, listing out the versions in order without assigning any values")
    }
}
