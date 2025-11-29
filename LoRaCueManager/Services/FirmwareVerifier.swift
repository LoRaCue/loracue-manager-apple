import CryptoKit
import Foundation

class FirmwareVerifier {
    private static let publicKeyPEM = """
    -----BEGIN PUBLIC KEY-----
    MCowBQYDK2VwAyEAo8F7VxGLhVKZqBxCQvJ5xKp0YvLqH8vN2wZ3jR4mTkI=
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

    // MARK: - Ed25519 Signature Verification

    /// Verify binary file signature (signs SHA256 hash)
    func verifyBinarySignature(fileUrl: URL, signatureUrl: URL) -> VerificationResult {
        do {
            let fileData = try Data(contentsOf: fileUrl)
            let hashData = SHA256.hash(data: fileData)
            let hashDataBytes = Data(hashData)

            let signatureString = try String(contentsOf: signatureUrl, encoding: .utf8)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            // Binary signatures are now Hex-encoded
            guard let signatureData = Data(hexString: signatureString) else {
                return .signatureInvalid
            }

            let publicKey = try parseEd25519PublicKey(Self.publicKeyPEM)
            let isValid = try verifyEd25519Signature(
                data: hashDataBytes,
                signature: signatureData,
                publicKey: publicKey
            )
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

            // JSON signatures remain Base64-encoded
            guard let signatureData = Data(base64Encoded: signatureString) else {
                return .signatureInvalid
            }

            let publicKey = try parseEd25519PublicKey(Self.publicKeyPEM)
            let isValid = try verifyEd25519Signature(
                data: jsonData,
                signature: signatureData,
                publicKey: publicKey
            )
            return isValid ? .success : .signatureInvalid
        } catch {
            return .error(error)
        }
    }

    // MARK: - Private Helpers

    private func parseEd25519PublicKey(_ pem: String) throws -> Curve25519.Signing.PublicKey {
        let pemStripped = pem
            .replacingOccurrences(of: "-----BEGIN PUBLIC KEY-----", with: "")
            .replacingOccurrences(of: "-----END PUBLIC KEY-----", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")

        guard let keyData = Data(base64Encoded: pemStripped) else {
            throw VerificationError.invalidPublicKey
        }

        // Ed25519 keys in PEM format (SubjectPublicKeyInfo) are wrapped.
        // The raw key is the last 32 bytes.
        // OID for Ed25519 is 1.3.101.112
        // Sequence: 30 2a
        //   AlgorithmIdentifier: 30 05 06 03 2b 65 70
        //   BitString: 03 21 00 [32 bytes of key]
        // Total length is 44 bytes.

        // Simple heuristic: if it's 32 bytes, use it directly.
        // If it's longer (likely 44 bytes for full DER), extract the last 32 bytes.

        let rawKeyData: Data
        if keyData.count == 32 {
            rawKeyData = keyData
        } else if keyData.count > 32 {
            rawKeyData = keyData.suffix(32)
        } else {
            throw VerificationError.invalidPublicKey
        }

        return try Curve25519.Signing.PublicKey(rawRepresentation: rawKeyData)
    }

    private func verifyEd25519Signature(
        data: Data,
        signature: Data,
        publicKey: Curve25519.Signing.PublicKey
    ) throws -> Bool {
        publicKey.isValidSignature(signature, for: data)
    }
}

// MARK: - Extensions

extension Data {
    fileprivate init?(hexString: String) {
        let length = hexString.count / 2
        var data = Data(capacity: length)
        var currentIndex = hexString.startIndex
        for _ in 0 ..< length {
            let nextIndex = hexString.index(currentIndex, offsetBy: 2)
            let bytes = hexString[currentIndex ..< nextIndex]
            if let num = UInt8(bytes, radix: 16) {
                data.append(num)
            } else {
                return nil
            }
            currentIndex = nextIndex
        }
        self = data
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
