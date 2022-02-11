import SwiftSyntax

extension FunctionCallExprSyntax {
    func findArgumentIndex(name: String) -> Int? {
        argumentList
            .enumerated()
            .first { $0.element.label?.text == name }
            .map { $0.offset }
    }

    func findArgument<T: ExprSyntaxProtocol>(name: String, as type: T.Type) -> (Int, T)? {
        argumentList
            .enumerated()
            .first { $0.element.label?.text == name }
            .flatMap {
                guard let expr = $0.element.expression.as(type) else {
                    print("Expression \($0.element.expression.syntaxNodeType) cannot to be casted as \(type)")
                    return nil
                }
                return ($0.offset, expr)
            }
    }

    func hasArgument<T: ExprSyntaxProtocol>(name: String, type: T.Type) -> Bool {
        findArgument(name: name, as: type) != nil
    }

    mutating func insertArgument<T: ExprSyntaxProtocol>(name: String, onNewLine: Bool, expr: T, after: String...) {
        guard let index = after.lazy.compactMap(findArgumentIndex).first else {
            print("Couldn't find any arg named: \(after)")
            return
        }

        var tuple = TupleExprElementSyntax { builder in
            builder.useLabel(SyntaxFactory.makeIdentifier(name))
            builder.useColon(SyntaxFactory.makeColonToken(trailingTrivia: .spaces(1)))
            builder.useExpression(ExprSyntax(expr))
        }
        var argList = argumentList
        argList.ensuresTrailingCommaAfterElementAtIndex(index, trailingTrivia: onNewLine ? .zero : .spaces(1))

        let newArgIndex = index + 1
        if newArgIndex < argList.count - 1 {
            let commaTrivia: Trivia = onNewLine ? .newlines(1).appending(.spaces(4)) : .spaces(1)
            tuple = tuple.withTrailingComma(SyntaxFactory.makeCommaToken(trailingTrivia: commaTrivia))
        }
        let argTrivia: Trivia = onNewLine ? .newlines(1).appending(.spaces(4)) : .zero
        argList = argList.inserting(tuple.withLeadingTrivia(argTrivia),
            at: newArgIndex)
        self.argumentList = argList
    }
}

extension TupleExprElementListSyntax {
    mutating func ensuresTrailingCommaAfterElementAtIndex(_ index: Int, trailingTrivia: Trivia = .zero) {
        guard !isEmpty else { return }

        let childIndex = children.index(children.startIndex, offsetBy: index)

        // take the last one and append a trailing comma
        var el = self[childIndex]
        el.trailingComma = SyntaxFactory.makeCommaToken(trailingTrivia: .zero)
        self = replacing(childAt: index, with: el)
    }
}

extension ArrayExprSyntax {
    mutating func ensuresTrailingCommaOnLastElement() {
        guard !elements.isEmpty else { return }

        // take the last one and append a trailing comma
        var lastElement = elements.last!
        lastElement.trailingComma = SyntaxFactory.makeCommaToken()
        elements = elements.replacing(childAt: elements.count - 1, with: lastElement)
    }

    func appendingElementsFormatted(elements newElements: [ArrayElementSyntax], baseIndentLevel: Int) -> Self {
        func newLine() -> Trivia {
            .newlines(1).appending(.spaces(4 * baseIndentLevel))
        }
        func newLineIndent() -> Trivia {
            .newlines(1).appending(.spaces(4 * (baseIndentLevel + 1)))
        }

        return ArrayExprSyntax { builder in
            builder.useLeftSquare(SyntaxFactory.makeLeftSquareBracketToken(
                trailingTrivia: newLineIndent()))

            let allElements = (elements + newElements)

            // add existing elements
            for (index, var el) in allElements.enumerated() {
                let isLastElement = index == allElements.count - 1
                if !isLastElement {
                    el = el.withTrailingComma(SyntaxFactory.makeCommaToken())
                }

                builder.addElement(el
                    .withLeadingTrivia(.zero)
                    .withTrailingTrivia(
                        isLastElement ? newLine() : newLineIndent()
                    )
                )
            }

            builder.useRightSquare(SyntaxFactory.makeRightSquareBracketToken())
        }
    }
}

extension TupleExprElementListSyntax {
    mutating func replaceArgument<S: ExprSyntaxProtocol>(name: String, expression: S) {
        guard let (index, arg) = enumerated().first(where: { $0.element.label?.text == name }) else { return }
        let needsTrailingComma = index < count - 1

        let newArg = TupleExprElementSyntax { builder in
            builder.useLabel(SyntaxFactory.makeIdentifier(name))
            builder.useColon(SyntaxFactory.makeColonToken().withTrailingTrivia(.spaces(1)))
            builder.useExpression(ExprSyntax(expression))
            if needsTrailingComma {
                builder.useTrailingComma(SyntaxFactory.makeCommaToken())
            }
        }
        .withLeadingTrivia(arg.leadingTrivia ?? .zero)
        self = replacing(childAt: index, with: newArg)
    }
}
