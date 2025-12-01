import Foundation

/// A word with its definition for the word search game
struct CypherpunkWord: Identifiable, Equatable {
    let id = UUID()
    let word: String
    let definition: String
    
    /// Cleaned word for grid placement (removes spaces and hyphens)
    var cleanedWord: String {
        word.uppercased().replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "-", with: "")
    }
}

/// All cypherpunk words and their definitions
enum WordSearchData {
    static let allWords: [CypherpunkWord] = [
        CypherpunkWord(word: "ZCASH", definition: "Cryptocurrency using zero-knowledge proofs to hide transaction details, amounts, and parties involved."),
        CypherpunkWord(word: "SHIELDED", definition: "Hidden transactions where sender, receiver, and amount are cryptographically concealed from public view."),
        CypherpunkWord(word: "TRANSPARENT", definition: "Visible transactions on blockchain; the opposite of privacy—what cypherpunks actively avoid."),
        CypherpunkWord(word: "ZERO-KNOWLEDGE", definition: "Proving a statement's truth without revealing the proof itself—privacy's mathematical foundation."),
        CypherpunkWord(word: "NULLIFIER", definition: "Cryptographic marker preventing double-spending while keeping transaction sender secret."),
        CypherpunkWord(word: "VIEWING KEY", definition: "Secret credential allowing only the recipient to decrypt their own shielded transactions."),
        CypherpunkWord(word: "MERKLE TREE", definition: "Hierarchical data structure enabling efficient verification of massive transaction sets."),
        CypherpunkWord(word: "BRIDGE", definition: "Cross-chain protocol connecting Zcash to other blockchains while preserving privacy."),
        CypherpunkWord(word: "INTEROPERABILITY", definition: "Different blockchains communicating seamlessly without compromising user privacy or security."),
        CypherpunkWord(word: "DEFI", definition: "Decentralized finance—financial services controlled by code, not banks; privacy makes it censorship-resistant."),
        CypherpunkWord(word: "DARK POOL", definition: "Private trading venue where orders remain hidden from public, protecting traders from manipulation."),
        CypherpunkWord(word: "MEV", definition: "Miner Extractable Value—when validators exploit transaction order for profit; privacy eliminates this threat."),
        CypherpunkWord(word: "FRONT-RUNNING", definition: "Exploiting knowledge of pending transactions to profit unfairly; privacy solutions prevent this."),
        CypherpunkWord(word: "ORDINAL", definition: "Transaction sequencing; keeping order private prevents adversaries from manipulating DeFi outcomes."),
        CypherpunkWord(word: "LIQUIDITY POOL", definition: "Shared assets enabling trading; privacy pools hide individual trader positions from competitors."),
        CypherpunkWord(word: "SWAP", definition: "Exchanging one asset for another; privacy swaps hide trade amounts and participants from surveillance."),
        CypherpunkWord(word: "LAUNCHPAD", definition: "Platform for new token releases; privacy launchpads prevent early front-running and whale attacks."),
        CypherpunkWord(word: "STABLECOIN", definition: "Cryptocurrency pegged to stable value; privacy stablecoins hide transaction amounts in everyday payments."),
        CypherpunkWord(word: "ORACLE", definition: "External data source feeding prices on-chain; privacy oracles compute values on encrypted data."),
        CypherpunkWord(word: "COLLATERAL", definition: "Assets locked as insurance for loans; privacy collateral hides your financial position."),
        CypherpunkWord(word: "YIELD", definition: "Returns on invested crypto; private yield farming hides strategies from competitors and tax surveillance."),
        CypherpunkWord(word: "LENDING", definition: "Borrowing and loaning assets; privacy lending hides loan amounts and parties."),
        CypherpunkWord(word: "PERPETUALS", definition: "Derivatives allowing unlimited leverage trading; privacy perpetuals hide positions from liquidation hunters."),
        CypherpunkWord(word: "WALLET", definition: "Software securing private keys; privacy wallets add multiple layers of anonymity protection."),
        CypherpunkWord(word: "SELF-CUSTODY", definition: "You control your private keys; privacy self-custody means nobody else knows your holdings."),
        CypherpunkWord(word: "HARDWARE WALLET", definition: "Offline device protecting keys; privacy hardware wallets disconnect completely from internet surveillance."),
        CypherpunkWord(word: "MULTICOIN", definition: "Wallet supporting multiple blockchains; privacy multicoin wallets hide cross-chain activity."),
        CypherpunkWord(word: "SDK", definition: "Software Development Kit—tools making it easier for developers to build privacy applications."),
        CypherpunkWord(word: "PCZT", definition: "Partially Constructed Zcash Transaction—allowing transparent users to create shielded payments."),
        CypherpunkWord(word: "PAYMENT PROCESSOR", definition: "Service converting payments to crypto; privacy processors hide transaction details from third parties."),
        CypherpunkWord(word: "POINT-OF-SALE", definition: "Retail payment terminal; privacy POS systems let facilitators accept anonymous crypto payments."),
        CypherpunkWord(word: "REMITTANCE", definition: "Money sent across borders; privacy remittances hide migrant worker transfers from governments."),
        CypherpunkWord(word: "MICROPAYMENT", definition: "Tiny transactions economically infeasible with traditional systems; privacy micropayments enable censorship-resistant donations."),
        CypherpunkWord(word: "ATOMIC SWAP", definition: "Direct peer-to-peer asset exchange across chains; privacy atomic swaps hide both sides."),
        CypherpunkWord(word: "FULLY HOMOMORPHIC ENCRYPTION", definition: "Revolutionary technique allowing computation on encrypted data without ever decrypting it."),
        CypherpunkWord(word: "ENCRYPTED COMPUTE", definition: "Processing sensitive data while keeping it encrypted—no one sees the raw information."),
        CypherpunkWord(word: "CONFIDENTIAL COMPUTE", definition: "TEE-based execution ensuring data stays private even from cloud infrastructure operators."),
        CypherpunkWord(word: "TEE", definition: "Trusted Execution Environment—isolated processor regions preventing even administrators from spying."),
        CypherpunkWord(word: "VERIFIABLE PROOF", definition: "Mathematical proof that computation was done correctly without revealing inputs or results."),
        CypherpunkWord(word: "RECURSIVE PROOF", definition: "Proofs proving other proofs; Mina Protocol's innovation enabling infinite scalability with privacy."),
        CypherpunkWord(word: "ZKAPP", definition: "Zero-knowledge app—application where privacy and verification combine seamlessly."),
        CypherpunkWord(word: "PASTA CURVES", definition: "Cryptographic curves used by both Zcash and Mina, enabling efficient privacy proofs."),
        CypherpunkWord(word: "ELLIPTIC CURVE", definition: "Mathematical foundation for modern cryptography; curves enable smaller, faster, stronger privacy."),
        CypherpunkWord(word: "SEMAPHORE", definition: "Privacy protocol proving group membership without revealing which member you are."),
        CypherpunkWord(word: "ANONYMOUS CREDENTIALS", definition: "Proving you have permissions without identifying yourself—the ultimate privacy document."),
        CypherpunkWord(word: "PROOF OF INNOCENCE", definition: "Demonstrating you're not on a blacklist without revealing your identity whatsoever."),
        CypherpunkWord(word: "VIEWABLE TRANSACTIONS", definition: "Personal transparency where only you can decrypt your transactions using viewing keys."),
        CypherpunkWord(word: "SHIELDED MEMO", definition: "Private message embedded in Zcash transactions—visible only to sender and receiver."),
        CypherpunkWord(word: "CROSS-CHAIN MESSAGING", definition: "Relaying information between blockchains while keeping both transactions and message encrypted."),
        CypherpunkWord(word: "LIGHT CLIENT", definition: "Lightweight software verifying blockchain without downloading entire history; privacy light clients hide your IP."),
        CypherpunkWord(word: "CONSENSUS", definition: "Network agreement on transaction validity; decentralized consensus prevents any single point controlling privacy."),
        CypherpunkWord(word: "PRIVACY INFRASTRUCTURE", definition: "Developer tools, libraries, and protocols making privacy-by-default easier to implement."),
        CypherpunkWord(word: "FRAMEWORK", definition: "Foundational structure simplifying development; privacy frameworks bake anonymity into every layer."),
        CypherpunkWord(word: "TESTING FRAMEWORK", definition: "Tools validating privacy properties haven't been compromised during development."),
        CypherpunkWord(word: "DEBUGGING TOOL", definition: "Software identifying problems while respecting privacy; privacy debuggers never log sensitive data."),
        CypherpunkWord(word: "OPEN-SOURCE", definition: "Code publicly visible for inspection; privacy projects must be open-source for trust."),
        CypherpunkWord(word: "REPOSITORY", definition: "Centralized code storage; privacy repositories ensure transparent security audits."),
        CypherpunkWord(word: "DOCUMENTATION", definition: "Written explanations of how code works; privacy documentation is essential for adoption."),
        CypherpunkWord(word: "ANALYTICS", definition: "Data analysis revealing trends; privacy analytics compute insights on encrypted data."),
        CypherpunkWord(word: "DASHBOARD", definition: "Visual interface displaying information; privacy dashboards let users view data without servers seeing it."),
        CypherpunkWord(word: "ALERT SYSTEM", definition: "Notifications triggering on events; privacy alerts notify you without revealing what triggered them."),
        CypherpunkWord(word: "BLOCKCHAIN EXPLORER", definition: "Interface viewing transaction history; privacy explorers show you your history without showing others."),
        CypherpunkWord(word: "PRIVACY POOL", definition: "Liquidity combining transactions, obscuring sources; mixing in privacy pools amplifies anonymity."),
        CypherpunkWord(word: "MIXER", definition: "Service shuffling transactions; privacy mixers make transaction origin impossible to trace."),
        CypherpunkWord(word: "TUMBLER", definition: "Advanced mixer layering transactions; privacy tumblers create complex obfuscation."),
        CypherpunkWord(word: "PARTIAL NOTES", definition: "Divided transaction outputs; partial notes enable creative cross-chain privacy constructions."),
        CypherpunkWord(word: "MPC", definition: "Multi-Party Computation—collaborative calculation where no participant sees others' data."),
        CypherpunkWord(word: "EIGENLAYER", definition: "Restaking infrastructure securing bridges; EigenLayer AVS adds economic security to privacy bridges."),
        CypherpunkWord(word: "AVS", definition: "Actively Validated Service—specializing in specific tasks like securing cross-chain privacy transfers."),
        CypherpunkWord(word: "PRIVATE BRIDGE", definition: "Cross-chain connection hiding transfer amounts and participants from surveillance."),
        CypherpunkWord(word: "DECENTRALIZED DESIGN", definition: "Protocol controlled by distributed participants, not corporations; decentralized privacy means no backdoors."),
        CypherpunkWord(word: "RISK MANAGEMENT", definition: "Preventing financial losses; privacy risk management hides positions until optimally executed."),
        CypherpunkWord(word: "AGENTIC MODELS", definition: "AI systems acting autonomously; private AI agents spend your ZEC based on your values, not corporate surveillance."),
        CypherpunkWord(word: "NATURAL LANGUAGE", definition: "Human-friendly interface; privacy via natural language means AI understands intentions without recording details."),
        CypherpunkWord(word: "PHILANTHROPY", definition: "Charitable giving; private philanthropy lets donors support causes without government/public surveillance."),
        CypherpunkWord(word: "INFERENCE", definition: "AI prediction from data; private inference computes answers without the AI seeing your personal data."),
        CypherpunkWord(word: "TRAINING", definition: "Teaching AI models; private training builds AI without exposing training data to anyone."),
        CypherpunkWord(word: "MULTI-PARTY COMPUTATION", definition: "Collaborative crypto protocols where participants jointly compute without sharing individual data."),
        CypherpunkWord(word: "PRIVACY-FIRST", definition: "Designing with anonymity as primary requirement, not afterthought; privacy-first architecture is uncompromising."),
        CypherpunkWord(word: "CAIRO", definition: "Provable programming language writing zero-knowledge proofs; Cairo enables efficient privacy computation."),
        CypherpunkWord(word: "CONSTRAINT", definition: "Mathematical rule proving correct execution; privacy constraints encode anonymity requirements."),
        CypherpunkWord(word: "PROVER", definition: "Entity generating zero-knowledge proofs; privacy provers never reveal what they're proving."),
        CypherpunkWord(word: "VERIFIER", definition: "Checking proof validity; privacy verifiers confirm correctness without learning transaction details."),
        CypherpunkWord(word: "ROLLUP", definition: "Bundling transactions off-chain then posting proof; privacy rollups scale while hiding data."),
        CypherpunkWord(word: "STARKNET", definition: "Zero-knowledge rollup platform; Starknet enables provable privacy at scale."),
        CypherpunkWord(word: "CONFIDENTIAL TRANSACTION", definition: "Cryptographic method hiding amounts while proving no inflation occurred."),
        CypherpunkWord(word: "RANGE PROOF", definition: "Proving number is within bounds without revealing exact value; enables amount hiding."),
        CypherpunkWord(word: "COMMITMENT SCHEME", definition: "Cryptographic lock proving you selected something without revealing selection until later."),
        CypherpunkWord(word: "STEALTH ADDRESS", definition: "One-time destination address generated for each transaction, preventing address linking."),
        CypherpunkWord(word: "ADDRESS LINKING", definition: "Connecting addresses to same person; privacy addresses prevent this fundamental tracking."),
        CypherpunkWord(word: "LINKABILITY", definition: "Risk that transactions get connected to same user; zero linkability is true privacy."),
        CypherpunkWord(word: "FUNGIBILITY", definition: "Coins being indistinguishable; perfect fungibility means no coin is suspicious or blacklisted."),
        CypherpunkWord(word: "TAINTED COIN", definition: "Cryptocurrency associated with crime; fungible privacy coins can't be discriminated against."),
        CypherpunkWord(word: "COIN ANALYSIS", definition: "Tracking transaction history; privacy coins defeat coin analysis through cryptographic obfuscation."),
        CypherpunkWord(word: "HASHING", definition: "One-way mathematical function ensuring data integrity; privacy hashing lets you prove data without revealing it."),
        CypherpunkWord(word: "ENCRYPTION STANDARD", definition: "Proven algorithms like AES protecting data; privacy standards undergo public scrutiny before real-world use."),
        CypherpunkWord(word: "SECURITY AUDIT", definition: "Expert review of code for vulnerabilities; privacy projects must pass security audits before launch."),
        CypherpunkWord(word: "FRONT-END", definition: "User interface; privacy front-ends hide wallet addresses and transaction amounts from casual observation."),
        CypherpunkWord(word: "BACK-END", definition: "Server infrastructure; privacy back-ends never log which users requested what information."),
        CypherpunkWord(word: "DECRYPTION", definition: "Unlocking encrypted data; only holders of private keys can successfully decrypt shielded transactions.")
    ]
    
    /// Get a random subset of words suitable for a single puzzle
    /// - Parameter count: Number of words to include (default 8)
    /// - Returns: Array of randomly selected words
    static func randomWords(count: Int = 8) -> [CypherpunkWord] {
        // Filter to words that fit well in a grid (not too long)
        let suitableWords = allWords.filter { $0.cleanedWord.count <= 12 }
        return Array(suitableWords.shuffled().prefix(count))
    }
    
    /// Get words by difficulty (shorter words are easier)
    static func words(forDifficulty difficulty: WordSearchDifficulty) -> [CypherpunkWord] {
        switch difficulty {
        case .easy:
            return allWords.filter { $0.cleanedWord.count <= 6 }.shuffled()
        case .medium:
            return allWords.filter { $0.cleanedWord.count > 6 && $0.cleanedWord.count <= 9 }.shuffled()
        case .hard:
            return allWords.filter { $0.cleanedWord.count > 9 }.shuffled()
        }
    }
}

enum WordSearchDifficulty: String, CaseIterable {
    case easy = "Easy"
    case medium = "Medium"
    case hard = "Hard"
}
