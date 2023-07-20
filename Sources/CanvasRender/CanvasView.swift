import Foundation
import simd
import SwiftUI

public struct CanvasView<StateType: ObservableObject>: View {
    private let maker: any ShapeMaker<StateType>
    @ObservedObject private var state: StateType

    public init(@ObservedObject state: StateType, maker: any ShapeMaker<StateType>) {
        self.maker = maker
        self.state = state
    }

    public var body: some View {
        CanvasRenderer(state: state,
                       maker: maker)
    }
}

public protocol ShapeMaker<StateType> {
    associatedtype StateType: ObservableObject
    @CanvasBuilder
    func shapes(from state: StateType) -> [any DrawableShape]
}
