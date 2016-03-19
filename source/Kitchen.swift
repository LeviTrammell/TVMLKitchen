//
//  Kitchen.swift
//  TVMLKitchen
//
//  Created by toshi0383 on 12/28/15.
//  Copyright © 2015 toshi0383. All rights reserved.
//

@exported import TVMLKit

public typealias JavaScriptEvaluationHandler = (TVApplicationController, JSContext) -> Void
public typealias KitchenErrorHandler = NSError -> Void
public typealias KitchenActionIDHandler = (String -> Void)

let kitchenErrorDomain = "jp.toshi0383.TVMLKitchen.error"

public class Kitchen: NSObject {
    /// singleton instance
    private static let sharedKitchen = Kitchen()

    private var evaluateAppJavaScriptInContext: JavaScriptEvaluationHandler?

    private var kitchenErrorHandler: KitchenErrorHandler? {
        didSet {
            Kitchen.appController.evaluateInJavaScriptContext({jsContext in
                let errorHandler: @convention(block) String -> Void =
                { [unowned self] (message: String) in
                    let error = NSError(domain: kitchenErrorDomain,
                        code: 1, userInfo: [NSLocalizedDescriptionKey:message])
                    self.kitchenErrorHandler?(error)
                }
                jsContext.setObject(unsafeBitCast(errorHandler, AnyObject.self),
                    forKeyedSubscript: "kitchenErrorHandler")
            }, completion: nil)
        }
    }

    private static let defaultErrorHandler: KitchenErrorHandler = { error in
        let alert = UIAlertController(title: "Oops, something's wrong.",
            message: "\(error.localizedDescription)",
            preferredStyle: UIAlertControllerStyle.Alert)
        let ok = UIAlertAction(title: "OK", style: .Cancel, handler: nil)
        alert.addAction(ok)
        main {
            Kitchen.navigationController.presentViewController(alert, animated: true, completion: nil)
        }
    }

    private var window: UIWindow

    private var appController: TVApplicationController!

    private var actionIDHandler: KitchenActionIDHandler?
    private var playActionIDHandler: KitchenActionIDHandler?

    public static var mainBundlePath: String!

    override init() {
        window = UIWindow(frame: UIScreen.mainScreen().bounds)
        super.init()
    }

}


// MARK: Public API (serve)
extension Kitchen {

    public static func serve(xmlString xmlString: String, type: PresentationType = .Default) {
        openTVMLTemplateFromXMLString(xmlString, type: type)
    }

    public static func serve(xmlFile xmlFile: String, type: PresentationType = .Default) {
        do {
            try openTVMLTemplateFromXMLFile(xmlFile, type: type)
        } catch let error as NSError {
            sharedKitchen.kitchenErrorHandler?(error)
        }
    }

    public static func serve(jsFile jsFile: String, type: PresentationType = .Default) {
        openTVMLTemplateFromJSFile(jsFile, type: type)
    }

    public static func serve(urlString urlString: String, type: PresentationType = .Default) {
        openTVMLTemplateFromURL(urlString, type: type)
    }

    public static func serve<R: RecipeType>(recipe recipe: R) {
        openTVMLTemplateFromXMLString(recipe.xmlString, type: recipe.presentationType)
    }

    public static func dismissModal() {
        dismissTVMLModal()
    }

}

// MARK: window
extension Kitchen {

    public static var window: UIWindow {
        return sharedKitchen.window
    }

}

// MARK: TVApplicationControllerDelegate
extension Kitchen {

    public static var appController: TVApplicationController {
        return sharedKitchen.appController
    }

    public static var navigationController: UINavigationController {
        return sharedKitchen.appController.navigationController
    }
}

public class Cookbook {

    /// launchOptions
    private var launchOptions: [NSObject: AnyObject]?
    /// inject functions or a exceptionHandler into JSContext
    public var evaluateAppJavaScriptInContext: JavaScriptEvaluationHandler?
    /// handles "select" event
    public var actionIDHandler: KitchenActionIDHandler?
    /// handles "play" event
    public var playActionIDHandler: KitchenActionIDHandler?
    /// error handler that gets called when any errors occured
    /// in Kitchen(both JS and Swift context)
    public var onError: KitchenErrorHandler?

    /// - parameter launchOptions: launchOptions
    public init(launchOptions: [NSObject: AnyObject]?) {
        self.launchOptions = launchOptions
    }
}

extension Kitchen {

    /**
     create TVApplicationControllerContext using launchOptions

     Supposed to be called in application:didFinishedLaunchingWithOptions:
     in UIApplicationDelegate of your @UIApplicationMain .
     - parameter cookbook: a Cookbook configuration object
     - returns:  If launch process was successfully or not.
    */
    public static func prepare(cookbook: Cookbook) -> Bool {
        sharedKitchen.window = UIWindow(frame: UIScreen.mainScreen().bounds)
        sharedKitchen.evaluateAppJavaScriptInContext = cookbook.evaluateAppJavaScriptInContext

        /// Create the TVApplicationControllerContext
        let appControllerContext = TVApplicationControllerContext()

        let javaScriptURL = NSBundle(forClass: self).URLForResource("kitchen", withExtension: "js")!
        appControllerContext.javaScriptApplicationURL = javaScriptURL
        appControllerContext.launchOptions[UIApplicationLaunchOptionsURLKey] = javaScriptURL

        /// Cutting `kitchen.js` off
        let TVBaseURL = javaScriptURL.URLByDeletingLastPathComponent

        /// Define framework bundle URL
        appControllerContext.launchOptions["BASEURL"] = TVBaseURL!.absoluteString
        let info = NSBundle(forClass: self).infoDictionary!
        let bundleid = info[String(kCFBundleIdentifierKey)]!
        appControllerContext.launchOptions[UIApplicationLaunchOptionsSourceApplicationKey] = bundleid

        /// Define mainBundle URL
        mainBundlePath = NSBundle.mainBundle().bundleURL.absoluteString
        appControllerContext.launchOptions["MAIN_BUNDLE_URL"] = mainBundlePath

        if let launchOptions = cookbook.launchOptions as? [String: AnyObject] {
            for (kind, value) in launchOptions {
                appControllerContext.launchOptions[kind] = value
            }
        }

        sharedKitchen.appController = TVApplicationController(context: appControllerContext,
            window: sharedKitchen.window, delegate: sharedKitchen)

        /// Must be place this statement after appController is initialized
        sharedKitchen.kitchenErrorHandler = cookbook.onError
        sharedKitchen.actionIDHandler = cookbook.actionIDHandler
        sharedKitchen.playActionIDHandler = cookbook.playActionIDHandler

        return true
    }

