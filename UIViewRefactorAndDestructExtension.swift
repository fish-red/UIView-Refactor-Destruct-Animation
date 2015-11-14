//
//  UIViewRefactorExtension.swift
//
//  Created by seedante on 15/11/8.
//  Copyright © 2015年 seedante. All rights reserved.
//

import Foundation
import UIKit

enum SDERefactorDirection{
    case Horizontal
    case Vertical
    case Diagonal
    case Custom
}

extension CGRect{
    var centerPoint: CGPoint{
        return CGPoint(x: origin.x + size.width / 2, y: origin.y + size.height / 2)
    }
}

extension UIView {
    //MARK: Refactor

    func refactor(){
        refactorWithNewFrame(nil, piecesRegion: nil, shiningColor: nil)
    }

    func customRefactor(){
        //DIY...
    }

    /**
     It's a alternative for move animation. Note: it cann't work fine with Auto Layout.
     - parameter destinationFrame: the frame you want to change to. If you not specify this parameter, it will refactor self in place. I recommend that you change this from CGRect? to CGRect when you use.
     - parameter jumpRect:        the area where all pieces appear, if nil, is 2X frame of the view.
     - parameter shiningColor:    if you specify this parameter, add light like electric welding.
     - parameter direction:       the direction of animation
     - parameter animationTime:   the total time of animation
     - parameter ratio:           the ratio which piece to view, here the ratio is used on width and height both.
     - parameter enableBigRegion: you will get 2X or 4X size of general piece if you enable it. I love this, and it can reduce the time of animation. I recommend just enable it if the view is big enough.
     **/
    func refactorWithNewFrame(destinationFrame: CGRect?, piecesRegion jumpRect: CGRect?, shiningColor: UIColor?, direction: SDERefactorDirection = .Horizontal, refactorTime animationTime: NSTimeInterval = 0.5, pieceRatio ratio: CGFloat = 0.05, enableBigRegion: Bool = false){

        guard let _ = self.superview else{
            return
        }

        if direction == .Custom{
            customRefactor()
            return
        }

        if destinationFrame != nil{
            self.translatesAutoresizingMaskIntoConstraints = false
            self.frame = destinationFrame!
        }

        let fromViewSnapshot = self.snapshotViewAfterScreenUpdates(false)
        UIView.animateWithDuration(0.3, animations: {
            self.alpha = 0
        })

        let origin = self.frame.origin
        let size = self.frame.size
        let pieceWidth: CGFloat = size.width * ratio
        let pieceHeight: CGFloat = size.height * ratio
        let (column, row) = columnAndrow(size, ratio: ratio)
        let delayDelta: Double = (direction == .Diagonal) ? animationTime / Double(column + row - 1) : animationTime / Double(column * row)
        let piecesRect = filterRect(jumpRect)

        var snapshots: [UIView] = []
        var ignoreIndexSet:Set<Int> = []
        var index = 0
        var delay: NSTimeInterval = 0
        var cleanTime: NSTimeInterval = 0

        for y in CGFloat(0).stride(to: size.height, by: pieceHeight) {
            for x in CGFloat(0).stride(to: size.width, by: pieceWidth) {

                index += 1
                if ignoreIndexSet.contains(index){
                    continue
                }

                let indexOffset = ignoreIndexSet.reduce(0, combine: {
                    delta, element in
                    let gap = element < index ? delta + 1 : delta
                    return gap
                })

                let (snapshotRegion, addedSet) = snapshotInfo(enableBigRegion, index: index, xy: (x, y), widthXheight: (pieceWidth, pieceHeight), columnXrow: (column, row))
                let initialFrame = randomRectFrom(piecesRect, regionSize: snapshotRegion.size)
                let finalFrame = CGRect(origin: CGPoint(x: (x + origin.x), y: (y + origin.y)), size: snapshotRegion.size)
                if addedSet.count > 0{
                    ignoreIndexSet.unionInPlace(addedSet)
                }

                let snapshot = fromViewSnapshot.resizableSnapshotViewFromRect(snapshotRegion, afterScreenUpdates: false, withCapInsets: UIEdgeInsetsZero)
                self.superview!.addSubview(snapshot)
                snapshots.append(snapshot)
                snapshot.frame = initialFrame
                snapshot.alpha = 0.0

                switch direction{
                case .Horizontal:
                    let x = index % column == 0 ? column : index % column
                    let y = (index - x + column) / column
                    delay = delayDelta * Double(x * row + y - indexOffset)
                case .Vertical:
                    delay = delayDelta * Double(index - indexOffset)
                case .Diagonal:
                    delay = delayDelta * Double(diagonalIndexFor(index, columnXrow: (column, row)))
                case .Custom: break
                }

                let duration: NSTimeInterval = 0.2 + 0.1 * Double(UInt32(arc4random()) % UInt32(3))
                cleanTime = (delay + duration + 0.2 > cleanTime) ? delay + duration + 0.2 : cleanTime

                //UIView block animation is better than Core Animation on the performance here.
                let randomScale =  CGFloat(UInt32(arc4random()) % UInt32(5)) / 10
                snapshot.transform = CGAffineTransformTranslate(CGAffineTransformIdentity, randomScale, randomScale)
                UIView.animateWithDuration(0.1, delay: delay, options: UIViewAnimationOptions.BeginFromCurrentState, animations: {
                    snapshot.alpha = 1
                    }, completion: { _ in

                        UIView.animateWithDuration(duration, delay: 0, options: .CurveEaseOut, animations: {
                            snapshot.transform = CGAffineTransformIdentity
                            snapshot.frame = finalFrame
                            }, completion: nil)
                })

                //addRefactorAnimationOn(snapshot, delayTime: delay, duration: duration, initialFrame: initialFrame, finalFrame: finalFrame)
                if shiningColor != nil{
                    addShiningAnimationOn(snapshot, delayTime: delay, shiningColor: shiningColor!)
                }

            }
        }
        //can't rely on dispatch_after, which can't guarantee the exact execution time
        self.performSelector("cleanUp:", withObject: snapshots, afterDelay: cleanTime)
    }

