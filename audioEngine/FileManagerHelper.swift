//
//  FileManagerHelper.swift
//  audioEngine
//
//  Created by Maysam Shahsavari on 2022-06-21.
//

import Foundation
struct FileManagerHelper {
    static let filename = "audio.wav"

    static func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
    
    static func getFileURL(for fileName: String) -> URL {
        let path = getDocumentsDirectory().appendingPathComponent(fileName)
        return path as URL
    }
}