    /**
     create TVApplicationControllerContext using launchOptions

     Supposed to be called in application:didFinishedLaunchingWithOptions:
     in UIApplicationDelegate of your @UIApplicationMain .

     - parameter launchOptions: launchOptions
     - parameter evaluateAppJavaScriptInContext:
                 the closure to inject functions or a exceptionHandler into JSContext
     - parameter actionIDHandler: a handler for "select" event
     - parameter playActionIDHandler: a handler fo "play" event
     - parameter onError: the Error handler that gets called when any errors occured
                 in Kitchen(both JS and Swift context)
     - returns:  If launch process was successfully or not.
     */
    @available(*, deprecated, message="Use prepare(cookbook:) instead")
    public static func prepare(launchOptions: [NSObject: AnyObject]?,
        evaluateAppJavaScriptInContext: JavaScriptEvaluationHandler? = nil,
        actionIDHandler: KitchenActionIDHandler? = nil,
        playActionIDHandler: KitchenActionIDHandler? = nil,
        onError kitchenErrorHandler: KitchenErrorHandler? = defaultErrorHandler) -> Bool
    {
        sharedKitchen.window = UIWindow(frame: UIScreen.mainScreen().bounds)
        sharedKitchen.evaluateAppJavaScriptInContext = evaluateAppJavaScriptInContext

        /// Create the TVApplicationControllerContext
        let appControllerContext = TVApplicationControllerContext()

        let javaScriptURL = NSBundle(forClass: self).URLForResource("kitchen", withExtension: "js")!
        appControllerContext.javaScriptApplicationURL = javaScriptURL
        appControllerContext.launchOptions[UIApplicationLaunchOptionsURLKey] = javaScriptURL

        /// Cutting `kitchen.js` off
        let TVBaseURL = javaScriptURL.URLByDeletingLastPathComponent

        /// Define framework bundle URL
        appControllerContext.launchOptions["BASEURL"] = TVBaseURL!.absoluteString
        let info = NSBundle(forClass: self).infoDictionary!
        let bundleid = info[String(kCFBundleIdentifierKey)]!
        appControllerContext.launchOptions[UIApplicationLaunchOptionsSourceApplicationKey] = bundleid

        /// Define mainBundle URL
        mainBundlePath = NSBundle.mainBundle().bundleURL.absoluteString
        appControllerContext.launchOptions["MAIN_BUNDLE_URL"] = mainBundlePath

        if let launchOptions = launchOptions as? [String: AnyObject] {
            for (kind, value) in launchOptions {
                appControllerContext.launchOptions[kind] = value
            }
        }

        sharedKitchen.appController = TVApplicationController(context: appControllerContext,
            window: sharedKitchen.window, delegate: sharedKitchen)

        /// Must be place this statement after appController is initialized
        sharedKitchen.kitchenErrorHandler = kitchenErrorHandler
        sharedKitchen.actionIDHandler = actionIDHandler
        sharedKitchen.playActionIDHandler = playActionIDHandler

        return true
    }

    /// Calls TVApplicationController.stop()
    public static func stop() {
        sharedKitchen.appController.stop()
    }

}

// MARK: TVApplicationControllerDelegate
extension Kitchen: TVApplicationControllerDelegate {

    public func appController(appController: TVApplicationController,
        didFinishLaunchingWithOptions options: [String: AnyObject]?)
    {
    }

    public func appController(appController: TVApplicationController,
        didFailWithError error: NSError)
    {
        self.kitchenErrorHandler?(error)
    }

    public func appController(appController: TVApplicationController,
        didStopWithOptions options: [String: AnyObject]?)
    {
    }

    public func appController(appController: TVApplicationController,
        evaluateAppJavaScriptInContext jsContext: JSContext)
    {
        if let playActionIDHandler = playActionIDHandler {
            let playActionIDHandler: @convention(block) String -> Void = { actionID in
                playActionIDHandler(actionID)
            }
            jsContext.setObject(unsafeBitCast(playActionIDHandler, AnyObject.self),
                forKeyedSubscript: "playActionIDHandler")
        }

        if let actionIDHandler = actionIDHandler {
            let actionIDHandler: @convention(block) String -> Void = { actionID in
                actionIDHandler(actionID)
            }
            jsContext.setObject(unsafeBitCast(actionIDHandler, AnyObject.self),
                forKeyedSubscript: "actionIDHandler")
        }


        // Add the tab bar handler for the shared instance.

        let tabBarHandler: @convention(block) String -> Void = { index in
            KitchenTabBar.sharedBar.tabChanged(index)
        }

        jsContext.setObject(unsafeBitCast(tabBarHandler, AnyObject.self),
            forKeyedSubscript: "tabBarHandler")

        self.evaluateAppJavaScriptInContext?(appController, jsContext)
    }
}
