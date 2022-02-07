import SwiftSyntax

extension FunctionCallExprSyntax {
    func findArgument<T: ExprSyntaxProtocol>(name: String, as type: T.Type) -> (Int, T)? {
        argumentList
            .enumerated()
            .first { $0.element.label?.text == name }
            .flatMap {
                guard let expr = $0.element.expression.as(type) else {
                    return nil
                }
                return ($0.offset, expr)
            }
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
