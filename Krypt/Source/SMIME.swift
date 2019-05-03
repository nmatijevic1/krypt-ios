//
//  SMIME.swift
//  Krypt
//
//  Created by marko on 11.04.19.
//

import Foundation
import Krypt_internal

public struct SMIME {
  /// Decrypts encrypted SMIME content using private key
  ///
  /// - Parameters:
  ///   - data: encrypted SMIME content
  ///   - key: private key
  /// - Returns: Decrypted SMIME content
  /// - Throws: In case of any error
  public static func decrypt(data: Data, key: Key) throws -> Data {
    guard key.access == .private,
      let keyPEM = try? key.convertedToPEM().unsafeUtf8cString else {
      throw SMIMEError.error
    }
    
    guard let dataString = data.unsafeUtf8cString else {
        throw SMIMEError.error
    }
    
    guard let decryptedString = smime_decrypt(dataString, keyPEM),
      let decryptedData = decryptedString.data else {
      throw SMIMEError.error
    }

    return decryptedData
  }
  
  /// Verifies the decrypted SMIME content signature against trusted CA certificates. The certificate chain needs to be complete for verification to succeed.
  ///
  /// - Parameters:
  ///   - data: SMIME content
  ///   - certificates: collection of CA certificates to trust
  /// - Returns: Decrypted SMIME content without signature
  /// - Throws: In case of any error.
  public static func verify(data: Data, certificates: [Data]) throws -> Data {
    guard let dataString = data.unsafeUtf8cString else {
      throw SMIMEError.error
    }
    
    let certificateStrings = certificates.map { String(decoding: $0, as: UTF8.self) }
    var certificateCStrings = certificateStrings.cStringsByCoping
    
    var contentWithoutSignature: UnsafeMutablePointer<Int8>?
    
    guard smime_verify(dataString, &certificateCStrings, Int32(certificateCStrings.count), &contentWithoutSignature) == 1 else {
      throw SMIMEError.error
    }
    
    guard let content = contentWithoutSignature?.data else {
      throw SMIMEError.error
    }
    
    certificateCStrings.freePointers()
    contentWithoutSignature?.deallocate()

    return content
  }
}

private extension Data {
  var unsafeUtf8cString: [CChar]? {
    return String(data: self, encoding: .utf8)?.unsafeUtf8cString
  }
}

private extension UnsafeMutablePointer where Pointee == Int8 {
  var data: Data? {
    return String(cString: self).data(using: .utf8)
  }
}

private extension Collection where Element == String {
  var cStringsByCoping: [UnsafePointer<Int8>?] {
    return map { UnsafePointer<Int8>(strdup($0)) }
  }
}

private extension Collection where Element == UnsafePointer<Int8>? {
  func freePointers() {
    forEach { free(UnsafeMutablePointer(mutating: $0)) }
  }
}

enum SMIMEError: Error {
  case error
}