import SwiftSyntax

class PackageDependencyRewriter: SyntaxRewriter {
    let packageToAdd: PackageInfo

    init(packageToAdd: PackageInfo) {
        self.packageToAdd = packageToAdd
    }

    override func visit(_ node: FunctionCallExprSyntax) -> ExprSyntax {
        guard node.calledExpression.as(IdentifierExprSyntax.self)?.identifier.text == "Package" else {
            return ExprSyntax(node)
        }

        // TODO: handle case where there is no dependencies arg
        let (index, deps) = node.argumentList.enumerated().first(where: { (index, tupleExpr) in tupleExpr.label?.text == "dependencies" })!

        let depsArray = deps.expression.as(ArrayExprSyntax.self)!
        let element = SyntaxFactory
            .makeArrayElement(expression: ExprSyntax(makePackageDependency()), trailingComma: nil)
            .withLeadingTrivia(.newlines(1).appending(.spaces(8)))
        
        var modifiedArray = depsArray
        if !depsArray.elements.isEmpty {
            // take the last one and append a trailing comma
            var lastElement = depsArray.elements.last!
            lastElement.trailingComma = SyntaxFactory.makeCommaToken()
            modifiedArray.elements = modifiedArray.elements.replacing(childAt: depsArray.elements.count - 1, with: lastElement)
        }
        
        modifiedArray = modifiedArray.addElement(element)
        let newDeps = deps.withExpression(ExprSyntax(modifiedArray))

        let newNode = node.withArgumentList(node.argumentList.replacing(childAt: index, with: newDeps))
        return ExprSyntax(newNode)
    }

    func makePackageDependency() -> FunctionCallExprSyntax {
        let memberAccess = MemberAccessExprSyntax { builder in
            builder.useDot(SyntaxFactory.makePrefixPeriodToken())
            builder.useName(SyntaxFactory.makeIdentifier("package"))
        }

        return FunctionCallExprSyntax { builder in
            builder.useCalledExpression(ExprSyntax(memberAccess))
            builder.useLeftParen(SyntaxFactory.makeLeftParenToken())

            // url
            builder.addArgument(TupleExprElementSyntax { builder in
                builder.useLabel(SyntaxFactory.makeIdentifier("url"))
                builder.useColon(SyntaxFactory.makeColonToken().withTrailingTrivia(.spaces(1)))
                builder.useExpression(ExprSyntax(SyntaxFactory.makeStringLiteralExpr(packageToAdd.url.absoluteString)))
                builder.useTrailingComma(SyntaxFactory.makeCommaToken())
            }.withTrailingTrivia(.spaces(1)))

            // from
            builder.addArgument(TupleExprElementSyntax { builder in
                builder.useLabel(SyntaxFactory.makeIdentifier("from"))
                builder.useColon(SyntaxFactory.makeColonToken().withTrailingTrivia(.spaces(1)))
                builder.useExpression(ExprSyntax(SyntaxFactory.makeStringLiteralExpr(packageToAdd.version)))
            })

            builder.useRightParen(SyntaxFactory.makeRightParenToken())
        }
    }
}
