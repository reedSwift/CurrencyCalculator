import UIKit

/// Base protocol every coordinator conforms to.
///
/// A coordinator owns a slice of the navigation stack and decides what to show.
/// It never contains view or business logic — that belongs in ViewControllers and
/// ViewModels respectively.
///
/// Lifetime rule: a coordinator must be retained by its parent (or SceneDelegate
/// for the root). ARC will deallocate it and its entire sub-tree when the parent
/// is done with it.
@MainActor
protocol Coordinator: AnyObject {
    /// Build and present the initial UI for this coordinator's flow.
    func start()
}