    //MARK: Destruct
    func destruct(){
        destructWithDirection()
    }

    /**
     It's a alternative for disappear animation. Add a destruct animation on view and remove it from its superview.

     - parameter direction:     animation direction
     - parameter animationTime: animation time
     - parameter ratio:         piece ratio to view. It apply to width and height both.
     */
    func destructWithDirection(direction: SDERefactorDirection = .Diagonal, animationTime: NSTimeInterval = 0.5, pieceRatio ratio: CGFloat = 0.05){
        guard let _ = self.superview else{
            return
        }

        if direction == .Custom{
            //DIY
            return
        }

        let fromViewSnapshot = self.snapshotViewAfterScreenUpdates(false)
        self.alpha = 0

        let origin = self.frame.origin
        let size = self.frame.size
        let pieceWidth = size.width * ratio
        let pieceHeight = size.height * ratio
        let (column, row) = columnAndrow(size, ratio: ratio)
        //Here 0.3 is the animation time of single piece
        let totalTime: NSTimeInterval = animationTime - 0.3
        let delayDelta: Double = (direction == .Diagonal) ? totalTime / Double(column + row - 1) : totalTime / Double(column * row)

        var snapshots: [UIView] = []
        var delay:NSTimeInterval = 0
        var windUpTime: NSTimeInterval = 0
        var index = 0

        for y in CGFloat(0).stride(to: size.height, by: pieceHeight) {
            for x in CGFloat(0).stride(to: size.width, by: pieceWidth) {
                index += 1

                var regionWidth = pieceWidth
                var regionHeight = pieceHeight
                if x + regionWidth > size.width{
                    regionWidth = size.width - x
                }
                if y + regionHeight > size.height{
                    regionHeight = size.height - y
                }

                let snapshotRegion = CGRect(x: x, y: y, width: regionWidth, height: regionHeight)
                let snapshot = fromViewSnapshot.resizableSnapshotViewFromRect(snapshotRegion, afterScreenUpdates: false, withCapInsets: UIEdgeInsetsZero)
                let snapshotFrame = CGRect(x: x + origin.x, y: y + origin.y, width: regionWidth, height: regionHeight)

                self.superview?.addSubview(snapshot)
                snapshot.frame = snapshotFrame
                snapshots.append(snapshot)

                switch direction{
                case .Horizontal:
                    let x = index % column == 0 ? column : index % column
                    let y = (index - x + column) / column
                    delay = delayDelta * Double(x * row + y)
                case .Vertical:
                    delay = delayDelta * Double(index)
                case .Diagonal:
                    delay = delayDelta * Double(diagonalIndexFor(index, columnXrow: (column, row)))
                case .Custom: break
                }

                addAnnihilationAnimationaOn(snapshot, delayTime: delay)
                windUpTime = (delay + 0.3 > windUpTime) ? delay + 0.3 : windUpTime
            }
        }

        self.performSelector("windUp:", withObject: snapshots, afterDelay: windUpTime + 0.1)
    }


