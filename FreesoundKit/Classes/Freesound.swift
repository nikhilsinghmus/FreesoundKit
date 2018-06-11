//
//  Freesound.swift
//  HiddenSounds
//
//  Copyright © 2018 Nikhil Singh. All rights reserved.
//

import UIKit
import Alamofire
import CoreLocation

public typealias FreesoundHandler = ([String: Any]?) -> ()

/**
 **Freesound** is an abstract class that manages interactions with the Freesound API.
 */
open class Freesound {
    private init() { } // Abstract class
    
    // MARK: URL components
    static fileprivate let BASE = "https://www.freesound.org/apiv2"
    static fileprivate let TEXT_SEARCH = "/search/text/"
    static fileprivate let CONTENT_SEARCH = "/search/content/"
    static fileprivate let COMBINED_SEARCH = "/search/combined/"
    static fileprivate let SOUND = "/sounds/<sound_id>/"
    static fileprivate let SOUND_ANALYSIS = "/sounds/<sound_id>/analysis/"
    static fileprivate let SIMILAR_SOUNDS = "/sounds/<sound_id>/similar/"
    static fileprivate let COMMENTS = "/sounds/<sound_id>/comments/"
    static fileprivate let DOWNLOAD = "/sounds/<sound_id>/download/"
    static fileprivate let UPLOAD = "/sounds/upload/"
    static fileprivate let DESCRIBE = "/sounds/describe/"
    static fileprivate let PENDING = "/sounds/pending_uploads/"
    static fileprivate let BOOKMARK = "/sounds/<sound_id>/bookmark/"
    static fileprivate let RATE = "/sounds/<sound_id>/rate/"
    static fileprivate let COMMENT = "/sounds/<sound_id>/comment/"
    static fileprivate let AUTHORIZE = "/oauth2/authorize/"
    static fileprivate let LOGOUT = "/api-auth/logout/"
    static fileprivate let LOGOUT_AUTHORIZE = "/oauth2/logout_and_authorize/"
    static fileprivate let ME = "/me/"
    static fileprivate let USER = "/users/<username>/"
    static fileprivate let USER_SOUNDS = "/users/<username>/sounds/"
    static fileprivate let USER_PACKS = "/users/<username>/packs/"
    static fileprivate let USER_BOOKMARK_CATEGORIES = "/users/<username>/bookmark_categories/"
    static fileprivate let USER_BOOKMARK_CATEGORY_SOUNDS = "/users/<username>/bookmark_categories/<bookmark_category_id>/sounds/"
    static fileprivate let PACK = "/packs/<pack_id>/"
    static fileprivate let PACK_SOUNDS = "/packs/<pack_id>/sounds/"
    static fileprivate let PACK_DOWNLOAD = "/packs/<pack_id>/download/"
    static fileprivate let ACCESS = "/oauth2/access_token/"
    static fileprivate let EDIT_DESCRIPTION = "/apiv2/sounds/<sound_id>/edit/"
    
    // MARK: Authorization information
    static fileprivate var CLIENT_ID: String?
    static fileprivate var CLIENT_SECRET: String?
    static fileprivate var ACCESS_TOKEN: String? {
        set {
            DataStorageManager.set(newValue, forKey: "access_token")
        }
        
        get {
            return DataStorageManager.object(forKey: "access_token") as? String
        }
    }
    static fileprivate var REFRESH_TOKEN: String? {
        set {
            DataStorageManager.set(newValue, forKey: "refresh_token")
        }
        
        get {
            return DataStorageManager.object(forKey: "refresh_token") as? String
        }
    }
    static fileprivate var headers: HTTPHeaders? {
        set {
            DataStorageManager.set(newValue, forKey: "http_headers")
        }
        
        get {
            return DataStorageManager.object(forKey: "http_headers") as? HTTPHeaders
        }
    }
    
    /// Returns whether or not the current app is authorized to use Freesound.
    static public var isAuthorized: Bool {
        set {
            DataStorageManager.set(newValue, forKey: "isAuthorized")
        }
        
        get {
            return DataStorageManager.bool(forKey: "isAuthorized") ?? false
        }
    }
    
    // MARK: API methods
    /// Stores client information to later communicate with API.
    static public func setup(with clientID: String, clientSecret: String) {
        CLIENT_ID = clientID
        CLIENT_SECRET = clientSecret
    }
    
