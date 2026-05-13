import Foundation

/// Intercepts `URLSession` requests in tests so `ExchangeRateService` can be
/// exercised without hitting a real network. Register it via an ephemeral
/// `URLSessionConfiguration`:
///
///     let config = URLSessionConfiguration.ephemeral
///     config.protocolClasses = [MockURLProtocol.self]
///     let session = URLSession(configuration: config)
///
/// Then set `MockURLProtocol.requestHandler` before each test.
final class MockURLProtocol: URLProtocol {

    /// Set this in each test to control what the mock returns.
    /// Throw to simulate a network error; return `(response, data)` for success.
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
