//
//  UIApplicationMessage\.swift
//  PortalApplication
//
//  Created by Guido Marucci Blas on 3/14/17.
//  Copyright © 2017 Guido Marucci Blas. All rights reserved.
//

import UIKit
import PortalView

public enum UIApplicationMessage {
    
    case didFinishLaunching(application: UIApplication, launchOptions: [UIApplicationLaunchOptionsKey: Any]?)
    case willResignActice(application: UIApplication)
    case didEnterBackground(application: UIApplication)
    case willEnterBackground(application: UIApplication)
    case didBecomeActive(application: UIApplication)
    case willTerminate(application: UIApplication)
    
}

public class UIKitApplicationContext<
    StateType,
    MessageType,
    CommandType,
    CustomSubscriptionType,
    RouteType: Route,
    NavigatorType: Navigator,
    ApplicationType: Application,
    CommandExecutorType: CommandExecutor,
    CustomSubscriptionManager: SubscriptionManager,
    CustomComponentRendererType: UIKitCustomComponentRenderer>
    
    where
    
    ApplicationType.StateType                   == StateType,
    ApplicationType.MessageType                 == MessageType,
    ApplicationType.CommandType                 == CommandType,
    ApplicationType.RouteType                   == RouteType,
    ApplicationType.NavigatorType               == NavigatorType,
    ApplicationType.SubscriptionType            == CustomSubscriptionType,
    NavigatorType.RouteType                     == RouteType,
    CommandExecutorType.MessageType             == Action<RouteType, MessageType>,
    CommandExecutorType.CommandType             == CommandType,
    CustomSubscriptionManager.SubscriptionType  == CustomSubscriptionType,
    CustomSubscriptionManager.RouteType         == RouteType,
    CustomSubscriptionManager.MessageType       == MessageType,
    CustomComponentRendererType.MessageType     == Action<RouteType, MessageType>  {

    public typealias Runner = ApplicationRunner<
        StateType,
        MessageType,
        CommandType,
        CustomSubscriptionType,
        RouteType,
        NavigatorType,
        ApplicationType,
        UIKitApplicationRenderer<MessageType, RouteType, CustomComponentRendererType>,
        CommandExecutorType,
        CustomSubscriptionManager>
    
    
    fileprivate let application: ApplicationType
    fileprivate let commandExecutor: CommandExecutorType
    fileprivate let subscriptionManager: CustomSubscriptionManager
    fileprivate let customComponentRenderer: CustomComponentRendererType
    fileprivate var middlewares: [Runner.Middleware] = []
    
    public init(
        application: ApplicationType,
        commandExecutor: CommandExecutorType,
        subscriptionManager: CustomSubscriptionManager,
        customComponentRenderer: CustomComponentRendererType) {
        self.application = application
        self.commandExecutor = commandExecutor
        self.subscriptionManager = subscriptionManager
        self.customComponentRenderer = customComponentRenderer
    }
    
    public func runner(for window: UIWindow) -> (@escaping (UIApplicationMessage) -> MessageType?) -> (UIApplicationMessage) -> Void {
        let runner = self.createApplicationRunner(window: window)
        middlewares.forEach(runner.registerMiddleware)
        return { messageMapper in
            return { applicationMessage in
                guard let message = messageMapper(applicationMessage) else { return }
                runner.dispatch(action: .sendMessage(message))
            }
        }
    }
    
    public func registerMiddleware<MiddlewareType: MiddlewareProtocol>(_ middleware: MiddlewareType)
        where
        MiddlewareType.MessageType == MessageType,
        MiddlewareType.StateType == StateType,
        MiddlewareType.CommandType == CommandType {
            
        middlewares.append(middleware.call)
    }
}

extension UIKitApplicationContext {
    
    fileprivate func createApplicationRunner(window: UIWindow) -> Runner {
        return Runner(application: application, commandExecutor: commandExecutor, subscriptionManager: subscriptionManager) { dispatch in
            UIKitApplicationRenderer(window: window, customComponentRenderer: customComponentRenderer, dispatch: dispatch)
        }
    }
    
}

