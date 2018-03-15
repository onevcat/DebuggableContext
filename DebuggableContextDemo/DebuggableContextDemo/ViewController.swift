//
//  ViewController.swift
//  DebuggableContextDemo
//
//  Created by Wang Wei on 2018/3/15.
//  Copyright © 2018年 OneV's Den. All rights reserved.
//

import UIKit
import DebuggableContext

class ViewController: UIViewController {
    @IBAction func dismiss(segue: UIStoryboardSegue) {}
    override func viewDidLoad() {
        super.viewDidLoad()
        #if DEBUG
        registerDebug()
        #endif
    }
}

#if DEBUG
extension ViewController: DebuggableContext {
    var debugMenus: [DebuggableContextItem] {
        return [
            .init(name: "Color To Cupid") { [weak self] in
                self?.view.backgroundColor = UIColor(red:0.94, green:0.73, blue:0.83, alpha:1.00)
            },
            .init(name: "Color To Mint") { [weak self] in
                self?.view.backgroundColor = UIColor(red:0.71, green:0.96, blue:0.82, alpha:1.00)
            }
        ]
    }
}
#endif

class AnotherViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        #if DEBUG
        registerDebug()
        #endif
    }
}

#if DEBUG
extension AnotherViewController: DebuggableContext {
    var debugMenus: [DebuggableContextItem] {
        return [ .init(name: "Say Hello") { print("Hello World! from \(self)") } ]
    }
}
    
extension AnotherViewController: DebuggableContextFiltering {
    func filterContext(target: DebuggableContext) -> Bool {
        return  target === self
    }
}
#endif
