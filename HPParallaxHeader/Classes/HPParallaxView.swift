//
//  HPParallaxView.swift
//  HPParallaxHeader
//
//  Created by Hien Pham on 19/05/2021.
//

import Foundation
import UIKit

class HPParallaxView: UIView {
    weak var parent: HPParallaxHeader?
    
    override func willMove(toSuperview newSuperview: UIView?) {
        if let scrollView = superview as? HPScrollView {
            parent?.removeObserveContentOffset()
        }
    }
    
    override func didMoveToSuperview() {
        if let scrollView = superview as? HPScrollView {
            parent?.addObserveContentOffset(scrollView)
        }
    }
}
