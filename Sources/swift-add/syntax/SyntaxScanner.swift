import SwiftSyntax

class SyntaxScanner {
    let file: SourceFileSyntax

    init(file: SourceFileSyntax) {
        self.file = file
    }

    /// Looks for a sequence of tokens recursively. Returns the next token after the sequence, or nil if at the end of the
    /// tokens or the sequence was not found.
    func scanForPattern<Collection: MutableCollection>(start: TokenSyntax?, pattern: Collection, allowSkip: Bool = true) -> TokenSyntax? 
        where Collection.Element == TokenKind
    {
        guard let start = start else { return nil }
        if pattern.isEmpty { return start }

        let lookingFor = pattern.first!
        if start.tokenKind == lookingFor {
            return scanForPattern(start: start.nextToken, pattern: pattern.dropFirst(), allowSkip: false)
        }

        if allowSkip {
            return scanForPattern(start: start.nextToken, pattern: pattern)
        } else {
            return nil
        }
    }

    /// Scans the syntax until it finds the token with the specified kind
    func scanUntil(from: TokenSyntax? = nil, kind: TokenKind) -> TokenSyntax? {
        guard var token = from ?? file.firstToken else { return nil }
        while token.tokenKind != kind {
            guard let next = token.nextToken else { return nil }
            token = next
        }
        return token
    }

    /// Takes an opening token ({[ and collects all of the tokens until the corresponding closing token.
    /// nested scopes are flattened and included.
    func tokensInScope(token: TokenSyntax) -> [TokenSyntax] {
        var tokens: [TokenSyntax] = []

        func isNewScope(_ kind: TokenKind) -> Bool {
            switch kind {
            case .leftParen, .leftBrace, .leftSquareBracket: return true
            default: return false
            }
        }

        func isClosingToken(_ kind: TokenKind) -> Bool {
            switch (token.tokenKind, kind) {
            case (.leftParen, .rightParen),
                 (.leftBrace, .rightBrace),
                 (.leftSquareBracket, .rightSquareBracket):
                 return true
            default: return false
            }
        }

        var t = token.nextToken
        while t != nil && !isClosingToken(t!.tokenKind) {
            tokens.append(t!)
            if isNewScope(t!.tokenKind) {
                let nested = tokensInScope(token: t!)
                tokens.append(contentsOf: nested)
                // add closing token and advance so we don't break the outer while loop on this one
                let closing = nested.last!.nextToken
                if let closing = closing {
                    tokens.append(closing)
                    t = closing.nextToken
                } else {
                    break
                }
            } else {
                t = t?.nextToken
            }
        }

        return tokens
    }
}

