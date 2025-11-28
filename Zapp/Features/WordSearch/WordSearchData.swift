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
        CypherpunkWord(word: "ZYPHERPUNK", definition: "A hackathon building the machinery of freedom through privacy innovation."),
        CypherpunkWord(word: "ZCASH", definition: "Privacy coin using cryptography to hide transaction details—transparency with anonymity."),
        CypherpunkWord(word: "PRIVACY", definition: "The foundation of cypherpunk philosophy; encryption grants it without permission."),
        CypherpunkWord(word: "CRYPTOGRAPHY", definition: "Math-powered secret codes that governments once tried to ban from civilians."),
        CypherpunkWord(word: "ENCRYPTION", definition: "Scrambling data so only intended readers can decode your secrets."),
        CypherpunkWord(word: "CYPHERPUNK", definition: "A cryptographic rebel who writes code instead of waiting for freedom."),
        CypherpunkWord(word: "BITCOIN", definition: "The OG decentralized money that proved cypherpunks weren't just theorizing."),
        CypherpunkWord(word: "MONERO", definition: "Privacy coin with ring signatures—making your transactions untraceable ghosts."),
        CypherpunkWord(word: "BLOCKCHAIN", definition: "Immutable ledger that records transactions but can keep your identity hidden."),
        CypherpunkWord(word: "DECENTRALIZED", definition: "No single point of failure—power distributed like truly owning your data."),
        CypherpunkWord(word: "ANONYMOUS", definition: "Identity hidden; cypherpunks' favorite way to stay off surveillance radars."),
        CypherpunkWord(word: "MANIFESTO", definition: "Eric Hughes' 1993 declaration that privacy isn't optional—it's necessary."),
        CypherpunkWord(word: "PGP", definition: "Phil Zimmermann's invention letting regular people encrypt emails the NSA hates."),
        CypherpunkWord(word: "TOR", definition: "Network that bounces your internet traffic through multiple nodes to hide your location."),
        CypherpunkWord(word: "CONSENSUS", definition: "Distributed agreement mechanism making manipulation nearly impossible."),
        CypherpunkWord(word: "LIBERTARIAN", definition: "Philosophy emphasizing individual freedom over centralized control—core cypherpunk fuel."),
        CypherpunkWord(word: "AUTONOMY", definition: "Self-determination; the right to control your own data without interference."),
        CypherpunkWord(word: "SURVEILLANCE", definition: "Mass monitoring cypherpunks actively work to defeat with technology."),
        CypherpunkWord(word: "CENSORSHIP", definition: "Silencing voices—exactly what decentralized systems were built to resist."),
        CypherpunkWord(word: "TRUST", definition: "What you don't need in a trustless system with strong cryptography."),
        CypherpunkWord(word: "PEER-TO-PEER", definition: "Direct transactions between users skipping the bank entirely."),
        CypherpunkWord(word: "LEDGER", definition: "Record-keeping system that can't be altered retroactively without everyone noticing."),
        CypherpunkWord(word: "FUNGIBLE", definition: "Indistinguishable units—key for privacy coins to avoid tainted coin issues."),
        CypherpunkWord(word: "ANONYMITY", definition: "Protecting identity so governments can't profile your spending habits."),
        CypherpunkWord(word: "PSEUDONYMOUS", definition: "Bitcoin's clever middle ground—traceable but divorced from real names."),
        CypherpunkWord(word: "STEALTH ADDRESS", definition: "Zcash magic allowing you to receive funds while remaining completely hidden."),
        CypherpunkWord(word: "RING SIGNATURE", definition: "Monero's technique that mixes your transaction with others to hide the real sender."),
        CypherpunkWord(word: "ZERO-KNOWLEDGE", definition: "Proving something's true without revealing the proof itself—math's greatest trick."),
        CypherpunkWord(word: "COMMITMENT", definition: "Cryptographic lock-in preventing transaction reversal without being revealed."),
        CypherpunkWord(word: "CIPHER", definition: "Encryption algorithm transforming readable text into incomprehensible gibberish."),
        CypherpunkWord(word: "PROTOCOL", definition: "Rules ensuring all participants play fairly without central referee enforcement."),
        CypherpunkWord(word: "HASH", definition: "One-way mathematical function creating unique fingerprints for data immutability."),
        CypherpunkWord(word: "MERKLE TREE", definition: "Hierarchical hashing structure allowing efficient verification of massive datasets."),
        CypherpunkWord(word: "NONCE", definition: "Random number preventing replay attacks and ensuring transaction uniqueness."),
        CypherpunkWord(word: "ELLIPTIC CURVE", definition: "Modern cryptography using curves instead of primes—faster and stronger."),
        CypherpunkWord(word: "PUBLIC KEY", definition: "The lock you share with everyone; matches only your private key."),
        CypherpunkWord(word: "PRIVATE KEY", definition: "Your secret decoder ring—losing it means losing everything forever."),
        CypherpunkWord(word: "SIGNATURE", definition: "Cryptographic proof you authorized a transaction without revealing your private key."),
        CypherpunkWord(word: "HODL", definition: "Holding cryptocurrency through market chaos—patience is a cypherpunk virtue."),
        CypherpunkWord(word: "FORK", definition: "Split in blockchain code when community can't agree, creating new chains."),
        CypherpunkWord(word: "MIXER", definition: "Service scrambling coin origins making transaction tracking impossible."),
        CypherpunkWord(word: "TUMBLER", definition: "Cash-mixing service laundering cryptocurrency through multiple wallets."),
        CypherpunkWord(word: "DUST", definition: "Tiny transaction traces bad actors use to track wallet movements."),
        CypherpunkWord(word: "WITNESS", definition: "Validator in consensus confirming transactions are legitimate and properly formatted."),
        CypherpunkWord(word: "VALIDATOR", definition: "Network participant securing blockchain by staking reputation or resources."),
        CypherpunkWord(word: "NODE", definition: "Computer running blockchain software independently participating in consensus."),
        CypherpunkWord(word: "WALLET", definition: "Software protecting your private keys like a digital strongbox for money."),
        CypherpunkWord(word: "HARDWARE WALLET", definition: "Offline device keeping private keys away from internet-connected threats."),
        CypherpunkWord(word: "TIMESTAMP", definition: "Immutable record proving something existed at a specific moment in time."),
        CypherpunkWord(word: "IMMUTABLE", definition: "Can't be changed retroactively; blockchain's core promise."),
        CypherpunkWord(word: "SATOSHI", definition: "Bitcoin's mysterious creator whose identity remains cryptocurrency's greatest secret."),
        CypherpunkWord(word: "SELF-SOVEREIGN", definition: "Total control over your identity without institutional gatekeepers."),
        CypherpunkWord(word: "SELFDETERMINATION", definition: "Choosing your own path regardless of what authorities demand."),
        CypherpunkWord(word: "CRYPTOGRAPHIC PROOF", definition: "Mathematical certainty replacing institutional authority and blind faith."),
        CypherpunkWord(word: "CIVIL LIBERTIES", definition: "Freedoms cypherpunks protect with technology instead of legal promises."),
        CypherpunkWord(word: "RESISTANCE", definition: "Cypherpunk battle against surveillance capitalism and government overreach."),
        CypherpunkWord(word: "FREEDOM", definition: "The end goal of all cypherpunk technology and philosophy."),
        CypherpunkWord(word: "DISSENT", definition: "Speaking up without fear of government retaliation—privacy enables this."),
        CypherpunkWord(word: "POLITICAL", definition: "All privacy-enhanced tech is political; choosing it is a statement."),
        CypherpunkWord(word: "REPRESSION", definition: "What centralized power uses against minorities; decentralization is the antidote."),
        CypherpunkWord(word: "INDIVIDUAL", definition: "Not collective; cypherpunks prioritize personal agency over group think."),
        CypherpunkWord(word: "EMPOWERMENT", definition: "Giving ordinary people cryptographic tools once restricted to military/governments."),
        CypherpunkWord(word: "OPEN-SOURCE", definition: "Code everyone can inspect, fork, and improve—transparency with freedom."),
        CypherpunkWord(word: "COMMUNITY", definition: "Cypherpunks work together but trust cryptography, not institutions."),
        CypherpunkWord(word: "MAILING LIST", definition: "Where early cypherpunks spread manifestos and code before the web existed."),
        CypherpunkWord(word: "ETHOS", definition: "The philosophical spirit that \"code is law\" and math beats politics."),
        CypherpunkWord(word: "REVOLUTION", definition: "Replacing power structures through technological means, not violence."),
        CypherpunkWord(word: "COUNTER-CULTURE", definition: "Rejecting mainstream acceptance of surveillance and financial control."),
        CypherpunkWord(word: "HACKER", definition: "In the original sense—talented engineers solving problems creatively."),
        CypherpunkWord(word: "DEVELOPER", definition: "Builders writing the cryptographic tools enabling cypherpunk dreams."),
        CypherpunkWord(word: "ACTIVIST", definition: "Technologist using code as protest against oppressive systems."),
        CypherpunkWord(word: "PIONEER", definition: "Early cypherpunks risking legal trouble exporting strong encryption globally."),
        CypherpunkWord(word: "PHILOSOPHY", definition: "The ideas guiding technology design—freedom must be baked in from start."),
        CypherpunkWord(word: "INNOVATION", definition: "Creating never-before-possible solutions by combining cryptography with clever design."),
        CypherpunkWord(word: "SCALABILITY", definition: "Making privacy systems fast enough for billions without sacrificing security."),
        CypherpunkWord(word: "INTEROPERABILITY", definition: "Different privacy systems working together instead of siloing into camps."),
        CypherpunkWord(word: "ADOPTION", definition: "Getting regular people to use privacy tech despite learning curves."),
        CypherpunkWord(word: "REGULATORY", definition: "The constant tension between innovation and governments wanting control."),
        CypherpunkWord(word: "JURISDICTION", definition: "Nobody owns the internet; this is cypherpunk's ultimate advantage."),
        CypherpunkWord(word: "ENFORCEMENT", definition: "Governments can't shut down what they don't control."),
        CypherpunkWord(word: "SOVEREIGNTY", definition: "Nation-states losing power to individuals armed with cryptography."),
        CypherpunkWord(word: "DISTRIBUTED", definition: "No single point of failure means no point to attack for censorship."),
        CypherpunkWord(word: "REDUNDANT", definition: "Multiple copies of data ensure survival despite any single system failure."),
        CypherpunkWord(word: "RESILIENT", definition: "Privacy systems survive attacks through distributed architecture."),
        CypherpunkWord(word: "ROBUST", definition: "Strong design preventing exploitation even if one component breaks."),
        CypherpunkWord(word: "SECURE", definition: "Protected by mathematics, not promises; that's cypherpunk security."),
        CypherpunkWord(word: "TRANSPARENT", definition: "What powerful institutions should be; cypherpunks demand it while providing privacy."),
        CypherpunkWord(word: "ACCOUNTABILITY", definition: "Making those in power answerable when protected by transparency."),
        CypherpunkWord(word: "CONSENT", definition: "Everything voluntary; joining networks means buying into the philosophy."),
        CypherpunkWord(word: "VOLUNTARY", definition: "No coercion; users choose privacy tools for genuine reasons."),
        CypherpunkWord(word: "FRICTION", definition: "Obstacles slowing bad actors from attacking your transactions."),
        CypherpunkWord(word: "THRESHOLD", definition: "Minimum participants needed for attack success—high in good designs."),
        CypherpunkWord(word: "MATURITY", definition: "Privacy tech evolving from academic research to real-world reliability."),
        CypherpunkWord(word: "LEGACY", definition: "How early cypherpunks' code and ideas still power today's privacy tools."),
        CypherpunkWord(word: "FUTURE", definition: "Cypherpunks building a world where privacy is default, not exception."),
        CypherpunkWord(word: "EQUALITY", definition: "Cryptography gives everyone the same power regardless of wealth/status."),
        CypherpunkWord(word: "MACHINERY", definition: "The \"machinery of freedom\"—tools, code, and systems enabling liberation.")
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
