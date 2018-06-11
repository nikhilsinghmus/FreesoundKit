//
//  DataStorageManager.swift
//  FreesoundKit
//
//  Copyright © 2018 Nikhil Singh. All rights reserved.
//

import UIKit

/**
 **DataStorageManager** is an abstract class that manages persistent storage of user data.
 */
open class DataStorageManager {
    private init() { } // Abstract class
    
    static fileprivate let storeQueue = DispatchQueue(label: "storage")
    static fileprivate let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    static fileprivate let plistURL = docsURL.appendingPathComponent("FreesoundData.plist")
    static fileprivate var data: NSMutableDictionary = NSMutableDictionary(contentsOf: plistURL) ?? NSMutableDictionary()
    
    /// Set dictionary key-value pair.
    static public func set(_ value: Any?, forKey key: String) {
        if (!FileManager.default.fileExists(atPath: plistURL.path)) {
            createPlist(plistURL)
        }
        
        data.setValue(value, forKey: key)
        try? data.write(to: plistURL)
    }
    
    /// Get object corresponding to a key.
    static public func object(forKey: String) -> Any? {
        if (!FileManager.default.fileExists(atPath: plistURL.path)) {
            createPlist(plistURL)
        }
        
        return data.value(forKey: forKey)
    }
    
    /// Get Bool corresponding to a key.
    static public func bool(forKey: String) -> Bool? {
        if (!FileManager.default.fileExists(atPath: plistURL.path)) {
            createPlist(plistURL)
        }
        
        return data.value(forKey: forKey) as? Bool
    }
    
    static fileprivate func createPlist(_ url: URL) {
        FileManager.default.createFile(atPath: plistURL.path, contents: nil, attributes: nil)
    }
}