    /// Authorizes client via OAuth2 and retrieves access token.
    static public func authorize(handler: @escaping () -> ()) {
        if let id = CLIENT_ID {
            openURL(from: BASE + AUTHORIZE + "?client_id=\(id)&response_type=code&state=freesoundkit", handler: handler)
        }
    }
    
    /// Refreshes authorization, retrieves new access and refresh tokens.
    static public func refresh() {
        if let id = CLIENT_ID, let secret = CLIENT_SECRET, let refresh = REFRESH_TOKEN {
            Alamofire.request(BASE + ACCESS + "?client_id=\(id)&client_secret=\(secret)&grant_type=refresh_token&refresh_token=\(refresh)").responseJSON(completionHandler: { response in
                
                if let dict = response.result.value as? [String: String] {
                    ACCESS_TOKEN = dict["access_token"]
                    REFRESH_TOKEN = dict["refresh_token"]
                }
                
                if let token = ACCESS_TOKEN {
                    headers = ["Authorization": "Bearer \(token)"]
                }
            })
        }
    }
    
    /// Handles the temporary authorization code generated by Freesound.
    @discardableResult
    static public func handleCode(_ code: String?) -> FreesoundResult {
        let queue = DispatchQueue(label: "handleCode")
        
        guard let code = code,
            let id = CLIENT_ID,
            let secret = CLIENT_SECRET else { return .failure }
        
        Alamofire.request(BASE + ACCESS + "?client_id=\(id)&client_secret=\(secret)&grant_type=authorization_code&code=\(code)", method: .post).responseJSON { response in
            print(response.result)
            if let dict = response.result.value as? [String: Any] {
                ACCESS_TOKEN = dict["access_token"] as? String
                REFRESH_TOKEN = dict["refresh_token"] as? String
                isAuthorized = true
                
                if let token = ACCESS_TOKEN {
                    headers = ["Authorization": "Bearer \(token)"]
                }
            }
        }
        
        if isAuthorized {
            return .success
        }
        
        return .failure
    }
    
    /// Text search.
    static public func search(_ text: String,
                              page: Int? = nil,
                              pageSize: Int? = nil,
                              handler: @escaping FreesoundHandler) {
        let urlString = BASE + TEXT_SEARCH
        var parameters: [String: Any] = [:]
        parameters["query"] = text
        parameters["page"] = page
        parameters["page_size"] = pageSize
        
        requestWithHeaders(urlString, parameters: parameters, handler: { response in
            let sounds = response.result.value as? [String: Any]
            handler(sounds)
        })
    }
    
    /// Content search.
    static public func contentSearch(_ target: String,
                                     page: Int? = nil,
                                     pageSize: Int? = nil,
                                     handler: @escaping FreesoundHandler) {
        let urlString = BASE + CONTENT_SEARCH
        var parameters: [String: Any] = [:]
        parameters["query"] = target
        parameters["page"] = page
        parameters["page_size"] = pageSize
        
        requestWithHeaders(urlString, parameters: parameters, handler: { response in
            let sounds = response.result.value as? [String: Any]
            handler(sounds)
        })
    }
    
    /// Downloads a sound file to a specified URL.
    static public func download(_ id: String,
                                to url: URL,
                                handler: @escaping (URL?) -> ()) {
        let urlString = (BASE + DOWNLOAD).replacingOccurrences(of: "<sound_id>", with: "id")
        let destination: DownloadRequest.DownloadFileDestination = { _, _ in
            return (url, [.removePreviousFile, .createIntermediateDirectories])
        }
        if let httpHeaders = headers {
            Alamofire.download(urlString, headers: httpHeaders, to: destination).response { response in
                let url = response.destinationURL
                handler(url)
            }
        }
    }
    
    /// Uploads a sound file to Freesound.
    static public func upload(_ url: URL,
                              name: String = "",
                              description: String = "",
                              pack: String?,
                              license: FreesoundLicense,
                              geoTag: Bool = false,
                              handler: @escaping FreesoundHandler) {
        var uploadUrlString = (BASE + UPLOAD).appending("?name=\(name)&description=\(description)&license=\(license.rawValue)")
        if let packName = pack {
            uploadUrlString.append("&pack=\(packName)")
        }
        
        if geoTag, let geoTagString = getGeoTagString() {
            uploadUrlString.append(geoTagString)
        }
        
        guard let uploadUrlStringEncoded = uploadUrlString.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) else { return }
        
