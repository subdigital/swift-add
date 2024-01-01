enum PackageDescriptor: CustomStringConvertible {
    case version(String)
    case gitBranch(repo: String, branch: String)

    static func inferredGitRepo(packageName: String, branch: String) -> Self {
        if packageName.starts(with: "http")  {
            return .gitBranch(repo: packageName, branch: branch)
        }

        // assume owner/repo format
        return .gitBranch(repo: "https://github.com/\(packageName)", branch: branch)
    }
    
    var description: String {
        switch self {
        case .version(let v): return v
        case .gitBranch(let repo, let branch): return "\(repo) branch: \(branch)"
        }
    }
}

