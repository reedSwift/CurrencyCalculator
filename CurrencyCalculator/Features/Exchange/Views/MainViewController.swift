import UIKit
import SwiftUI
import Combine

final class MainViewController: UIViewController {

    private let viewModel: ExchangeViewModel
    private var cancellables = Set<AnyCancellable>()

    init(viewModel: ExchangeViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        embedExchangeCard()
        observePickerRequest()
        setupKeyboardDismissal()
    }

    // MARK: - Setup

    private func embedExchangeCard() {
        let cardView = ExchangeCardView(viewModel: viewModel)
        let host = UIHostingController(rootView: cardView)
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        host.didMove(toParent: self)
    }

    private func observePickerRequest() {
        viewModel.showPickerPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.presentCurrencyPicker() }
            .store(in: &cancellables)
    }

    // Dismiss keyboard when the user taps anywhere that isn't a text field.
    // cancelsTouchesInView = false ensures the tap still reaches the tapped view
    // (e.g. a TextField), so this never blocks focus acquisition.
    private func setupKeyboardDismissal() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleBackgroundTap(_:)))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    @objc private func handleBackgroundTap(_ recognizer: UITapGestureRecognizer) {
        let point = recognizer.location(in: view)
        guard let hit = view.hitTest(point, with: nil), !(hit is UITextField) else { return }
        view.endEditing(true)
    }

    // MARK: - Sheet presentation

    private func presentCurrencyPicker() {
        let pickerVC = CurrencyPickerViewController(viewModel: viewModel)
        if let sheet = pickerVC.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 24
            sheet.prefersScrollingExpandsWhenScrolledToEdge = false
        }
        present(pickerVC, animated: true)
    }
}
