import SwiftSyntax

@available(macOS 10.13, *)
extension FunctionCallExprSyntax {
    func findArgumentIndex(name: String) -> SyntaxChildrenIndex? {
        zip(arguments, arguments.indices)
            .first { (arg, index) in
                arg.label?.text == name
            }
            .map { (_, index) in index }
    }

    func findArgument<T: ExprSyntaxProtocol>(name: String, as type: T.Type) -> (SyntaxChildrenIndex, T)? {
        zip(arguments, arguments.indices)
            .first { (arg, index) in
                arg.label?.text == name
            }
            .flatMap { (arg, index) in
                guard let expr = arg.expression.as(type) else {
                    assertionFailure("Expression \(arg.expression.syntaxNodeType) cannot to be casted as \(type)")
                    return nil
                }
                return (index, expr)
            }
    }

    func hasArgument<T: ExprSyntaxProtocol>(name: String, type: T.Type) -> Bool {
        findArgument(name: name, as: type) != nil
    }

    func getStringArgumentValue(name: String) -> String? {
        if let (_, arg) = findArgument(name: name, as: StringLiteralExprSyntax.self) {
            return String(describing: arg.segments)
        }
        return nil
    }

    mutating func insertArgument<T: ExprSyntaxProtocol>(name: String, onNewLine: Bool, expr: T, after: String...) {
        guard let index = after.lazy.compactMap(findArgumentIndex).first else {
            assertionFailure("Couldn't find any arg named: \(after)")
            return
        }

        var argList = arguments
        let newArgIndex = arguments.index(after: index)
        let isLastArgument = index >= arguments.index(before: arguments.endIndex)
        let leadingTrivia: Trivia? = onNewLine ? .newlines(1).appending(TriviaPiece.spaces(4)) : nil

        var arg = LabeledExprSyntax(
            leadingTrivia: leadingTrivia,
            label: .identifier(name),
            colon: .colonToken(trailingTrivia: .space),
            expression: expr,
            trailingComma: isLastArgument ? .commaToken() : nil,
            trailingTrivia: onNewLine ? .newline.appending(TriviaPiece.spaces(4)) : nil
        )
        argList.ensuresTrailingCommaAfterElementAtIndex(index, trailingTrivia: onNewLine ? nil : .space)

        argList.insert(arg, at: newArgIndex)
        self.arguments = argList
    }
}

extension LabeledExprListSyntax {
    mutating func ensuresTrailingCommaAfterElementAtIndex(_ childIndex: SyntaxChildrenIndex, trailingTrivia: Trivia? = nil) {
        // take the last one and append a trailing comma
        var el = self[childIndex]
        el.trailingComma = .commaToken()
        self = self.with(\.[childIndex], el)
    }

    mutating func ensuresTrailingCommaAfterElementAtIndex(_ index: Int, trailingTrivia: Trivia? = nil) {
        let children = self.children(viewMode: .sourceAccurate)
        let childIndex = children.index(children.startIndex, offsetBy: index)
        ensuresTrailingCommaAfterElementAtIndex(childIndex, trailingTrivia: trailingTrivia)
    }
}

extension ArrayExprSyntax {
    mutating func ensuresTrailingCommaOnLastElement() {
        guard !elements.isEmpty else { return }

        // take the last one and append a trailing comma
        var lastElement = elements.last!
        lastElement.trailingComma = .commaToken()
        let index = elements.index(before: elements.endIndex)
        elements = elements.with(\.[index], lastElement)
    }

    func appendingElementsFormatted(elements newElements: [ArrayElementSyntax], baseIndentLevel: Int) -> Self {
        func newLine() -> Trivia {
            Trivia.newline.appending(Trivia.spaces(4 * baseIndentLevel))
        }
        func newLineIndent() -> Trivia {
            Trivia.newline.appending(Trivia.spaces(4 * (baseIndentLevel + 1)))
        }
        fatalError()

//        return ArrayExprSyntax { builder in
//            builder.useLeftSquare(SyntaxFactory.makeLeftSquareBracketToken(
//                trailingTrivia: newLineIndent()))
//
//            let allElements = (elements + newElements)
//
//            // add existing elements
//            for (index, var el) in allElements.enumerated() {
//                let isLastElement = index == allElements.count - 1
//                if !isLastElement {
//                    el = el.withTrailingComma(SyntaxFactory.makeCommaToken())
//                }
//
//                builder.addElement(el
//                    .withLeadingTrivia(.zero)
//                    .withTrailingTrivia(
//                        isLastElement ? newLine() : newLineIndent()
//                    )
//                )
//            }
//
//            builder.useRightSquare(SyntaxFactory.makeRightSquareBracketToken())
//        }
    }
}

extension LabeledExprListSyntax {
    mutating func replaceArgument<S: ExprSyntaxProtocol>(name: String, expression: S) {
        guard let index = firstIndex(where: { $0.label?.text == name }) else {
            assertionFailure("Cannot find argument named: `\(name)` in \(self.description)")
            return
        }

        let arg = self[index]
        let needsTrailingComma = index < self.index(before: endIndex)

        let newArg = LabeledExprSyntax(
            leadingTrivia: arg.leadingTrivia,
            label: .identifier(name),
            colon: .colonToken(),
            expression: expression,
            trailingComma: needsTrailingComma ? .commaToken() : nil,
            trailingTrivia: nil
        )
        self = self.with(\.[index], newArg)
    }
}
