//
//  HPScrollView.swift
//  HPParallaxHeader
//
//  Created by Hien Pham on 17/05/2021.
//

import Foundation
import UIKit

/**
 The delegate of a MXScrollView object may adopt the MXScrollViewDelegate protocol to control subview's scrolling effect.
 */
@objc public protocol HPScrollViewDelegate: UIScrollViewDelegate {
    /**
     Asks the page if the scrollview should scroll with the subview.
     
     @param scrollView The scrollview. This is the object sending the message.
     @param subView    An instance of a sub view.
     
     @return YES to allow scrollview and subview to scroll together. YES by default.
     */
    func scrollViewShouldScroll(_ scrollView: HPScrollView, with subView: UIScrollView) -> Bool
}

/**
 The MXScrollView is a UIScrollView subclass with the ability to hook the vertical scroll from its subviews.
 */
public class HPScrollView : UIScrollView {
    static var KVOContext = "kDMScrollViewKVOContext"

    /**
     Delegate instance that adopt the MXScrollViewDelegate.
     */
    @IBOutlet public weak var hpDelegate: HPScrollViewDelegate?
    
    private var observedViews: [UIScrollView] = []
    private var isObserving: Bool = true
    private var lock: Bool = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        initialize()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        initialize()
    }
    
    func initialize() {
        //            self.forwarder = [MXScrollViewDelegateForwarder new];
        //            super.delegate = self.forwarder;
        
        showsVerticalScrollIndicator = false
        isDirectionalLockEnabled = true
        bounces = true
        
        panGestureRecognizer.cancelsTouchesInView = false
        
        addObserver(self, forKeyPath: #keyPath(UIScrollView.contentOffset),
                    options:[.new, .old], context: &HPScrollView.KVOContext)

//        myKVOToken = observe(\.contentOffset, options: [.old, .new], changeHandler: {[weak self] scrollView, change in
//            guard let self = self else { return }
//            self.onChangeContentOffset(scrollView, change)
//        })
    }

    // MARK: - Properties

//    - (void)setDelegate:(id<MXScrollViewDelegate>)delegate {
//        self.forwarder.delegate = delegate;
//        // Scroll view delegate caches whether the delegate responds to some of the delegate
//        // methods, so we need to force it to re-evaluate if the delegate responds to them
//        super.delegate = nil;
//        super.delegate = self.forwarder;
//    }
//
//    - (id<MXScrollViewDelegate>)delegate {
//        return self.forwarder.delegate;
//    }

    deinit {
        removeObserver(self, forKeyPath: #keyPath(contentOffset), context: &HPScrollView.KVOContext)
        removeObservedViews()
    }
}

extension HPScrollView: UIGestureRecognizerDelegate {
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                                  shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if (otherGestureRecognizer.view == self) {
            return false
        }
        
        // Ignore other gesture than pan
        if !(gestureRecognizer is UIPanGestureRecognizer) {
            return false
        }
        
        // Lock horizontal pan gesture.
        guard let velocity = (gestureRecognizer as? UIPanGestureRecognizer)?.velocity(in: self) else {
            return false
        }
        if (fabs(velocity.x) > fabs(velocity.y)) {
            return false
        }
        
        var otherView = otherGestureRecognizer.view
        // WKWebView on he MXScrollView
        if let wkContentClass = NSClassFromString("WKContent"),
           let unwrapped = otherView, unwrapped.isKind(of: wkContentClass) {
            otherView = unwrapped.superview
        }
        
        // Consider scroll view pan only
        guard let scrollView = otherView as? UIScrollView else {
            return false
        }
        
        // Tricky case: UITableViewWrapperView
        if scrollView.superview is UITableView {
            return false
        }
        
        //tableview on the HPScrollView
        if let uiTableViewContentClass = NSClassFromString("UITableViewCellContentView"),
           (scrollView.superview?.isKind(of: uiTableViewContentClass) ?? false) {
            return false
        }
        
