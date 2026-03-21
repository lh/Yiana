import Foundation
import CYianaTypstBridge

public enum TypstError: Error, LocalizedError {
    case compilationFailed(String)
    case invalidTemplate
    case unknown

    public var errorDescription: String? {
        switch self {
        case .compilationFailed(let message): return message
        case .invalidTemplate: return "Invalid Typst template"
        case .unknown: return "Unknown Typst error"
        }
    }
}

enum TypstBridge {
    /// Compile a Typst template with JSON inputs, returning PDF data.
    static func compile(template: Data, inputs: [String: Any]) throws -> Data {
        let inputsData = try JSONSerialization.data(withJSONObject: inputs)

        return try template.withUnsafeBytes { templateBuffer in
            try inputsData.withUnsafeBytes { inputsBuffer in
                guard let templatePtr = templateBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self),
                      let inputsPtr = inputsBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self)
                else {
                    throw TypstError.invalidTemplate
                }

                var pdfPtr: UnsafeMutablePointer<UInt8>?
                var pdfLen: UInt = 0
                var errPtr: UnsafeMutablePointer<UInt8>?
                var errLen: UInt = 0

                let result = typst_compile_to_pdf(
                    templatePtr, UInt(templateBuffer.count),
                    inputsPtr, UInt(inputsBuffer.count),
                    &pdfPtr, &pdfLen,
                    &errPtr, &errLen
                )

                if result != 0 {
                    let message: String
                    if let errPtr, errLen > 0 {
                        message = String(
                            bytesNoCopy: errPtr,
                            length: Int(errLen),
                            encoding: .utf8,
                            freeWhenDone: false
                        ) ?? "Unknown error"
                        typst_free_buffer(errPtr, errLen)
                    } else {
                        message = "Unknown compilation error"
                    }
                    throw TypstError.compilationFailed(message)
                }

                guard let pdfPtr, pdfLen > 0 else {
                    throw TypstError.unknown
                }

                let pdfData = Data(bytes: pdfPtr, count: Int(pdfLen))
                typst_free_buffer(pdfPtr, pdfLen)
                return pdfData
            }
        }
    }
}
