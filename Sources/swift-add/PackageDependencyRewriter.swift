import SwiftSyntax

class PackageDependencyRewriter: SyntaxRewriter {
    let packageToAdd: PackageInfo
    
    init(packageToAdd: PackageInfo) {
        self.packageToAdd = packageToAdd
    }
    
    override func visit(_ node: FunctionCallExprSyntax) -> ExprSyntax {
        if node.calledExpression.as(IdentifierExprSyntax.self)?.identifier.text == "Package" {
            // TODO: handle case where there is no dependencies arg
            let (index, deps) = node.argumentList.enumerated().first(where: { (index, tupleExpr) in
                tupleExpr.label?.text == "dependencies"
            })!
            let depsArray = deps.expression.as(ArrayExprSyntax.self)!
            dump(depsArray)
            let element = SyntaxFactory.makeArrayElement(expression: ExprSyntax(makePackageDependency()), trailingComma: nil)
                .withLeadingTrivia(.newlines(1).appending(.spaces(8)))
            let modifiedArray = depsArray.addElement(element)
            let newDeps = deps.withExpression(ExprSyntax(modifiedArray))
            
            let newNode = node.withArgumentList(node.argumentList.replacing(childAt: index, with: newDeps))
            return ExprSyntax(newNode)
        } else {
            return ExprSyntax(node)
        }
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
