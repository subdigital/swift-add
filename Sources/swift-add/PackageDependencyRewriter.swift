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

        guard let (index, depsArray) = node.findArgument(name: "dependencies", as: ArrayExprSyntax.self) else {
            // TODO: handle case where there is no dependencies arg
            return ExprSyntax(node)
        }

        var newNode = node
        
        addPackageToDependenciesArray(call: &newNode)
        updateTargetDependencies(call: &newNode)
        // print("UPDATED TARGETS:", updatedTargets)

        return ExprSyntax(newNode)
    }

    func deriveIndentationTrivia(_ call: FunctionCallExprSyntax, level: Int) -> TriviaPiece {
        .spaces(4 * level)
    }

    func updateTargetDependencies(call: inout FunctionCallExprSyntax) {
        guard let (targetsIndex, targets) = call.findArgument(name: "targets", as: ArrayExprSyntax.self) else { return }

        // always add to first target?
        guard let target = targets.elements.first else {
            // targets is empty
            return
        }

        guard var targetCall = target.expression.as(FunctionCallExprSyntax.self) else {
            return
        }
        
        if var (_, depsArray) = targetCall.findArgument(name: "dependencies", as: ArrayExprSyntax.self) {
            depsArray.ensuresTrailingCommaOnLastElement()
            depsArray = depsArray.addElement(.init {
                $0.useExpression(self.createTargetDependency())
            }.withLeadingTrivia(
                .newlines(1).appending(deriveIndentationTrivia(call, level: 4))
            ))
            targetCall.argumentList.replaceArgument(name: "dependencies", expression: ExprSyntax(depsArray))
            let modifiedTargets = targets.elements.replacing(childAt: 0, with: ArrayElementSyntax {
                $0.useExpression(ExprSyntax(targetCall))
                $0.useTrailingComma(SyntaxFactory.makeCommaToken())
            })
            var array = ArrayExprSyntax({ _ in })
            array.elements = modifiedTargets
            call.argumentList.replaceArgument(name: "targets", expression: array)
        } else {
            // insert new dependencies section
        }
        
    }
    
    private func createTargetDependency() -> ExprSyntax {
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
                    arg.useExpression(ExprSyntax(SyntaxFactory.makeStringLiteralExpr("????")))
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
