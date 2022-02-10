import SwiftSyntax

class PackageDependencyRewriter: SyntaxRewriter {
    let packageToAdd: PackageInfo

    init(packageToAdd: PackageInfo) {
        self.packageToAdd = packageToAdd
    }
    
    private var rootNode: FunctionCallExprSyntax!
    
    func indent(level: Int, withNewLine: Bool = false) -> Trivia {
        .newlines(withNewLine ? 1 : 0).appending(deriveIndentationTrivia(rootNode, level: level))
    }

    override func visit(_ node: FunctionCallExprSyntax) -> ExprSyntax {
        self.rootNode = node
        guard node.calledExpression.as(IdentifierExprSyntax.self)?.identifier.text == "Package" else {
            return ExprSyntax(node)
        }
        var node = node

        if !node.hasArgument(name: "dependencies", type: ArrayExprSyntax.self) {
            let blankArray = SyntaxFactory.makeArrayExpr(
                leftSquare: SyntaxFactory.makeLeftSquareBracketToken(),
                elements: SyntaxFactory.makeBlankArrayElementList(),
                rightSquare: SyntaxFactory.makeRightSquareBracketToken(leadingTrivia: .newlines(1).appending(.spaces(4)))
            )
            node.insertArgument(name: "dependencies", onNewLine: true, expr: blankArray, after: "platform", "name")
        }

        addPackageToDependenciesArray(call: &node)
        updateTargetDependencies(call: &node)

        return ExprSyntax(node)
    }

    func deriveIndentationTrivia(_ call: FunctionCallExprSyntax, level: Int) -> TriviaPiece {
        .spaces(4 * level)
    }
    
    func updateTargetDependencies(call: inout FunctionCallExprSyntax) {
        guard let (_, targets) = call.findArgument(name: "targets", as: ArrayExprSyntax.self) else { return }

        // TODO: prompt the user if there is more than one product
        guard let product = packageToAdd.products.first else { return }

        // always add to first target?
        guard let target = targets.elements.first else {
            // targets is empty
            return
        }

        // .executableTarget(...)
        guard var targetCall = target.expression.as(FunctionCallExprSyntax.self) else {
            return
        }
        
        if let (_, depsArray) = targetCall.findArgument(name: "dependencies", as: ArrayExprSyntax.self) {
            let newArray = ArrayExprSyntax { builder in
                builder.useLeftSquare(SyntaxFactory.makeLeftSquareBracketToken(trailingTrivia: indent(level: 3, withNewLine: true)))
                for (index, var el) in depsArray.elements.enumerated() {
                    if index == depsArray.elements.count - 1 {
                        el = el.withTrailingComma(SyntaxFactory.makeCommaToken())
                    }
                    builder.addElement(
                        el
                            .withLeadingTrivia(.zero)
                            .withTrailingTrivia(indent(level: 3, withNewLine: true))
                    )
                }
                let newEl = ArrayElementSyntax {
                    $0.useExpression(self.createTargetDependency(product: product))
                }.withTrailingTrivia(indent(level: 2, withNewLine: true))
                builder.addElement(newEl)
                                     
                builder.useRightSquare(SyntaxFactory.makeRightSquareBracketToken())
            }

            targetCall.argumentList.replaceArgument(name: "dependencies", expression: ExprSyntax(newArray))
            let modifiedTargets = targets.elements.replacing(childAt: 0, with: ArrayElementSyntax {
                $0.useExpression(ExprSyntax(targetCall))
                if targets.elements.count > 1 {
                    $0.useTrailingComma(SyntaxFactory.makeCommaToken())
                }
            })
            var array = ArrayExprSyntax { builder in
                builder.useLeftSquare(SyntaxFactory.makeLeftSquareBracketToken())
                builder.useRightSquare(SyntaxFactory.makeRightSquareBracketToken()
                                        .withLeadingTrivia(.newlines(1).appending(.spaces(4))))
            }
            array.elements = modifiedTargets
            call.argumentList.replaceArgument(name: "targets", expression: array)
        } else {
            // insert new dependencies section
        }
    }
    
    private func createTargetDependency(product: ProductInfo) -> ExprSyntax {
        // .product(name: ..., package: ...)
        ExprSyntax(
            FunctionCallExprSyntax { fn in
                fn.useCalledExpression(
                    ExprSyntax(
                        MemberAccessExprSyntax { memberAccess in
                            memberAccess.useDot(SyntaxFactory.makePrefixPeriodToken())
                            memberAccess.useName(SyntaxFactory.makeIdentifier("product"))
                        }
                    )
                )
                fn.useLeftParen(SyntaxFactory.makeLeftParenToken())
                fn.addArgument(.init { arg in
                    arg.useLabel(SyntaxFactory.makeIdentifier("name"))
                    arg.useColon(SyntaxFactory.makeColonToken().withTrailingTrivia(.spaces(1)))
                    arg.useExpression(ExprSyntax(SyntaxFactory.makeStringLiteralExpr(product.name)))
                }.withTrailingComma(SyntaxFactory.makeCommaToken().withTrailingTrivia(.spaces(1))))
                fn.addArgument(.init { arg in
                    arg.useLabel(SyntaxFactory.makeIdentifier("package"))
                    arg.useColon(SyntaxFactory.makeColonToken().withTrailingTrivia(.spaces(1)))
                    arg.useExpression(ExprSyntax(SyntaxFactory.makeStringLiteralExpr(packageToAdd.name)))
                })
                fn.useRightParen(SyntaxFactory.makeRightParenToken())
            }
        )
    }

    func addPackageToDependenciesArray(call: inout FunctionCallExprSyntax) {
        // TODO: smarter handling of indentation
        
        let element = SyntaxFactory
            .makeArrayElement(expression: ExprSyntax(makePackageDependency()), trailingComma: nil)
            .withLeadingTrivia(.newlines(1).appending(.spaces(8)))
        
        guard var (_, dependencies) = call.findArgument(name: "dependencies", as: ArrayExprSyntax.self) else {
            // TODO: add dependencies section
            return
        }
        dependencies.ensuresTrailingCommaOnLastElement()
        dependencies = dependencies.addElement(element)
     
        call.argumentList.replaceArgument(name: "dependencies", expression: dependencies)
    }

    func makePackageDependency() -> FunctionCallExprSyntax {
        let memberAccess = MemberAccessExprSyntax { builder in
            builder.useDot(SyntaxFactory.makePrefixPeriodToken())
            builder.useName(SyntaxFactory.makeIdentifier("package"))
        }

        return FunctionCallExprSyntax { builder in
            builder.useCalledExpression(ExprSyntax(memberAccess))
            builder.useLeftParen(SyntaxFactory.makeLeftParenToken())

            // name: "...",
            builder.addArgument(TupleExprElementSyntax { builder in
                builder.useLabel(SyntaxFactory.makeIdentifier("name"))
                builder.useColon(SyntaxFactory.makeColonToken(trailingTrivia: .spaces(1)))
                builder.useExpression(ExprSyntax(SyntaxFactory.makeStringLiteralExpr(packageToAdd.name)))
                builder.useTrailingComma(SyntaxFactory.makeCommaToken())
            }.withTrailingTrivia(.spaces(1)))

            // url: "....",
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
