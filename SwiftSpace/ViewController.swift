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
    
    let hermitePath = UIBezierPath()
    var interpolationPoints = [CGPoint]()
    
    override func viewDidLoad()
    {
        guard motionManager.isGyroAvailable else
        {
            fatalError("CMMotionManager not available.")
        }
        
        super.viewDidLoad()
        
        let title = UIBarButtonItem(title: "flexmonkey.co.uk", style: UIBarButtonItemStyle.plain, target: nil, action: nil)
        let spacer = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.flexibleSpace, target: nil, action: nil)
        let clearButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.trash, target: self, action: #selector(ViewController.clear))
        buttonBar.items = [title, spacer, clearButton]
        
        view.addSubview(sceneKitView)
        view.addSubview(buttonBar)
        
        sceneKitView.backgroundColor = UIColor.darkGray
        
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
        
        let queue = OperationQueue.main
        
        motionManager.deviceMotionUpdateInterval = 1 / 30
        
        motionManager.startDeviceMotionUpdates(to: queue) { (deviceMotionData:CMDeviceMotion?, error:Error?) in
            guard let deviceMotionData = deviceMotionData else {return}
            if (self.initialAttitude == nil)
            {
                self.initialAttitude = (deviceMotionData.attitude.roll,
                                        deviceMotionData.attitude.pitch)
            }
            
            self.cameraNode.eulerAngles.y = Float(self.initialAttitude!.roll - deviceMotionData.attitude.roll)
            self.cameraNode.eulerAngles.x = Float(self.initialAttitude!.pitch - deviceMotionData.attitude.pitch)

        }
        
        
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?)
    {
        super.touchesBegan(touches, with: event)
        
        currentDrawingNode = SCNNode(geometry: SCNBox(width: 1, height: 1, length: 0, chamferRadius: 0))
        currentDrawingLayer = CAShapeLayer()
        
        if let currentDrawingNode = currentDrawingNode, let currentDrawingLayer = currentDrawingLayer
        {
            currentDrawingNode.position = SCNVector3(x: 0, y: 0, z: 0)
            
            currentDrawingNode.eulerAngles.x = self.cameraNode.eulerAngles.x
            currentDrawingNode.eulerAngles.y = self.cameraNode.eulerAngles.y
            
            scene.rootNode.addChildNode(currentDrawingNode)

            currentDrawingLayer.strokeColor = UIColor.white.cgColor
            currentDrawingLayer.fillColor = nil
            currentDrawingLayer.lineWidth = 10
            currentDrawingLayer.lineJoin = kCALineJoinRound
            currentDrawingLayer.lineCap = kCALineCapRound
            currentDrawingLayer.frame = CGRect(x: 0, y: 0, width: currentDrawingLayerSize, height: currentDrawingLayerSize)
            
            let material = SCNMaterial()
            
            material.diffuse.contents = currentDrawingLayer
            material.lightingModel = SCNMaterial.LightingModel.constant
            
            currentDrawingNode.geometry?.materials = [material]
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?)
    {
        super.touchesMoved(touches, with: event)
        
        let locationInView = touches.first?.location(in: view)
        
        if let hitTestResult:SCNHitTestResult = sceneKitView.hitTest(locationInView!, options: nil).filter( { $0.node == currentDrawingNode }).first,
            let currentDrawingLayer = currentDrawingLayer
        {
            if currentDrawingLayer.path == nil
            {
                let newX = CGFloat((hitTestResult.localCoordinates.x + 0.5) * Float(currentDrawingLayerSize))
                let newY = CGFloat((hitTestResult.localCoordinates.y + 0.5) * Float(currentDrawingLayerSize))
        
                interpolationPoints = [CGPoint(x: newX, y: newY)]
            }
            
            let newX = CGFloat((hitTestResult.localCoordinates.x + 0.5) * Float(currentDrawingLayerSize))
            let newY = CGFloat((hitTestResult.localCoordinates.y + 0.5) * Float(currentDrawingLayerSize))
   
            interpolationPoints.append(CGPoint(x: newX, y: newY))
            
            hermitePath.removeAllPoints()
            hermitePath.interpolatePointsWithHermite(interpolationPoints)
            
            currentDrawingLayer.path = hermitePath.cgPath
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?)
    {
        super.touchesEnded(touches, with: event)

        currentDrawingLayer = nil
        currentDrawingNode = nil
        
        hermitePath.removeAllPoints()
        interpolationPoints.removeAll()
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
        let toolbarHeight = buttonBar.intrinsicContentSize.height
        
        sceneKitView.frame = CGRect(x: 0, y: topMargin, width: view.frame.width, height: view.frame.height - topMargin - toolbarHeight)
        
        buttonBar.frame = CGRect(x: 0, y: view.frame.height - toolbarHeight, width: view.frame.width, height: toolbarHeight)
    }
    
    override var supportedInterfaceOrientations : UIInterfaceOrientationMask
    {
        return UIInterfaceOrientationMask.portrait
    }
    
}