    //MARK: Private Helper
    private func columnAndrow(size: CGSize, ratio: CGFloat) -> (Int, Int){
        /*
        You can't rely on ceil, like Int(ceil(size.width / width)), sometimes the follow result is +1.
        */
        var rowCount = 0
        for _ in CGFloat(0).stride(to: size.height, by: size.height * ratio){
            rowCount += 1
        }

        var columnCount = 0
        for _ in CGFloat(0).stride(to: size.width, by: size.width * ratio){
            columnCount += 1
        }

        return (columnCount, rowCount)
    }

    private func diagonalIndexFor(index: Int, columnXrow:(Int, Int)) -> Int{

        let (column, _) = columnXrow
        let x = index % column == 0 ? column : index % column
        let y = (index - x + column) / column
        let DiagonalIndex = x + y - 1
        return DiagonalIndex
    }

    /*
    - parameter jumpRect: the area where you specify all the pieces appear
    - returns: the jumpRect intersect with the screen, or UIView's 2X frame if you not specify jumpRect.
    */
    private func filterRect(jumpRect: CGRect?) -> CGRect{
        var piecesRect = self.frame
        let screenRect = UIScreen.mainScreen().bounds
        if jumpRect != nil{
            if CGRectContainsRect(screenRect, jumpRect!){
                piecesRect = jumpRect!
            }else{
                if !CGRectIsNull(CGRectIntersection(screenRect, jumpRect!)){
                    piecesRect = CGRectIntersection(screenRect, jumpRect!)
                }else{
                    let bigRect = CGRectInset(self.frame, -self.frame.size.width/2, -self.frame.size.height/2)
                    piecesRect = CGRectIntersection(screenRect, bigRect)
                }
            }
        }else{
            let bigRect = CGRectInset(self.frame, -self.frame.size.width/2, -self.frame.size.height/2)
            piecesRect = CGRectIntersection(screenRect, bigRect)
        }

        return piecesRect

    }

    private func snapshotInfo(enableBigRegion: Bool, index: Int, xy: (CGFloat, CGFloat), widthXheight: (CGFloat, CGFloat), columnXrow: (Int, Int)) -> (CGRect, Set<Int>){
        /*
        What this method do? Integrate partions to reduce the total animation time.
        _______       _______      ____      ____       _______      _______
        |__|__|  >>>  |     |  or  |__|  >>> |__|  or   |__|__|  >>> |_____|
        |__|__|  >>>  |_____|      |__|      |__|

        */
        let (pieceWidth, pieceHeight) = widthXheight

        let isBigRegion = enableBigRegion ? Int(UInt32(arc4random()) % UInt32(2)) == 1 : false
        var regionWidth = isBigRegion ? 2.0 * pieceWidth : pieceWidth
        var regionHeith = isBigRegion ? 2.0 * pieceHeight : pieceHeight

        let (regionX, regionY) = xy

        let size = self.frame.size
        if regionX + regionWidth >= size.width{
            regionWidth = size.width - regionX
        }
        if regionY + regionHeith >= size.height{
            regionHeith = size.height - regionY
        }

        let (column, _) = columnXrow
        var ignoreIndexSet: Set<Int> = []

        if isBigRegion {
            if regionX + pieceWidth < size.width{
                ignoreIndexSet.insert(index + 1)
            }

            if regionY + pieceHeight < size.height{
                ignoreIndexSet.insert(index + column)

                if regionX + pieceWidth < size.width{
                    ignoreIndexSet.insert(index + column + 1)
                }
            }
        }

        let regionOrigin: CGPoint = CGPoint(x: regionX, y: regionY)
        let regionSize: CGSize = CGSize(width: regionWidth, height: regionHeith)
        let snapshotRegion = CGRect(origin: regionOrigin, size: regionSize)

        return (snapshotRegion, ignoreIndexSet)
    }

