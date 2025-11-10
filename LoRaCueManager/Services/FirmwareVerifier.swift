import CryptoKit
import Foundation

class FirmwareVerifier {
    private static let publicKeyPEM = """
    -----BEGIN PUBLIC KEY-----
    MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAtTdjvDKnLv8DNjQ+xqQ4
    Vq7fArurL3ISRHnYfALeeS4tPF8GO2yP36tc/RCe0UkG1IN9LZNmEKOFdDn3W6Cm
    wJR2W/JpERdozsel2yJvVKkePapFepbfDd2LiwmUBM68QH/2tjCxAWICHFu+TVvm
    Hvow6UC8n6v43ALczajE6TFaTqRQCY5dBeJi5bMyuYz1NtMz3qj9rjHkDED/jcyX
    P797mjWbVgGbvZPc56MYrB7BgkOalt5k+0dAxavFUS9xVJfhmpXligCCVMCzc9/X
    vyFjUidSYMQNbiqGlgbh3GtPp58Zd9Ynv/4l6s/W2fsqhSdYyI1iTQwWdzvzrJzd
    1ST7VnyFgFOYGL1h0LOlVfccv6WO6cR/5o00G3xFA5fjUatAj29UJ+YndhVBhf5h
    ZQ0eB/KocNRh19tLUcVdmzNRSFQSCOYpIt+b6tB9oh4SzWfzXVQdBKPAHTdB5WWh
    AHBd7cNhSIlBHgahA1ZD1FY012JJTx0ZxG+17rrdZY/R+aOoGgec0PkpUqg70Rnu
    TXAUd55S0bJouFQUFUOqd4Bx6PjPXE08eg5mHal0pPJ5T5+3IkyF9lIuSZBysL3e
    UVbB/uWy6+ZQzj1tL4fVMxiHBzN9Jy6kUQJr0V80CKpnbRzkTZ94qiiVu2v0z9CL
    QfgIqpuSnXdpOyMI9FggbT0CAwEAAQ==
    -----END PUBLIC KEY-----
    """

    // MARK: - SHA256 Verification

    func verifySHA256(data: Data, expectedHash: String) -> VerificationResult {
        let hash = SHA256.hash(data: data)
        let actualHash = hash.compactMap { String(format: "%02x", $0) }.joined()

        if actualHash.lowercased() == expectedHash.lowercased() {
            return .success
        } else {
            return .hashMismatch(expected: expectedHash, actual: actualHash)
        }
    }

    // MARK: - RSA Signature Verification

    /// Verify binary file signature (signs raw file data)
    func verifyBinarySignature(fileUrl: URL, signatureUrl: URL) -> VerificationResult {
        do {
            let fileData = try Data(contentsOf: fileUrl)

            let signatureString = try String(contentsOf: signatureUrl, encoding: .utf8)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard let signatureData = Data(base64Encoded: signatureString) else {
                return .signatureInvalid
            }

            let publicKey = try parsePublicKey(Self.publicKeyPEM)
            let isValid = try verifyRSASignature(data: hashData, signature: signatureData, publicKey: publicKey)
            return isValid ? .success : .signatureInvalid
        } catch {
            return .error(error)
        }
    }

    /// Verify JSON file signature (signs raw UTF-8 bytes)
    func verifyJSONSignature(fileUrl: URL, signatureUrl: URL) -> VerificationResult {
        do {
            let jsonData = try Data(contentsOf: fileUrl)

            let signatureString = try String(contentsOf: signatureUrl, encoding: .utf8)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard let signatureData = Data(base64Encoded: signatureString) else {
                return .signatureInvalid
            }

            let publicKey = try parsePublicKey(Self.publicKeyPEM)
            let isValid = try verifyRSASignature(data: jsonData, signature: signatureData, publicKey: publicKey)
            return isValid ? .success : .signatureInvalid
        } catch {
            return .error(error)
        }
    }

    // MARK: - Private Helpers

    private func parsePublicKey(_ pem: String) throws -> SecKey {
        let pemStripped = pem
            .replacingOccurrences(of: "-----BEGIN PUBLIC KEY-----", with: "")
            .replacingOccurrences(of: "-----END PUBLIC KEY-----", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")

        guard let keyData = Data(base64Encoded: pemStripped) else {
            throw VerificationError.invalidPublicKey
        }

        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass as String: kSecAttrKeyClassPublic,
            kSecAttrKeySizeInBits as String: 4096
        ]

        var error: Unmanaged<CFError>?
        guard let key = SecKeyCreateWithData(keyData as CFData, attributes as CFDictionary, &error) else {
            throw error?.takeRetainedValue() ?? VerificationError.invalidPublicKey
        }

        return key
    }

    private func verifyRSASignature(data: Data, signature: Data, publicKey: SecKey) throws -> Bool {
        var error: Unmanaged<CFError>?
        let result = SecKeyVerifySignature(
            publicKey,
            .rsaSignatureMessagePKCS1v15SHA256,
            data as CFData,
            signature as CFData,
            &error
        )

        if let error {
            throw error.takeRetainedValue()
        }

        return result
    }
}

// MARK: - Errors

enum VerificationError: LocalizedError {
    case invalidPublicKey
    case invalidSignature

    var errorDescription: String? {
        switch self {
        case .invalidPublicKey:
            "Invalid public key format"
        case .invalidSignature:
            "Invalid signature format"
        }
    }
}