public final class PortalUIApplication: UIResponder, UIApplicationDelegate {

    public static func start<
        StateType,
        MessageType,
        CommandType,
        CustomSubscriptionType,
        RouteType: Route,
        NavigatorType: Navigator,
        ApplicationType: Application,
        CommandExecutorType: CommandExecutor,
        CustomSubscriptionManager: SubscriptionManager,
        CustomComponentRendererType: UIKitCustomComponentRenderer> (
            applicationContext: UIKitApplicationContext<
                StateType,
                MessageType,
                CommandType,
                CustomSubscriptionType,
                RouteType,
                NavigatorType,
                ApplicationType,
                CommandExecutorType,
                CustomSubscriptionManager,
                CustomComponentRendererType>,
            messageMapper: @escaping (UIApplicationMessage) -> MessageType?)
    
        where
        
        ApplicationType.StateType                   == StateType,
        ApplicationType.MessageType                 == MessageType,
        ApplicationType.CommandType                 == CommandType,
        ApplicationType.RouteType                   == RouteType,
        ApplicationType.NavigatorType               == NavigatorType,
        ApplicationType.SubscriptionType            == CustomSubscriptionType,
        NavigatorType.RouteType                     == RouteType,
        CommandExecutorType.MessageType             == Action<RouteType, MessageType>,
        CommandExecutorType.CommandType             == CommandType,
        CustomSubscriptionManager.SubscriptionType  == CustomSubscriptionType,
        CustomSubscriptionManager.RouteType         == RouteType,
        CustomSubscriptionManager.MessageType       == MessageType,
        CustomComponentRendererType.MessageType     == Action<RouteType, MessageType> {
            
            PortalUIApplication.binder = { window in
                applicationContext.runner(for: window)(messageMapper)
            }
            
            let unsafeArgv = UnsafeMutableRawPointer(CommandLine.unsafeArgv).bindMemory(
                to: UnsafeMutablePointer<Int8>.self,
                capacity: Int(CommandLine.argc)
            )
            UIApplicationMain(CommandLine.argc, unsafeArgv, nil, NSStringFromClass(PortalUIApplication.self))
    }

    public static func subscribe(subscriber: @escaping (UIApplicationMessage) -> Void) {
        PortalUIApplication.subscribers.append(subscriber)
    }
    
    private static var binder: (UIWindow) -> ((UIApplicationMessage) -> Void) = { _ in { _ in } }
    private static var subscribers: [(UIApplicationMessage) -> Void] = []
    
    private static func dispatch(message: UIApplicationMessage) {
        subscribers.forEach { $0(message) }
    }
    
    public func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {

        let window = UIWindow(frame: UIScreen.main.bounds)
        PortalUIApplication.subscribe(subscriber: PortalUIApplication.binder(window))
        PortalUIApplication.dispatch(message: .didFinishLaunching(application: application, launchOptions: launchOptions))
        window.rootViewController = UIViewController()
        window.makeKeyAndVisible()
        return true
    }
    
    public func applicationWillResignActive(_ application: UIApplication) {
        PortalUIApplication.dispatch(message: .willResignActice(application: application))
    }
    
    public func applicationDidEnterBackground(_ application: UIApplication) {
        PortalUIApplication.dispatch(message: .didEnterBackground(application: application))
    }
    
    public func applicationWillEnterForeground(_ application: UIApplication) {
        PortalUIApplication.dispatch(message: .willEnterBackground(application: application))
    }
    
    public func applicationDidBecomeActive(_ application: UIApplication) {
        PortalUIApplication.dispatch(message: .didBecomeActive(application: application))
    }
    
    public func applicationWillTerminate(_ application: UIApplication) {
        PortalUIApplication.dispatch(message: .willTerminate(application: application))
    }
    
}
