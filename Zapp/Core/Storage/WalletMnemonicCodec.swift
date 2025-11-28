import Foundation

enum WalletMnemonicCodec {
    /// A fixed English wordlist used to render wallet seeds as human-readable phrases.
    ///
    /// The list contains more than 256 words; only the first 256 are used so that
    /// every possible byte value (0-255) maps to a unique word. This keeps the
    /// mapping simple and fully reversible.
    private static let words: [String] = [
        "abandon","ability","able","about","above","absent","absorb","abstract",
        "absurd","abuse","access","accident","account","accuse","achieve","acid",
        "acoustic","acquire","across","act","action","actor","actress","actual",
        "adapt","add","addict","address","adjust","admit","adult","advance",
        "advice","aerobic","affair","afford","afraid","again","age","agent",
        "agree","ahead","aim","air","airport","aisle","alarm","album",
        "alcohol","alert","alien","all","alley","allow","almost","alone",
        "alpha","already","also","alter","always","amateur","amazing","among",
        "amount","amused","analyst","anchor","ancient","anger","angle","angry",
        "animal","ankle","announce","annual","another","answer","antenna","antique",
        "anxiety","any","apart","apology","appear","apple","approve","april",
        "arch","area","arena","argue","arm","armed","armor","army",
        "around","arrange","arrest","arrive","arrow","art","artefact","artist",
        "artwork","ask","aspect","assault","asset","assist","assume","asthma",
        "athlete","atom","attack","attend","attitude","attract","auction","audit",
        "august","aunt","author","auto","autumn","average","avocado","avoid",
        "awake","aware","away","awesome","awful","awkward","axis","baby",
        "bachelor","bacon","badge","bag","balance","balcony","ball","bamboo",
        "banana","banner","bar","barely","bargain","barrel","base","basic",
        "basket","battle","beach","bean","beauty","because","become","beef",
        "before","begin","behave","behind","believe","below","belt","bench",
        "benefit","best","betray","better","between","beyond","bicycle","bid",
        "bike","bind","biology","bird","birth","bitter","black","blade",
        "blame","blanket","blast","bleak","bless","blind","blood","blossom",
        "blouse","blue","blur","blush","board","boat","body","boil",
        "bomb","bonus","book","boost","border","boring","borrow","boss",
        "bottom","bounce","box","boy","bracket","brain","brand","brass",
        "brave","bread","breeze","brick","bridge","brief","bright","bring",
        "brisk","broccoli","broken","bronze","broom","brother","brown","brush",
        "bubble","buddy","budget","buffalo","build","bulb","bulk","bullet",
        "bundle","bunker","burden","burger","burst","bus","business","busy",
        "butter","buyer","buzz","cabbage","cabin","cable","cactus","cage",
        "cake","call","calm","camera","camp","can","canal","cancel",
        "candy","cannon","canoe","canvas","canyon","capable","capital","captain",
        "car","carbon","card","cargo","carpet","carry","cart","case",
        "cash","casino","castle","casual","catalog","catch","category","cattle",
        "caught","cause","caution","cave","ceiling","celery","cement","census",
        "century","cereal","certain","chair","chalk","champion","change","chaos",
        "chapter","charge","chase","chat","cheap","check","cheese","chef",
        "cherry","chest","chicken","chief","child","chimney","choice","choose",
        "chronic","chuckle","chunk","churn","cigar","cinnamon","circle","citizen",
        "city","civil","claim","clap","clarify","claw","clay","clean",
        "clerk","clever","click","client","cliff","climb","clinic","clip"
    ]

    private static let wordToIndex: [String: UInt8] = {
        var dict: [String: UInt8] = [:]
        for (index, word) in words.enumerated() {
            // We only care about indices 0-255, but allowing more entries is fine.
            if index <= 255 {
                dict[word] = UInt8(index)
            }
        }
        return dict
    }()

    /// Encodes the given seed bytes as a space-separated phrase.
    ///
    /// Each byte maps to one word by index, so a 32-byte seed becomes a 32-word
    /// phrase. This is reversible via `seed(fromMnemonic:)`.
    static func mnemonic(fromSeed seed: [UInt8]) -> String {
        guard !seed.isEmpty else { return "" }
        return seed.map { byte in
            let index = Int(byte)
            precondition(index < 256, "Seed bytes must be in 0...255 range")
            return words[index]
        }.joined(separator: " ")
    }

    /// Decodes a phrase created by `mnemonic(fromSeed:)` back into the original bytes.
    static func seed(fromMnemonic mnemonic: String) -> [UInt8]? {
        let tokens = mnemonic
            .lowercased()
            .components(separatedBy: CharacterSet.whitespacesAndNewlines)
            .filter { !$0.isEmpty }

        guard !tokens.isEmpty else { return nil }

        var result: [UInt8] = []
        result.reserveCapacity(tokens.count)

        for token in tokens {
            guard let index = wordToIndex[token] else {
                return nil
            }
            result.append(index)
        }

        return result
    }
}
