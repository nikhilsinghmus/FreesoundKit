//
//  Freesound.swift
//  FreesoundKit
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
    /// Stores client information to later communicate with API. Should be called first, typically in the AppDelegate method *application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions:)*.
    /// - parameter clientID: The client ID registered with the Freesound API.
    /// - parameter clientSecret: The client secret registered with the Freesound API.
    static public func setup(with clientID: String, clientSecret: String) {
        CLIENT_ID = clientID
        CLIENT_SECRET = clientSecret
    }
    
    /// Authorizes client via OAuth2 and retrieves access token. Should be called if not already authorized, which can be checked via the **isAuthorized** property. If already authorized, see *refresh()*.
    /// - parameter handler: A closure in which you may implement some input interface for the user to enter a temporary authorization code obtained after logging in to Freesound, which can then be used with *handleCode(_:)*.
    static public func authorize(handler: @escaping () -> ()) {
        if let id = CLIENT_ID {
            openURL(from: BASE + AUTHORIZE + "?client_id=\(id)&response_type=code&state=freesoundkit", handler: handler)
        }
    }
    
    /// Refreshes authorization, retrieves new access and refresh tokens. Typically called if already authorized, which can be checked by accessing the **isAuthorized** property.
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
    /// - parameter code: The temporary authorization code provided by Freesound to the user.
    @discardableResult
    static public func handleCode(_ code: String?) -> FreesoundResult {
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
    
    /// Text search searches sounds using tags and metadata.
    /// - parameter text: The query text to look up.
    /// - parameter page: The page number of results to retrieve (nil by default).
    /// - parameter pageSize: The size of each returned page (nil by default, given in sounds-per-page).
    /// - parameter handler: A closure that handles the response data, an optional dictionary with the following keys:
    ///     - **count**: The number of results on the page.
    ///     - **next**: A link to the next page of results (nil if none).
    ///     - **results**: An array of dictionaries representing information about the sounds on the current page.
    ///         - Each of these dictionaries contains, by default, the following keys:
    ///             - **id**: The sound ID.
    ///             - **name**: The sound name.
    ///             - **tags**: The sound's tags.
    ///             - **username**: The user who uploaded the current sound.
    ///             - **license**: The license provided.
    ///     - **previous**: A link to the previous page of results (nil if none).
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
    
    /// Content search searches sounds using their content descriptors.
    /// - parameter target: The ID of a sound whose content descriptors should be used in the query.
    /// - parameter page: The page number of results to retrieve (nil by default).
    /// - parameter pageSize: The size of each returned page (nil by default, given in sounds-per-page).
    /// - parameter handler: A closure that handles the response data, an optional dictionary with the following keys:
    ///     - **count**: The number of results on the page.
    ///     - **next**: A link to the next page of results (nil if none).
    ///     - **results**: An array of dictionaries representing information about the sounds on the current page.
    ///         - Each of these dictionaries contains, by default, the following keys:
    ///             - **id**: The sound ID.
    ///             - **name**: The sound name.
    ///             - **tags**: The sound's tags.
    ///             - **username**: The user who uploaded the current sound.
    ///             - **license**: The license provided.
    ///     - **previous**: A link to the previous page of results (nil if none).
    static public func contentSearch(_ target: String,
                                     page: Int? = nil,
                                     pageSize: Int? = nil,
                                     handler: @escaping FreesoundHandler) {
        let urlString = BASE + CONTENT_SEARCH
        var parameters: [String: Any] = [:]
        parameters["target"] = target
        parameters["page"] = page
        parameters["page_size"] = pageSize
        
        requestWithHeaders(urlString, parameters: parameters, handler: { response in
            let sounds = response.result.value as? [String: Any]
            handler(sounds)
        })
    }
    
    /// Content search searches sounds using their content descriptors.
    /// - parameter target: A dictionary of filters and corresponding values (given as strings).
    /// - parameter page: The page number of results to retrieve (nil by default).
    /// - parameter pageSize: The size of each returned page (nil by default, given in sounds-per-page).
    /// - parameter handler: A closure that handles the response data, an optional dictionary with the following keys:
    ///     - **count**: The number of results on the page.
    ///     - **next**: A link to the next page of results (nil if none).
    ///     - **results**: An array of dictionaries representing information about the sounds on the current page.
    ///         - Each of these dictionaries contains, by default, the following keys:
    ///             - **id**: The sound ID.
    ///             - **name**: The sound name.
    ///             - **tags**: The sound's tags.
    ///             - **username**: The user who uploaded the current sound.
    ///             - **license**: The license provided.
    ///     - **previous**: A link to the previous page of results (nil if none).
    static public func contentSearch(_ target: [String: String],
                                     page: Int? = nil,
                                     pageSize: Int? = nil,
                                     handler: @escaping FreesoundHandler) {
        let urlString = BASE + CONTENT_SEARCH
        var parameters: [String: Any] = [:]
        let targetString = "target=" + target.map { "\($0.key):\($0.value)" }.joined(separator: " ")
        parameters["target"] = targetString
        parameters["page"] = page
        parameters["page_size"] = pageSize
        
        requestWithHeaders(urlString, parameters: parameters, handler: { response in
            let sounds = response.result.value as? [String: Any]
            handler(sounds)
        })
    }
    
    /// Downloads a sound file to a specified URL.
    /// - parameter id: The ID number of a sound to download.
    /// - parameter url: The destination URL to download a sound to.
    /// - parameter handler: A closure that takes an optional URL (nil if the file didn't download correctly).
    static public func download(_ id: String,
                                to url: URL,
                                handler: @escaping ((URL?) -> ())) {
        let urlString = (BASE + DOWNLOAD).replacingOccurrences(of: "<sound_id>", with: "id")
        let destination: DownloadRequest.DownloadFileDestination = { _, _ in
            return (url, [.removePreviousFile, .createIntermediateDirectories])
        }
        if let httpHeaders = headers {
            Alamofire.download(urlString, headers: httpHeaders, to: destination).validate().response { response in
                let url = response.destinationURL
                handler(url)
            }
        }
    }
    
    /// Uploads a sound file to Freesound.
    /// - parameter url: The URL of the sound file to upload.
    /// - parameter name: The name for the uploaded sound.
    /// - parameter tags: Tags for the uploaded sound (nil by default).
    /// - parameter description: A description to add to the uploaded sound.
    /// - parameter pack: The name of a new/existing pack to add the sound to (nil by default).
    /// - parameter license: The license for the uploaded sound.
    /// - parameter geoTag: A boolean value indicating whether or not to geotag the sound (false by default). May request user authorization to access location data.
    /// - parameter handler: A closure that handles the response data, an optional dictionary with the following keys:
    ///     - **detail**: A confirmation message.
    ///     - **id**: The sound ID if a description was provided, OR
    ///     - **name**: The sound name if a description was not provided.
    static public func upload(_ url: URL,
                              name: String = "",
                              tags: [String]? = nil,
                              description: String = "",
                              pack: String? = nil,
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
        if let soundTags = tags {
            uploadUrlString.append("&tags=" + soundTags.map { $0.replacingOccurrences(of: " ", with: "-") }.joined(separator: "%20"))
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
    /// - parameter uploadFilename: The upload-pending file to add a description to.
    /// - parameter name: A name for the uploaded sound.
    /// - parameter tags: Tags for the uploaded sound (nil by default).
    /// - parameter description: A description to add to the uploaded sound.
    /// - parameter license: The license for the uploaded sound.
    /// - parameter pack: The name of a new/existing pack to add the sound to (nil by default).
    /// - parameter geoTag: A boolean value indicating whether or not to geotag the sound (false by default). May request user authorization to access location data.
    /// - parameter handler: A closure that handles the response data, an optional dictionary with the following keys:
    ///     - **detail**: A confirmation message.
    ///     - **id**: The sound ID.
    static public func describeSound(_ uploadFilename: String,
                                     name: String?,
                                     tags: [String]? = nil,
                                     description: String,
                                     license: FreesoundLicense,
                                     pack: String? = nil,
                                     geoTag: Bool = false,
                                     handler: @escaping FreesoundHandler) {
        let urlString = BASE + DESCRIBE
        
        var parameters: [String: Any] = [:]
        parameters["upload_filename"] = uploadFilename
        parameters["name"] = name
        parameters["tags"] = tags?.map { $0.replacingOccurrences(of: " ", with: "-") }.joined(separator: " ")
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
    /// - parameter id: The ID number of a sound whose description to edit.
    /// - parameter name: A new name for the sound.
    /// - parameter tags: New tags for the sound (nil by default).
    /// - parameter description: A new description for the sound.
    /// - parameter license: The new license for the sound.
    /// - parameter pack: The name of a new/existing pack to add the sound to (nil by default).
    /// - parameter geoTag: A boolean value indicating whether or not to geotag the sound (false by default). May request user authorization to access location data.
    /// - parameter handler: A closure that handles the response data, an optional dictionary with the following key:
    ///     - **detail**: A confirmation message.
    static public func editSoundDescription(_ id: String,
                                            name: String?,
                                            tags: [String]? = nil,
                                            description: String,
                                            license: FreesoundLicense,
                                            pack: String? = nil,
                                            geoTag: Bool = false,
                                            handler: @escaping FreesoundHandler) {
        let urlString = (BASE + EDIT_DESCRIPTION).replacingOccurrences(of: "<sound_id>", with: id)
        
        var parameters: [String: Any] = [:]
        parameters["name"] = name
        parameters["tags"] = tags?.map { $0.replacingOccurrences(of: " ", with: "-") }.joined(separator: " ")
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
    /// - parameter handler: A closure that handles the response data, as an optional dictionary with the keys:
    ///     - **pending_description**: An array of filenames for sounds pending description.
    ///     - **pending_processing**: An array of dictionaries, each representing a sound.
    ///     - **pending_moderation**: An array of dictionaries, each representing a sound.
    static public func getPendingUploads(handler: @escaping FreesoundHandler) {
        let urlString = BASE + PENDING
        requestWithHeaders(urlString, handler: { response in
            let pendingUploads = response.result.value as? [String: Any]
            handler(pendingUploads)
        })
    }
    
    /// Bookmarks a sound for the logged in user.
    /// - parameter id: The ID of the sound to be bookmarked.
    /// - parameter name: A new name for the bookmarked sound (nil by default).
    /// - parameter category: A bookmark category for the bookmarked sound (nil by default).
    /// - parameter handler: A closure that handles the response data, an optional dictionary with the following key:
    ///     - **detail**: A confirmation message.
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
    /// - parameter id: The ID of the sound to be rated.
    /// - parameter rating: The rating for the sound as an integer from 0 to 5.
    /// - parameter handler: A closure that handles the response data, an optional dictionary with the following key:
    ///     - **detail**: A confirmation message or description of an error if one occurred.
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
    /// - parameter id: The ID of the sound to comment on.
    /// - parameter comment: The comment to leave.
    /// - parameter handler: A closure that handles the response data, an optional dictionary with the following key:
    ///     - **detail**: A confirmation message.
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
    /// - parameter id: The ID of the sound whose preview audio to get.
    /// - parameter url: The URL to download the preview audio to.
    /// - parameter quality: The quality (high/low) of the preview to get.
    /// - parameter handler: A closure that takes an optional URL (nil if the file didn't download correctly).
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
            Alamofire.download(previewUrlString, to: destination).validate().response { response in
                let url = response.destinationURL
                handler(url)
            }
        })
    }
    
    /// Gets preview URL for a sound.
    /// - parameter id: The ID of the sound whose preview URL to get.
    /// - parameter quality: The quality (high/low) of the preview soundfile whose URL to get.
    /// - parameter handler: A closure that takes in an optional URL that points to the preview soundfile.
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
    /// - parameter username: The user whose information to retrieve.
    /// - parameter handler: A closure that handles the response data, an optional dictionary with the following keys:
    ///     - **url**: URL for the user's Freesound website profile.
    ///     - **username**: The user's username.
    ///     - **about**: The user's profile's "about" text.
    ///     - **homepage**: URI for the user's homepage (if listed).
    ///     - **avatar**: Dictionary containing URIs for the user's avatar (nil if not available). Fields are **Small**, **Medium**, and **Large**.
    ///     - **date_joined**: The date when the user joined Freesound.
    ///     - **num_sounds**: Number of sounds uploaded by the user.
    ///     - **sounds**: URI for a list of sounds by the user.
    ///     - **num_packs**: Number of packs created by the user.
    ///     - **packs**: URI for a list of packs by the user.
    ///     - **num_posts**: Number of forum posts by the user.
    ///     - **num_comments**: Number of comments made by the user on other users' sounds.
    ///     - **bookmark_categories**: URI for a list of bookmark categories made by the user.
    static public func getUserInstance(_ username: String,
                                       handler: @escaping FreesoundHandler) {
        let urlString = (BASE + USER).replacingOccurrences(of: "<username>", with: username)
        requestWithHeaders(urlString, handler: { response in
            let userData = response.result.value as? [String: Any]
            handler(userData)
        })
    }
    
    /// Retrieves a user's sounds.
    /// - parameter username: The user whose sounds to retrieve.
    /// - parameter page: The page number of results to retrieve (nil by default).
    /// - parameter pageSize: The size of each returned page (nil by default, given in sounds-per-page).
    /// - parameter handler: A closure that handles the response data, an optional dictionary with the following keys:
    ///     - **count**: The number of results on the page.
    ///     - **next**: A link to the next page of results (nil if none).
    ///     - **results**: An array of dictionaries representing information about the sounds on the current page.
    ///         - Each of these dictionaries contains, by default, the following keys:
    ///             - **id**: The sound ID.
    ///             - **name**: The sound name.
    ///             - **tags**: The sound's tags.
    ///             - **username**: The user who uploaded the current sound.
    ///             - **license**: The license provided.
    ///     - **previous**: A link to the previous page of results (nil if none).
    static public func getUserSounds(_ username: String,
                                     page: Int? = nil,
                                     pageSize: Int? = nil,
                                     handler: @escaping FreesoundHandler) {
        let urlString = (BASE + USER_SOUNDS).replacingOccurrences(of: "<username>", with: username)
        getPaginatedList(urlString, page: page, pageSize: pageSize, handler: handler)
    }
    
    /// Retrieves a user's packs.
    /// - parameter username: The user whose packs to retrieve.
    /// - parameter page: The page number of results to retrieve (nil by default).
    /// - parameter pageSize: The size of each returned page (nil by default, given in packs-per-page).
    /// - parameter handler: A closure that handles the response data, an optional dictionary with the following keys:
    ///     - **count**: The number of results on the page.
    ///     - **next**: A link to the next page of results (nil if none).
    ///     - **results**: An array of dictionaries representing information about the packs on the current page.
    ///         - Each of these dictionaries contains, by default, the following keys:
    ///             - **id**: The pack ID.
    ///             - **url**: The URI for the pack.
    ///             - **description**: The description for the pack (if available).
    ///             - **created**: Date the pack was made.
    ///             - **name**: The name of the pack.
    ///             - **username**: Username of the pack owner.
    ///             - **num_sounds**: Number of sounds in the current pack.
    ///             - **sounds**: URI for list of sounds in the current pack.
    ///             - **num_downloads**: Number of times the current pack has been downloaded.
    ///     - **previous**: A link to the previous page of results (nil if none).
    static public func getUserPacks(_ username: String,
                                    page: Int? = nil,
                                    pageSize: Int? = nil,
                                    handler: @escaping FreesoundHandler) {
        let urlString = (BASE + USER_PACKS).replacingOccurrences(of: "<username>", with: username)
        getPaginatedList(urlString, page: page, pageSize: pageSize, handler: handler)
    }
    
    /// Retrieves a user's sound bookmark categories.
    /// - parameter username: User whose bookmark categories to retrieve.
    /// - parameter page: The page number of results to retrieve (nil by default).
    /// - parameter pageSize: The size of each returned page (nil by default, given in bookmark-categories-per-page).
    /// - parameter handler: A closure that handles the response data, an optional dictionary with the following keys:
    ///     - **count**: The number of results on the page.
    ///     - **next**: A link to the next page of results (nil if none).
    ///     - **results**: An array of dictionaries representing information about the packs on the current page.
    ///         - Each of these dictionaries contains, by default, the following keys:
    ///             - **url**: URI for the bookmark category.
    ///             - **name**: Name of the bookmark category.
    ///             - **num_sounds**: Number of sounds in the bookmark category.
    ///             - **sounds**: URI for list of sounds in the current bookmark category.
    ///     - **previous**: A link to the previous page of results (nil if none).
    static public func getUserBookmarkCategories(_ username: String,
                                                 page: Int? = nil,
                                                 pageSize: Int? = nil,
                                                 handler: @escaping FreesoundHandler) {
        let urlString = (BASE + USER_BOOKMARK_CATEGORIES).replacingOccurrences(of: "<username>", with: username)
        getPaginatedList(urlString, page: page, pageSize: pageSize, handler: handler)
    }
    
    /// Retrieves sounds from a user's sound bookmark category.
    /// - parameter username: User whose bookmark category to retrieve sounds from.
    /// - parameter categoryID: ID of the bookmark category from which to retrieve sounds.
    /// - parameter page: The page number of results to retrieve (nil by default).
    /// - parameter pageSize: The size of each returned page (nil by default, given in sounds-per-page).
    /// - parameter handler: A closure that handles the response data, an optional dictionary with the following keys:
    ///     - **count**: The number of results on the page.
    ///     - **next**: A link to the next page of results (nil if none).
    ///     - **results**: An array of dictionaries representing information about the packs on the current page.
    ///         - Each of these dictionaries contains, by default, the following keys:
    ///             - **id**: The sound ID.
    ///             - **name**: The sound name.
    ///             - **tags**: The sound's tags.
    ///             - **username**: The user who uploaded the current sound.
    ///             - **license**: The license provided.
    ///     - **previous**: A link to the previous page of results (nil if none).
    static public func getUserBookmarkCategorySounds(_ username: String,
                                                     categoryID: String,
                                                     page: Int? = nil,
                                                     pageSize: Int? = nil,
                                                     handler: @escaping FreesoundHandler) {
        let urlString = (BASE + USER_BOOKMARK_CATEGORY_SOUNDS).replacingOccurrences(of: "<username>", with: username).replacingOccurrences(of: "<bookmark_category_id>", with: categoryID)
        getPaginatedList(urlString, page: page, pageSize: pageSize, handler: handler)
    }
    
    /// Retrieves a pack instance.
    /// - parameter packID: ID of the pack to get information about.
    /// - parameter handler: A closure that handles the response data, an optional dictionary containing the following keys:
    ///     - **id**: The pack ID.
    ///     - **url**: The URI for the pack.
    ///     - **description**: The description for the pack (if available).
    ///     - **created**: The date the pack was made.
    ///     - **name**: The name of the pack.
    ///     - **username**: Username of the pack owner.
    ///     - **num_sounds**: Number of sounds in the current pack.
    ///     - **sounds**: URI for list of sounds in the current pack.
    ///     - **num_downloads**: Number of times the current pack has been downloaded.
    static public func getPackInstance(_ packID: String,
                                       handler: @escaping FreesoundHandler) {
        let urlString = (BASE + PACK).replacingOccurrences(of: "<pack_id>", with: packID)
        requestWithHeaders(urlString, handler: { response in
            let packData = response.result.value as? [String: Any]
            handler(packData)
        })
    }
    
    /// Retrieves a pack's sounds.
    /// - parameter packID: ID of the pack to retrieve sounds from.
    /// - parameter page: The page number of results to retrieve (nil by default).
    /// - parameter pageSize: The size of each returned page (nil by default, given in sounds-per-page).
    /// - parameter handler: A closure that handles the response data, an optional dictionary with the following keys:
    ///     - **count**: The number of results on the page.
    ///     - **next**: A link to the next page of results (nil if none).
    ///     - **results**: An array of dictionaries representing information about the packs on the current page.
    ///         - Each of these dictionaries contains, by default, the following keys:
    ///             - **id**: The sound ID.
    ///             - **name**: The sound name.
    ///             - **tags**: The sound's tags.
    ///             - **username**: The user who uploaded the current sound.
    ///             - **license**: The license provided.
    ///     - **previous**: A link to the previous page of results (nil if none).
    static public func getPackSounds(_ packID: String,
                                     page: Int? = nil,
                                     pageSize: Int? = nil,
                                     handler: @escaping FreesoundHandler) {
        let urlString = (BASE + PACK_SOUNDS).replacingOccurrences(of: "<pack_id>", with: packID)
        getPaginatedList(urlString, page: page, pageSize: pageSize, handler: handler)
    }
    
    /// Downloads a pack's sounds.
    /// - parameter packID: ID of the pack to download sounds from.
    /// - parameter url: URL to download the pakc .zip file to.
    /// - parameter handler: A closure that takes an optional URL (nil if the file didn't download correctly).
    static public func downloadPack(_ packID: String,
                                    to url: URL,
                                    handler: @escaping (URL?) -> ()) {
        let urlString = (BASE + PACK_DOWNLOAD).replacingOccurrences(of: "<pack_id>", with: packID)
        let destination: DownloadRequest.DownloadFileDestination = { _, _ in
            return (url, [.removePreviousFile, .createIntermediateDirectories])
        }
        if let httpHeaders = headers {
            Alamofire.download(urlString, headers: httpHeaders, to: destination).validate().response { response in
                let url = response.destinationURL
                handler(url)
            }
        }
    }
    
    /// Retrieves information about the logged-in user.
    /// - parameter handler: A closure that handles the response data, an optional dictionary with the following keys:
    ///     - **url**: URL for the user's Freesound website profile.
    ///     - **username**: The user's username.
    ///     - **about**: The user's profile's "about" text.
    ///     - **homepage**: URI for the user's homepage (if listed).
    ///     - **avatar**: Dictionary containing URIs for the user's avatar (nil if not available). Fields are **Small**, **Medium**, and **Large**.
    ///     - **date_joined**: The date when the user joined Freesound.
    ///     - **num_sounds**: Number of sounds uploaded by the user.
    ///     - **sounds**: URI for a list of sounds by the user.
    ///     - **num_packs**: Number of packs created by the user.
    ///     - **packs**: URI for a list of packs by the user.
    ///     - **num_posts**: Number of forum posts by the user.
    ///     - **num_comments**: Number of comments made by the user on other users' sounds.
    ///     - **bookmark_categories**: URI for a list of bookmark categories made by the user.
    ///     - **email**: Email ID of the logged in user.
    ///     - **unique_id**: A unique ID associated with the user.
    static public func getMe(handler: @escaping FreesoundHandler) {
        let urlString = (BASE + ME)
        requestWithHeaders(urlString, handler: { response in
            let meData = response.result.value as? [String: Any]
            handler(meData)
        })
    }
    
    /// Retrieves sound analysis data.
    /// - parameter id: ID of sound to be analyzed.
    /// - parameter descriptors: Analysis descriptors to retrieve for the sound file.
    /// - parameter normalized: A boolean value that sets whether to retrieve normalized or absolute values for specified content descriptors.
    /// - parameter handler: A closure that handles response data, an optional dictionary that contains keys corresponding to content descriptors.
    static public func getAnalysis(_ id: String,
                                   descriptors: [FreesoundDescriptor],
                                   normalized: Bool = false,
                                   handler: @escaping FreesoundHandler) {
        var descriptorString = "?descriptors=" + descriptors.map { $0.string }.joined(separator: ",")
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
    /// - parameter id: The ID of the sound to get sounds that are similar to.
    /// - parameter page: The page number of results to retrieve (nil by default).
    /// - parameter pageSize: The size of each returned page (nil by default, given in sounds-per-page).
    /// - parameter handler: A closure that handles the response data, an optional dictionary with the following keys:
    ///     - **count**: The number of results on the page.
    ///     - **next**: A link to the next page of results (nil if none).
    ///     - **results**: An array of dictionaries representing information about the packs on the current page.
    ///         - Each of these dictionaries contains, by default, the following keys:
    ///             - **id**: The sound ID.
    ///             - **name**: The sound name.
    ///             - **tags**: The sound's tags.
    ///             - **username**: The user who uploaded the current sound.
    ///             - **license**: The license provided.
    ///     - **previous**: A link to the previous page of results (nil if none).
    static public func getSimilarSounds(_ id: String,
                                        page: Int? = nil,
                                        pageSize: Int? = nil,
                                        handler: @escaping FreesoundHandler) {
        let urlString = (BASE + SIMILAR_SOUNDS).replacingOccurrences(of: "<sound_id>", with: id)
        var parameters: [String: Any] = [:]
        parameters["page"] = page
        parameters["page_size"] = pageSize
        requestWithHeaders(urlString, parameters: parameters, handler: { response in
            let similarSounds = response.result.value as? [String: Any]
            handler(similarSounds)
        })
    }
    
    /// Retrieves comments made on a sound.
    /// - parameter id: The ID of the sound to get comments made on.
    /// - parameter page: The page number of results to retrieve (nil by default).
    /// - parameter pageSize: The size of each returned page (nil by default, given in sounds-per-page).
    /// - parameter handler: A closure that handles the response data, an optional dictionary with the following keys:
    ///     - **count**: The number of results on the page.
    ///     - **next**: A link to the next page of results (nil if none).
    ///     - **results**: An array of dictionaries representing information about the packs on the current page.
    ///         - Each of these dictionaries contains, by default, the following keys:
    ///             - **username**: Username of the comment author.
    ///             - **comment**: The comment itself.
    ///             - **created**: Date the comment was made.
    ///     - **previous**: A link to the previous page of results (nil if none).
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
                return "&geotag=\(location.coordinate.latitude),\(location.coordinate.longitude),14"
            }
        }
        return nil
    }
}