        let shouldScroll = (hpDelegate?.scrollViewShouldScroll(self, with: scrollView)) ?? true
        
        if shouldScroll {
            addObservedView(scrollView)
        }
        
        return shouldScroll
    }
}

// MARK: - KVO
extension HPScrollView {
    /*
     *  MARK: - KVO
     */
    
    func addObserver(to scrollView: UIScrollView) {
        lock = (scrollView.contentOffset.y > -scrollView.contentInset.top)
        
        scrollView.addObserver(self,
                               forKeyPath: #keyPath(UIScrollView.contentOffset),
                               options: [.old, .new],
                               context: &HPScrollView.KVOContext)
    }
    
    func removeObserver(from scrollView: UIScrollView) {
        scrollView.removeObserver(self,
                                  forKeyPath: #keyPath(UIScrollView.contentOffset),
                                  context: &HPScrollView.KVOContext)
    }

    
    //This is where the magic happens...
    override open func observeValue(forKeyPath keyPath: String?,
                                    of object: Any?,
                                    change: [NSKeyValueChangeKey : Any]?,
                                    context: UnsafeMutableRawPointer?) {
        guard context == &HPScrollView.KVOContext && keyPath == #keyPath(UIScrollView.contentOffset) else {
            return super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
        
        guard let scrollView = object as? UIScrollView,
            let new = change?[.newKey] as? CGPoint,
            let old = change?[.oldKey] as? CGPoint else { return }
        let diff = old.y - new.y
        if diff == 0.0 || !isObserving { return }

        if scrollView == self {
            
            //Adjust self scroll offset when scroll down
            if (diff > 0 && lock) {
                self.scrollView(self, setContentOffset: old)
            } else if contentOffset.y < -contentInset.top && !bounces {
                self.scrollView(self, setContentOffset: CGPoint(x: contentOffset.x,
                                                                y: -contentInset.top))
            } else if contentOffset.y > -parallaxHeader.minimumHeight {
                self.scrollView(self, setContentOffset: CGPoint(x: contentOffset.x,
                                                                y: -parallaxHeader.minimumHeight))
            }

        } else {
            print("\(new) - \(old)")
            
            //Adjust the observed scrollview's content offset
            lock = (scrollView.contentOffset.y > -scrollView.contentInset.top)
            
            //Manage scroll up
            if (contentOffset.y < -parallaxHeader.minimumHeight) && lock && (diff < 0) {
                self.scrollView(scrollView, setContentOffset: old)
            }
            
            //Disable bouncing when scroll down
            if !lock && ((contentOffset.y > -contentInset.top) || bounces) {
                self.scrollView(scrollView, setContentOffset: CGPoint(x: scrollView.contentOffset.x,
                                                                      y: -scrollView.contentInset.top))
            }
        }
    }

}

// MARK: - Scrolling views handlers
extension HPScrollView {
    func addObservedView(_ scrollView: UIScrollView) {
        guard !observedViews.contains(scrollView) else { return }
        observedViews.append(scrollView)
        addObserver(to: scrollView)
    }
    
    func removeObservedViews() {
        observedViews.forEach { removeObserver(from: $0) }
        observedViews.removeAll()
    }

    func scrollView(_ scrollView: UIScrollView, setContentOffset offset: CGPoint) {
        isObserving = false
        scrollView.contentOffset = offset
        isObserving = true
    }
}


//@implementation MXScrollViewDelegateForwarder
//
//- (BOOL)respondsToSelector:(SEL)selector {
//    return [self.delegate respondsToSelector:selector] || [super respondsToSelector:selector];
//}
//
//- (void)forwardInvocation:(NSInvocation *)invocation {
//    [invocation invokeWithTarget:self.delegate];
//}

// MARK: - <UIScrollViewDelegate>
extension HPScrollView: UIScrollViewDelegate {
    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        hpDelegate?.scrollViewDidEndDecelerating?(scrollView)
    }
    
    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        hpDelegate?.scrollViewDidEndDragging?(scrollView, willDecelerate: decelerate)
    }
}
