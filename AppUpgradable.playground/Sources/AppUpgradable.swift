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

public protocol AppVersion {
    var name: String { get }
    func upgradeClosure() -> () -> UpgradeResult
}

public class AppUpgrader<T: AppVersion & RawRepresentable> where T.RawValue == Int {
    
    private let version: T
    
    public init(version: T) {
        self.version = version
    }
    
    // MARK: - Public Methods
    
    public func upgradeApp() throws {
        try upgrade(fromVersion: version)
    }
    
    public func getCurrentVersion() -> T {
        let savedVersion = UserDefaults.standard.object(forKey: version.name) as? Int ?? 0
        return makeVersion(savedVersion)!
    }
    
    // MARK: - Private Methods
    
    private func makeVersion(_ number: Int) -> T? {
        return T.init(rawValue: number)
    }
    
    private func nextVersion(_ version: T) -> T? {
        return makeVersion(version.rawValue + 1)
    }
    
    private func upgrade(fromVersion version: T) throws {
        var nextRawVersion = version
        var nonFatalErrors = [Error]()
        
        while let version = nextVersion(nextRawVersion)/* Version(rawValue: nextRawVersion)*/ {
            var upgradedToVersion = version
            let result = version.upgradeClosure()()
            
            switch result {
            case .success:
                break
                
            case .fatalError(let error):
                throw UpgradeError.Canceled(rawVersion: version.rawValue, fatalErrors: [error], nonFatalErrors: nonFatalErrors)
                
            case .nonFatalError(let error):
                nonFatalErrors.append(error)
                
            case ._jumper(let errors, let jumpVersion):
                upgradedToVersion = makeVersion(jumpVersion)!
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
            nextRawVersion = upgradedToVersion
        }
        
        if nonFatalErrors.count > 0 {
            throw UpgradeError.CompletedWithErrors(errors: nonFatalErrors)
        }
    }
    
    private func setCurrentVersion(version: T) {
        UserDefaults.standard.set(version.rawValue, forKey: version.name)
        UserDefaults.standard.synchronize()
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
