import SwiftSyntax
import SwiftSyntaxBuilder

class PackageDependencyRewriter: SyntaxRewriter {
    let packageToAdd: PackageInfo
    let products: [ProductInfo]

    init(packageToAdd: PackageInfo, products: [ProductInfo]) {
        self.packageToAdd = packageToAdd
        self.products = products
    }

    private var rootNode: FunctionCallExprSyntax!

    func indent(level: Int, withNewLine: Bool = false) -> Trivia {
        .newlines(withNewLine ? 1 : 0).appending(deriveIndentationTrivia(rootNode, level: level))
    }

    override func visit(_ node: FunctionCallExprSyntax) -> ExprSyntax {
        self.rootNode = node
        guard node.calledExpression.as(DeclReferenceExprSyntax.self)?.baseName.text == "Package" else {
            return ExprSyntax(node)
        }
        var node = node

        // create a dependencies section if there isn't one already
        if !node.hasArgument(name: "dependencies", type: ArrayExprSyntax.self) {
            let arraySyntax = ArrayExprSyntax {

            }
            node.insertArgument(name: "dependencies", onNewLine: true, expr: arraySyntax, after: "platform", "name")
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

            let newElements = products.compactMap { product in
                ArrayElementSyntax(self.createTargetDependency(product: product))
            }
            let newArray = depsArray.appendingElementsFormatted(elements: newElements, baseIndentLevel: 2)

            targetCall.arguments.replaceArgument(name: "dependencies", expression: ExprSyntax(newArray))
//            let modifiedTargets = targets.elements.replacing(childAt: 0, with: ArrayElementSyntax(targetCall)
//
//                                                             ArrayEx
//            var array = ArrayExprSyntax { builder in
//                builder.useLeftSquare(SyntaxFactory.makeLeftSquareBracketToken())
//                builder.useRightSquare(SyntaxFactory.makeRightSquareBracketToken()
//                                        .withLeadingTrivia(.newlines(1).appending(.spaces(4))))
//            }
//            array.elements = modifiedTargets
//            call.argumentList.replaceArgument(name: "targets", expression: array)
        } else {
            // insert new dependencies section
        }
    }

    private func createTargetDependency(product: ProductInfo) -> ExprSyntax {
        // .product(name: ..., package: ...)
        return ExprSyntax(stringLiteral: #".product(name: "\#(product.name)", package: "\#(packageToAdd.name)""#)
    }

    func addPackageToDependenciesArray(call: inout FunctionCallExprSyntax) {
        guard var (_, dependencies) = call.findArgument(name: "dependencies", as: ArrayExprSyntax.self) else {
            // TODO: add dependencies section
            return
        }

        let package = makePackageDependency()
        guard !dependencies.containsPackage(self.packageToAdd) else { return }

        dependencies.ensuresTrailingCommaOnLastElement()
        let leading = Trivia.newline.appending(TriviaPiece.spaces(8))
        let element = ArrayElementSyntax(leadingTrivia: leading, expression: package)
        dependencies.elements.append(element)
        dependencies.leadingTrivia = .space

        call.arguments.replaceArgument(name: "dependencies", expression: dependencies)
    }

    func makePackageDependency() -> FunctionCallExprSyntax {
        // .package(name: "...", url: "...", from: "...")
        let version = packageToAdd.versions.last ?? "0.0.1"
        return FunctionCallExprSyntax(
            ExprSyntax(stringLiteral: #".package(name: "\#(packageToAdd.name)", url: "\#(packageToAdd.url)", from: "\#(version)")"#)
        )!
    }
}


extension ArrayExprSyntax {
    func containsPackage(_ packageInfo: PackageInfo) -> Bool {
        for el in elements {
            guard let fn = el.expression.as(FunctionCallExprSyntax.self) else { continue }
            guard fn.calledExpression.as(MemberAccessExprSyntax.self)!.declName.baseName.text == "package" else { return false }
            guard let url = fn.getStringArgumentValue(name: "url") else { return false }
            return url == packageInfo.url.absoluteString
        }
        return false
    }
}
