import SwiftUI
import Razorpay

// MARK: - Razorpay Test Key
// TODO: Replace with your actual test key from https://dashboard.razorpay.com/app/keys
private let kRazorpayTestKey = "rzp_test_SUAB0mTWqbFbXu"

// MARK: - Payment Result
enum RazorpayPaymentResult {
    case success(paymentId: String)
    case failure(code: Int32, description: String)
}

// MARK: - Payment Options Builder
struct RazorpayOptions {
    let amountInPaise: Int      // Always in paise: ₹500 = 50000
    let description: String
    let prefillName: String
    let prefillEmail: String
    let prefillContact: String

    /// Returns the [String: Any] options dict that Razorpay.open() expects
    func toDictionary() -> [String: Any] {
        return [
            "amount": amountInPaise,
            "currency": "INR",
            "name": "HMS",
            "description": description,
            "prefill": [
                "name": prefillName,
                "email": prefillEmail,
                "contact": prefillContact
            ],
            "theme": ["color": "#4F7EFF"]
        ]
    }
}

// MARK: - Coordinator (Razorpay Delegate)
/// Conforms to RazorpayPaymentCompletionProtocolWithData to handle callbacks.
class RazorpayCoordinator: NSObject, RazorpayPaymentCompletionProtocolWithData {

    var razorpay: RazorpayCheckout?
    var completion: ((RazorpayPaymentResult) -> Void)?
    var hasOpened = false

    func reset() {
        razorpay = nil
        completion = nil
        hasOpened = false
    }

    func onPaymentSuccess(_ payment_id: String, andData response: [AnyHashable: Any]?) {
        DispatchQueue.main.async { [weak self] in
            self?.completion?(.success(paymentId: payment_id))
        }
    }

    func onPaymentError(_ code: Int32, description str: String, andData response: [AnyHashable: Any]?) {
        DispatchQueue.main.async { [weak self] in
            self?.completion?(.failure(code: code, description: str))
        }
    }
}

// MARK: - UIViewControllerRepresentable Bridge
/// Embed this in a .background or .sheet to trigger the Razorpay checkout.
struct RazorpayCheckoutView: UIViewControllerRepresentable {

    let options: RazorpayOptions
    let onResult: (RazorpayPaymentResult) -> Void

    func makeCoordinator() -> RazorpayCoordinator {
        return RazorpayCoordinator()
    }

    func makeUIViewController(context: Context) -> UIViewController {
        let vc = UIViewController()
        vc.view.backgroundColor = .clear
        return vc
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // Open the Razorpay checkout only once per sheet presentation
        guard !context.coordinator.hasOpened else { return }
        context.coordinator.hasOpened = true

        let coordinator = context.coordinator
        coordinator.completion = onResult

        let razorpay = RazorpayCheckout.initWithKey(
            kRazorpayTestKey,
            andDelegateWithData: coordinator
        )
        coordinator.razorpay = razorpay

        // Slight delay ensures the UIViewController is fully in the hierarchy
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            razorpay.open(options.toDictionary(), displayController: uiViewController)
        }
    }
}

// MARK: - SwiftUI Convenience Modifier
/// Add .razorpaySheet(...) to any view to present the payment checkout.
extension View {
    func razorpaySheet(
        isPresented: Binding<Bool>,
        options: RazorpayOptions,
        onResult: @escaping (RazorpayPaymentResult) -> Void
    ) -> some View {
        self.sheet(isPresented: isPresented) {
            RazorpayCheckoutView(options: options, onResult: { result in
                isPresented.wrappedValue = false
                onResult(result)
            })
            .presentationDetents([.large])
            .interactiveDismissDisabled(true)
        }
    }
}