        if let httpHeaders = headers {
            Alamofire.upload(url, to: uploadUrlStringEncoded, headers: httpHeaders).responseJSON { response in
                let responseData = response.result.value as? [String: Any]
                handler(responseData)
            }
        }
    }
    
    /// Describes an upload-pending sound.
    static public func describeSound(_ uploadFilename: String,
                                     name: String?, tags: String,
                                     description: String,
                                     license: FreesoundLicense,
                                     pack: String?,
                                     geoTag: Bool = false,
                                     handler: @escaping FreesoundHandler) {
        let urlString = BASE + DESCRIBE
        
        var parameters: [String: Any] = [:]
        parameters["upload_filename"] = uploadFilename
        parameters["name"] = name
        parameters["tags"] = tags
        parameters["description"] = description
        parameters["license"] = license.rawValue
        parameters["pack"] = pack
        
        if geoTag {
            parameters["geotag"] = getGeoTagString()
        }
        
        requestWithHeaders(urlString, method: .post, parameters: parameters, handler: { response in
            if let responseData = response.result.value as? [String: Any] {
                handler(responseData)
            }
        })
    }
    
    /// Edits an existing sound file's description on Freesound.
    static public func editSoundDescription(_ id: String,
                                            name: String?,
                                            tags: String,
                                            description: String,
                                            license: FreesoundLicense,
                                            pack: String?,
                                            geoTag: Bool = false,
                                            handler: @escaping FreesoundHandler) {
        let urlString = (BASE + EDIT_DESCRIPTION).replacingOccurrences(of: "<sound_id>", with: id)
        
        var parameters: [String: Any] = [:]
        parameters["name"] = name
        parameters["tags"] = tags
        parameters["description"] = description
        parameters["license"] = license.rawValue
        parameters["pack"] = pack
        
        if geoTag {
            parameters["geotag"] = getGeoTagString()
        }
        
        requestWithHeaders(urlString,
                           method: .post,
                           parameters: parameters,
                           handler: { response in
            if let responseData = response.result.value as? [String: Any] {
                handler(responseData)
            }
        })
    }
    
    /// Retrieves a dictionary of pending uploads.
    static public func getPendingUploads(handler: @escaping FreesoundHandler) {
        let urlString = BASE + PENDING
        requestWithHeaders(urlString, handler: { response in
            let pendingUploads = response.result.value as? [String: Any]
            handler(pendingUploads)
        })
    }
    
    /// Bookmarks a sound for the logged in user.
    static public func bookmarkSound(_ id: String,
                              name: String? = nil,
                              category: String? = nil,
                              handler: @escaping FreesoundHandler) {
        let urlString = (BASE + BOOKMARK).replacingOccurrences(of: "<sound_id>", with: id)
        var parameters: [String: Any] = [:]
        parameters["name"] = name
        parameters["category"] = category
        requestWithHeaders(urlString, method: .post, parameters: parameters, handler: { response in
            let responseData = response.result.value as? [String: Any]
            handler(responseData)
        })
    }
    
    /// Rates a sound for the logged in user (rating range is 0-5).
    static public func rateSound(_ id: String,
                                 rating: Int,
                                 handler: @escaping FreesoundHandler) {
        let urlString = (BASE + RATE).replacingOccurrences(of: "<sound_id>", with: id)
        let parameters: [String: Any] = ["rating": max(0, min(5, rating))]
        requestWithHeaders(urlString, method: .post, parameters: parameters, handler: { response in
            let responseData = response.result.value as? [String: Any]
            handler(responseData)
        })
    }
    
    /// Add a comment to a sound on Freesound.
    static public func commentSound(_ id: String,
                                    comment: String,
                                    handler: @escaping FreesoundHandler) {
        let urlString = (BASE + COMMENT).replacingOccurrences(of: "<sound_id>", with: id)
        let parameters: [String: Any] = ["comment": comment]
        requestWithHeaders(urlString, method: .post, parameters: parameters, handler: { response in
            let responseDict = response.result.value as? [String: Any]
            handler(responseDict)
        })
    }
    
    /// Gets preview audio for a sound.
    static public func getPreview(_ id: String,
                                  to url: URL,
                                  quality: FreesoundPreviewQuality,
                                  handler: @escaping (URL?) -> ()) {
        let urlString = (BASE + SOUND).replacingOccurrences(of: "<sound_id>", with: id)
        requestWithHeaders(urlString, handler: { response in
            guard let dict = response.result.value as? [String: Any] else { return }
            guard let previewUrlString = (dict["previews"] as! [String: Any])[quality.rawValue] as? String else { return }
            
            let destination: DownloadRequest.DownloadFileDestination = { _, _ in
                return (url, [.removePreviousFile, .createIntermediateDirectories])
            }
            Alamofire.download(previewUrlString, to: destination).response { response in
                let url = response.destinationURL
                handler(url)
            }
        })
    }
    
    /// Gets preview URL for a sound.
    static public func getPreviewURL(_ id: String,
                                     quality: FreesoundPreviewQuality,
                                     handler: @escaping (URL?) -> ()) {
        let urlString = (BASE + SOUND).replacingOccurrences(of: "<sound_id>", with: id)
        requestWithHeaders(urlString, handler: { response in
            guard let dict = response.result.value as? [String: Any] else { return }
            guard let previewUrlString = (dict["previews"] as! [String: Any])[quality.rawValue] as? String else { return }
            handler(URL(string: previewUrlString))
        })
    }
    
    /// Retrieves a user instance.
    static public func getUserInstance(_ username: String,
                                       handler: @escaping FreesoundHandler) {
        let urlString = (BASE + USER).replacingOccurrences(of: "<username>", with: username)
        requestWithHeaders(urlString, handler: { response in
            let userData = response.result.value as? [String: Any]
            handler(userData)
        })
    }
    
    /// Retrieves a user's sounds.
    static public func getUserSounds(_ username: String,
                                     page: Int? = nil,
                                     pageSize: Int? = nil,
                                     handler: @escaping FreesoundHandler) {
        let urlString = (BASE + USER_SOUNDS).replacingOccurrences(of: "<username>", with: username)
        getPaginatedList(urlString, page: page, pageSize: pageSize, handler: handler)
    }
    
    /// Retrieves a user's packs.
    static public func getUserPacks(_ username: String,
                                    page: Int? = nil,
                                    pageSize: Int? = nil,
                                    handler: @escaping FreesoundHandler) {
        let urlString = (BASE + USER_PACKS).replacingOccurrences(of: "<username>", with: username)
        getPaginatedList(urlString, page: page, pageSize: pageSize, handler: handler)
    }
    
    /// Retrieves a user's sound bookmark categories.
    static public func getUserBookmarkCategories(_ username: String,
                                                 page: Int? = nil,
                                                 pageSize: Int? = nil,
                                                 handler: @escaping FreesoundHandler) {
        let urlString = (BASE + USER_BOOKMARK_CATEGORIES).replacingOccurrences(of: "<username>", with: username)
        getPaginatedList(urlString, page: page, pageSize: pageSize, handler: handler)
    }
    
    /// Retrieves sounds from a user's sound bookmark category.
    static public func getUserBookmarkCategorySounds(_ username: String,
                                                     categoryID: String,
                                                     page: Int? = nil,
                                                     pageSize: Int? = nil,
                                                     handler: @escaping FreesoundHandler) {
        let urlString = (BASE + USER_BOOKMARK_CATEGORY_SOUNDS).replacingOccurrences(of: "<username>", with: username).replacingOccurrences(of: "<bookmark_category_id>", with: categoryID)
        getPaginatedList(urlString, page: page, pageSize: pageSize, handler: handler)
    }
    
    /// Retrieves a pack instance.
    static public func getPackInstance(_ packID: String,
                                       page: Int? = nil,
                                       pageSize: Int? = nil,
                                       handler: @escaping FreesoundHandler) {
        let urlString = (BASE + PACK).replacingOccurrences(of: "<pack_id>", with: packID)
        requestWithHeaders(urlString, handler: { response in
            let packData = response.result.value as? [String: Any]
            handler(packData)
        })
    }
    
    /// Retrieves a pack's sounds.
    static public func getPackSounds(_ packID: String,
                                     page: Int? = nil,
                                     pageSize: Int? = nil,
                                     handler: @escaping FreesoundHandler) {
        let urlString = (BASE + PACK_SOUNDS).replacingOccurrences(of: "<pack_id>", with: packID)
        getPaginatedList(urlString, page: page, pageSize: pageSize, handler: handler)
    }
    
    /// Downloads a pack's sounds.
    static public func downloadPack(_ packID: String,
                                    to url: URL,
                                    handler: @escaping (URL?) -> ()) {
        let urlString = (BASE + PACK_DOWNLOAD).replacingOccurrences(of: "<pack_id>", with: packID)
        let destination: DownloadRequest.DownloadFileDestination = { _, _ in
            return (url, [.removePreviousFile, .createIntermediateDirectories])
        }
        if let httpHeaders = headers {
            Alamofire.download(urlString, headers: httpHeaders, to: destination).response { response in
                let url = response.destinationURL
                handler(url)
            }
        }
    }
    
    /// Retrieves information about the logged-in user.
    static public func getMe(handler: @escaping FreesoundHandler) {
        let urlString = (BASE + ME)
        requestWithHeaders(urlString, handler: { response in
            let meData = response.result.value as? [String: Any]
            handler(meData)
        })
    }
    
    /// Retrieves sound analysis data.
    static public func getAnalysis(_ id: String,
                                   descriptors: [FreesoundDescriptor],
                                   normalized: Bool = false,
                                   handler: @escaping FreesoundHandler) {
        var descriptorString = "?descriptors=" + descriptors.map { $0.string }.joined()
        if normalized {
            descriptorString.append("&normalized=1")
        }
        
        let urlString = (BASE + SOUND_ANALYSIS).replacingOccurrences(of: "<sound_id>", with: id).appending(descriptorString)
        requestWithHeaders(urlString, handler: { response in
            let analysis = response.result.value as? [String: Any]
            handler(analysis)
        })
    }
    
    /// Retrieves information about sounds similar to ID specified.
    static public func getSimilarSounds(_ id: String,
                                        handler: @escaping FreesoundHandler) {
        let urlString = (BASE + SIMILAR_SOUNDS).replacingOccurrences(of: "<sound_id>", with: id)
        requestWithHeaders(urlString, handler: { response in
            let similarSounds = response.result.value as? [String: Any]
            handler(similarSounds)
        })
    }
    
    /// Retrieves comments made on a sound.
    static public func getComments(_ id: String,
                                   handler: @escaping FreesoundHandler) {
        let urlString = (BASE + COMMENTS).replacingOccurrences(of: "<sound_id>", with: id)
        
        requestWithHeaders(urlString, handler: { response in
            let comments = response.result.value as? [String: Any]
            handler(comments)
        })
    }
    
    // MARK: Utility
    static fileprivate func requestWithHeaders(_ string: String,
                                               method: HTTPMethod = .get,
                                               parameters: [String: Any] = [:],
                                               handler: @escaping (DataResponse<Any>) -> Void) {
        if let httpHeaders = headers {
            Alamofire.request(string, method: method, parameters: parameters, headers: httpHeaders).responseJSON(completionHandler: handler)
        }
    }
    
    static fileprivate func openURL(from string: String,
                                    handler: @escaping () -> ()) {
        if let url = URL(string: string) {
            UIApplication.shared.open(url, options: [:], completionHandler: { _ in
                handler()
            })
        }
    }
    
    static fileprivate func getPaginatedList(_ urlString: String,
                                             page: Int?,
                                             pageSize: Int?,
                                             handler: @escaping FreesoundHandler) {
        var parameters: [String: Any] = [:]
        parameters["page"] = page
        parameters["page_size"] = pageSize
        requestWithHeaders(urlString, parameters: parameters, handler: { response in
            let userBookmarkCategories = response.result.value as? [String: Any]
            handler(userBookmarkCategories)
        })
    }
    
    static fileprivate func getGeoTagString() -> String? {
        let locationManager = CLLocationManager()
        locationManager.requestWhenInUseAuthorization()
        if CLLocationManager.authorizationStatus() == .authorizedWhenInUse || CLLocationManager.authorizationStatus() == .authorizedAlways {
            if let location = locationManager.location {
                return "\(location.coordinate.latitude),\(location.coordinate.longitude),14"
            }
        }
        return nil
    }
}
