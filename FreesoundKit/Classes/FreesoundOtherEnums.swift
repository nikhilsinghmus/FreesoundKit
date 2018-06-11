//
//  FreesoundLicense.swift
//  FreesoundKit
//
//  Copyright © 2018 Nikhil Singh. All rights reserved.
//

import Foundation

/// The type of license to use.
public enum FreesoundLicense: String {
    case attribution = "Attribution",
    attributionNoncommercial = "Attribution Noncommercial",
    creativeCommons0 = "Creative Commons 0"
}

/// Success or failure result.
public enum FreesoundResult {
    case success, failure
}

/// Quality for sound previews.
public enum FreesoundPreviewQuality: String {
    case low = "preview-lq-mp3", high = "preview-hq-mp3"
}