    private func randomRectFrom(sourceRect: CGRect, regionSize: CGSize) -> CGRect {
        //Now the method is like its name.
        let randomX: CGFloat = sourceRect.origin.x + CGFloat(UInt32(arc4random()) % UInt32(sourceRect.size.width))
        let randomY: CGFloat = sourceRect.origin.y + CGFloat(UInt32(arc4random()) % UInt32(sourceRect.size.height))

        let initialFrame = CGRect(x: randomX, y: randomY, width: regionSize.width, height: regionSize.height)

        return initialFrame
    }

    private func addRefactorAnimationOn(snapshot: UIView, delayTime: NSTimeInterval, duration: NSTimeInterval, initialFrame: CGRect, finalFrame: CGRect){
        let opaAni = CABasicAnimation(keyPath: "opacity")
        opaAni.fromValue = 0
        opaAni.toValue = 1
        opaAni.duration = 0.1
        opaAni.fillMode = kCAFillModeForwards
        opaAni.removedOnCompletion = false
        opaAni.beginTime = CACurrentMediaTime() + delayTime
        snapshot.layer.addAnimation(opaAni, forKey: nil)

        let moveAni = CABasicAnimation(keyPath: "position")
        moveAni.fromValue = NSValue(CGPoint: initialFrame.centerPoint)
        moveAni.toValue = NSValue(CGPoint: finalFrame.centerPoint)
        moveAni.duration = duration
        moveAni.beginTime = CACurrentMediaTime() + delayTime
        moveAni.fillMode = kCAFillModeForwards
        moveAni.removedOnCompletion = false
        snapshot.layer.addAnimation(moveAni, forKey: nil)

    }

    private func addShiningAnimationOn(snapshot: UIView, delayTime: NSTimeInterval, shiningColor: UIColor, shadowRadius: CGFloat = 10.0){
        snapshot.layer.shadowColor = shiningColor.CGColor
        snapshot.layer.shadowRadius = shadowRadius
        snapshot.layer.shadowPath = UIBezierPath(rect: snapshot.bounds).CGPath

        let opaKeyAni = CAKeyframeAnimation(keyPath: "shadowOpacity")
        opaKeyAni.values = [0.0, 0.1, 1.0, 0.8, 0.0]
        opaKeyAni.keyTimes = [0.0, 0.5, 0.7, 0.99, 1.0]
        opaKeyAni.duration = 0.3
        opaKeyAni.beginTime = CACurrentMediaTime() + delayTime

        snapshot.layer.addAnimation(opaKeyAni, forKey: nil)

    }

    private func addAnnihilationAnimationaOn(snapshot: UIView, delayTime: NSTimeInterval){
        let delta = CGFloat(UInt32(arc4random()) % UInt32(30))
        let end = CGPoint(x: snapshot.center.x - delta, y: snapshot.center.y - delta)
        
        UIView.animateWithDuration(0.3, delay: delayTime, options: .CurveEaseInOut, animations: {
            snapshot.alpha = 0
            snapshot.center = end
            }, completion: nil)
    }
    
    @objc private func cleanUp(snapshots: [UIView]){
        self.alpha = 1
        for snapshot in snapshots{
            snapshot.removeFromSuperview()
        }
        
    }
    
    @objc private func windUp(snapshots: [UIView]){
        self.removeFromSuperview()
        for snapshot in snapshots{
            snapshot.removeFromSuperview()
        }
    }
}
