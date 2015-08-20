//
//  ViewController.swift
//  SwiftSpace
//
//  Created by Simon Gladman on 20/08/2015.
//  Copyright © 2015 Simon Gladman. All rights reserved.
//

import UIKit
import SceneKit
import CoreMotion

class ViewController: UIViewController
{
    
    
    let buttonBar = UIToolbar()
    
    let cameraDistance: Float = 2
    
    let sceneKitView = SCNView()
    let cameraNode = SCNNode()
    
    var initialAttitude: (roll: Double, pitch:Double)?
    let motionManager = CMMotionManager()
    
    let currentDrawingLayerSize = 512
    
    var currentDrawingNode: SCNNode?
    var currentDrawingLayer: CAShapeLayer?
    
    override func viewDidLoad()
    {
        guard motionManager.gyroAvailable else
        {
            fatalError("CMMotionManager not available.")
        }
        
        super.viewDidLoad()
        
        let title = UIBarButtonItem(title: "flexmonkey.co.uk", style: UIBarButtonItemStyle.Plain, target: nil, action: nil)
        let spacer = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.FlexibleSpace, target: nil, action: nil)
        let clearButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.Trash, target: self, action: "clear")
        buttonBar.items = [title, spacer, clearButton]
        
        view.addSubview(sceneKitView)
        view.addSubview(buttonBar)
        
        sceneKitView.backgroundColor = UIColor.darkGrayColor()
        
        sceneKitView.scene = SCNScene()
        
        // centreNode
        
        let centreNode = SCNNode()
        centreNode.position = SCNVector3(x: 0, y: 0, z: 0)
        scene.rootNode.addChildNode(centreNode)
        
        // camera
        
        let camera = SCNCamera()
        camera.xFov = 20
        camera.yFov = 20
     
        cameraNode.camera = camera
        scene.rootNode.addChildNode(cameraNode)
        
        let constraint = SCNLookAtConstraint(target: centreNode)
        cameraNode.constraints = [constraint]
        
        cameraNode.pivot = SCNMatrix4MakeTranslation(0, 0, -cameraDistance)

        // motion manager
        
        let queue = NSOperationQueue.mainQueue
        
        motionManager.deviceMotionUpdateInterval = 1 / 30
        
        motionManager.startDeviceMotionUpdatesToQueue(queue())
        {
            (deviceMotionData: CMDeviceMotion?, error: NSError?) in
            
            if let deviceMotionData = deviceMotionData
            {
                if (self.initialAttitude == nil)
                {
                    self.initialAttitude = (deviceMotionData.attitude.roll,
                        deviceMotionData.attitude.pitch)
                }
                
                self.cameraNode.eulerAngles.y = Float(self.initialAttitude!.roll - deviceMotionData.attitude.roll)
                self.cameraNode.eulerAngles.x = Float(self.initialAttitude!.pitch - deviceMotionData.attitude.pitch)
            }
        }
        
    }
    
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?)
    {
        super.touchesBegan(touches, withEvent: event)
        
        currentDrawingNode = SCNNode(geometry: SCNBox(width: 1, height: 1, length: 0, chamferRadius: 0))
        currentDrawingLayer = CAShapeLayer()
        
        if let currentDrawingNode = currentDrawingNode, currentDrawingLayer = currentDrawingLayer
        {
            currentDrawingNode.position = SCNVector3(x: 0, y: 0, z: 0)
            
            currentDrawingNode.eulerAngles.x = self.cameraNode.eulerAngles.x
            currentDrawingNode.eulerAngles.y = self.cameraNode.eulerAngles.y
            
            scene.rootNode.addChildNode(currentDrawingNode)

            currentDrawingLayer.strokeColor = UIColor.whiteColor().CGColor
            currentDrawingLayer.fillColor = nil
            currentDrawingLayer.lineWidth = 10
            currentDrawingLayer.lineJoin = kCALineJoinRound
            currentDrawingLayer.lineCap = kCALineCapRound
            currentDrawingLayer.frame = CGRect(x: 0, y: 0, width: currentDrawingLayerSize, height: currentDrawingLayerSize)

            let material = SCNMaterial()

            material.diffuse.contents = currentDrawingLayer
            material.lightingModelName = SCNLightingModelConstant
            
            currentDrawingNode.geometry?.materials = [material]
        }
    }
    
    override func touchesMoved(touches: Set<UITouch>, withEvent event: UIEvent?)
    {
        super.touchesMoved(touches, withEvent: event)
        
        let locationInView = touches.first?.locationInView(view)
        
        if let hitTestResult:SCNHitTestResult = sceneKitView.hitTest(locationInView!, options: nil).filter( { $0.node == currentDrawingNode }).first,
            currentDrawingLayer = currentDrawingLayer
        {
            if currentDrawingLayer.path == nil
            {
                let newX = CGFloat((hitTestResult.localCoordinates.x + 0.5) * Float(currentDrawingLayerSize))
                let newY = CGFloat((hitTestResult.localCoordinates.y + 0.5) * Float(currentDrawingLayerSize))
                
                currentDrawingLayer.path = UIBezierPath(rect: CGRect(x: newX, y: newY, width: 0, height: 0)).CGPath
            }
            
            let drawPath = UIBezierPath(CGPath: currentDrawingLayer.path!)
 
            let newX = CGFloat((hitTestResult.localCoordinates.x + 0.5) * Float(currentDrawingLayerSize))
            let newY = CGFloat((hitTestResult.localCoordinates.y + 0.5) * Float(currentDrawingLayerSize))
            
            drawPath.addLineToPoint(CGPoint(x: newX, y: newY))
            
            currentDrawingLayer.path = drawPath.CGPath
        }
    }
    
    override func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?)
    {
        super.touchesEnded(touches, withEvent: event)
        
        currentDrawingLayer = nil
        currentDrawingNode = nil
    }
    
    func clear()
    {
        scene.rootNode.childNodes.filter( {$0.geometry != nil} ).forEach
        {
            $0.removeFromParentNode()
        }
    }
    
    var scene: SCNScene
    {
        return sceneKitView.scene!
    }
    
    override func viewDidLayoutSubviews()
    {
        super.viewDidLayoutSubviews()
        
        let topMargin = topLayoutGuide.length
        let toolbarHeight = buttonBar.intrinsicContentSize().height
        
        sceneKitView.frame = CGRect(x: 0, y: topMargin, width: view.frame.width, height: view.frame.height - topMargin - toolbarHeight)
        
        buttonBar.frame = CGRect(x: 0, y: view.frame.height - toolbarHeight, width: view.frame.width, height: toolbarHeight)
    }
    
    override func supportedInterfaceOrientations() -> UIInterfaceOrientationMask
    {
        return UIInterfaceOrientationMask.Portrait
    }
    
}

