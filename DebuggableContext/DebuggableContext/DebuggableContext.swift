//
//  DebuggableContext.swift
//  DebuggableContext
//
//  Created by Wei Wang (@onevcat) on 2018/3/15.
//
// MIT License
// Copyright (c) 2018 Wei Wang
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

#if DEBUG
import UIKit
public protocol DebuggableContext: class {
    /// The menu related to this debuggable context. These items will be presented in an alert sheet from the most top view controller.
    var debugMenus: [DebuggableContextItem] { get }
    
    /// Register `self` to debuggable list. After registered, this debuggable context will be displayed when you shake your device.
    func registerDebug()
    
    /// Unregister `self` from debuggable list. It is the reverting of `registerDebug`. Generally, there is no need to unregister. The
    /// registered items will be unregistered automatically when dealloc.
    func unregisterDebug()
    
    /// Context name displayed in menu. By default it is the name of self class.
    var debugContextName: String { get }
}

extension DebuggableContext {
    public func registerDebug() {
        ContextDebugResponser.shared.register(self)
    }
    
    public func unregisterDebug() {
        ContextDebugResponser.shared.unregister(self)
    }
    
    public var debugContextName: String {
        return String(describing: Self.self)
    }
}

/// Filtering which target should be displayed in the context debug menu. It is useful when you have a lot of debuggable context items,
/// but only want to show one or some of them from current view controller. Make your view controller to extend this protocol and return
/// `false` to exclude the `target` context.
public protocol DebuggableContextFiltering {
    func filterContext(target: DebuggableContext) -> Bool
}

/// Debug button item which will be shown in the context menu.
public struct DebuggableContextItem {
    let name: String
    let action: () -> Void
    public init(name: String, action: @escaping () -> Void) {
        self.name = name
        self.action = action
    }
}

final public class ShakeDetectingWindow: UIWindow {
    override public func motionEnded(_ motion: UIEventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            NotificationCenter.default.post(name: .contextDebugDeviceShakenNotification, object: self)
            return
        }
        
        super.motionEnded(motion, with: event)
    }
}

// Private
private let logTag = "[ContextDebuggable]"
private extension Notification.Name {
    static let contextDebugDeviceShakenNotification = NSNotification.Name("com.onevcat.ContextDebugDeviceShakenNotification")
}

private final class ContextDebugResponser {
    static let shared = ContextDebugResponser()
    private let table = NSMapTable<NSString, AnyObject>(valueOptions: .weakMemory)
    private init() {
        NotificationCenter.default.addObserver(self, selector: #selector(onShaken),
                                               name: .contextDebugDeviceShakenNotification, object: nil)
    }
    
    func register(_ target: DebuggableContext) {
        var key = target.debugContextName as NSString
        if table.object(forKey: key) != nil {
            var t = target
            withUnsafePointer(to: &t) { key = "\(key)-\($0)" as NSString }
        }
        table.setObject(target, forKey: key)
    }
    
    func unregister(_ target: DebuggableContext) {
        let allKeys = table.keyEnumerator().allObjects
        for key in allKeys {
            guard let k = key as? NSString else { continue }
            if let value = table.object(forKey: k), value === target {
                table.removeObject(forKey: k)
                break
            }
        }
    }
    
    @objc private func onShaken() {
        
        guard let allContext = (table.objectEnumerator()?.allObjects.map { $0 as! DebuggableContext }) else {
            assertionFailure("\(logTag) Corrupted context table.")
            return
        }
        
        guard let topVC = UIApplication.shared.keyWindow?.rootViewController?.topMostViewController() else {
            assertionFailure("\(logTag) Fails to show debug menu. Cannot get most top view controller.")
            return
        }
        
        let filter = (topVC as? DebuggableContextFiltering)?.filterContext ?? { _ in true }
        let validContext = allContext.filter(filter)
        
        switch validContext.count {
        case 0: print("\(logTag) No listening debugable object. Skipping...")
        case 1: show(context: validContext[0], in: topVC)
        default: show(contexts: validContext, in: topVC)
        }
    }
    
    private func show(contexts: [DebuggableContext], in viewController: UIViewController) {
        
        print("\(logTag) Presenting debuggable context menu from \(viewController)")
        
        let alert = UIAlertController(title: "Valid Context", message: nil, preferredStyle: .actionSheet)
        let actions = contexts.map { context in
            return UIAlertAction(context) { self.show(context: context, in: viewController) }
        } + [.cancel]
        actions.forEach(alert.addAction)
        
        viewController.present(alert, animated: true)
    }
    
    private func show(context: DebuggableContext, in viewController: UIViewController) {
        
        print("\(logTag) Presenting debuggable context menu from \(viewController)")
        
        let alert = UIAlertController(title: context.debugContextName, message: nil, preferredStyle: .actionSheet)
        let actions = context.debugMenus.map(UIAlertAction.init) + [.cancel]
        actions.forEach(alert.addAction)
        
        viewController.present(alert, animated: true)
    }
}
    
private extension UIAlertAction {
    static let cancel = UIAlertAction(title: "Cancel", style: .cancel)
    
    convenience init(_ context: DebuggableContext, done: @escaping () -> Void) {
        self.init(title: context.debugContextName, style: .default) { _ in done() }
    }
    
    convenience init(_ item: DebuggableContextItem) {
        self.init(title: item.name, style: .default) { _ in item.action() }
    }
}

private extension UIViewController {
    @objc func topMostViewController() -> UIViewController {
        if let presentedViewController = presentedViewController {
            return presentedViewController.topMostViewController()
        } else {
            let childViewController = view.subviews.first { $0.next is UIViewController }
                                                   .map { $0.next as! UIViewController }
            return childViewController?.topMostViewController() ?? self
        }
    }
}

private extension UITabBarController {
    override func topMostViewController() -> UIViewController {
        return selectedViewController!.topMostViewController()
    }
}

private extension UINavigationController {
    override func topMostViewController() -> UIViewController {
        return visibleViewController!.topMostViewController()
    }
}

private extension UIWindow {
    func topViewController() -> UIViewController? {
        return rootViewController?.topMostViewController()
    }
}
#endif
