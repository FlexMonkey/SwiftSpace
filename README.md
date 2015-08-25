# SwiftSpace
Gyroscope Driven Drawing in 3D Space
 
Companion project to: http://flexmonkey.blogspot.co.uk/2015/08/coremotion-controlled-3d-sketching-on.html

I was really impressed by a demo of InkScape that I read about in Creative Applications recently. InkScape is an Android app which allows users to sketch in a 3D space that's controlled by the device's accelerometer. It's inspired by Rhonda which pre-dates accelerometers and uses a trackball instead.

Of course, my first thought was, "how can I do this in Swift?". I've never done any work with CoreMotion before, so this was a good opportunity to learn some new stuff. My first port of call was this excellent article on iOS motion at NSHipster.

My plan for the application was to have a SceneKit scene with a motion controlled camera rotating around an offset pivot point at the centre of the SceneKit world. With each touchesBegan(), I'd create a new flat box in the centre of the screen that aligned with the camera and on touchesMoved(), I'd use the touch location to append to a path that I'd draw onto a CAShapeLayer that I'd use as the diffuse material for the newly created geometry. 

Easy! Let's break it down:

## Creating the Camera

I wanted the camera at to always point at and rotate around the centre of the world while being slightly offset from it. The two things to help this are the camera's pivot property and using a "look at constraint". First off, I create a node to represent the centre of the world and the camera itself:

```swift
    let centreNode = SCNNode()
    centreNode.position = SCNVector3(x: 0, y: 0, z: 0)
    scene.rootNode.addChildNode(centreNode)

    let camera = SCNCamera()
    camera.xFov = 20

    camera.yFov = 20
```

Next, an SCNLookAtConstraint means that however I translate the camera, it will always point at the centre:

```swift
    let constraint = SCNLookAtConstraint(target: centreNode)
    cameraNode.constraints = [constraint]
```

...and finally, setting the camera's pivot will reposition it but have it rotate around the centre of the world: 

```swift
    cameraNode.pivot = SCNMatrix4MakeTranslation(0, 0, -cameraDistance)
```

## Handling iPhone Motion

Next up is handling the iPhone's motion to rotate the camera. Remembering that the iPhone's roll is its rotation along the front-to-back axis and its pitch is its rotation along its side-to-side axis:

...I'll use those properties to control my camera's x and y Euler angles.

The first step is to create an instance of CMMotionManager and ensure it's available and working (so this code won't work on the simulator):

```swift
    let motionManager = CMMotionManager()
        
    guard motionManager.gyroAvailable else
    {
        fatalError("CMMotionManager not available.")

    }
```

Next up, I start the motion manager with a little block of code that's invoked with each update. I use a tuple to store the initial attitude of the iPhone and simple use the difference between that initial value and the current attitude to set the camera's Euler angles:

```swift
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
```

##Drawing in 3D

Since I know the angles of my camera, it's pretty simple to align the target geometry for drawing on the touchesBegan() method - it just shares the same attitude:

```swift
    currentDrawingNode = SCNNode(geometry: SCNBox(width: 1, height: 1, length: 0, chamferRadius: 0))

    currentDrawingNode.eulerAngles.x = self.cameraNode.eulerAngles.x
    currentDrawingNode.eulerAngles.y = self.cameraNode.eulerAngles.y
```

At the same time, I create a new CAShapeLayer that will contain a stroked path that follows the user's finger:

```swift
    currentDrawingLayer = CAShapeLayer()

    let material = SCNMaterial()

    material.diffuse.contents = currentDrawingLayer
    material.lightingModelName = SCNLightingModelConstant
            

    currentDrawingNode.geometry?.materials = [material]
```

On touchesMoved(), I need to convert the location in the main view to the location on the geometry. Since this geometry has a size of 1 x 1 (from -0.5 through 0.5 in both directions), I'll need to convert that to coordinates in my CAShapeLayer (arbitrarily set to 512 x 512) to add points its path.   

There are a few steps to do this, taking the locationInView() of the first item in the touches set, I pass it into hitTest()  on my SceneKit scene. This returns an array of SCNHitTestResults for all the geometries underneath the touch which I filter for the current geometry and then simply rescale the result's localCoordinates to find the coordinates on the current CAShapeLayer:

```swift
    let locationInView = touches.first?.locationInView(view)

    if let hitTestResult:SCNHitTestResult = sceneKitView.hitTest(locationInView!, options: nil).filter( { $0.node == currentDrawingNode }).first,
        currentDrawingLayer = currentDrawingLayer

    {
        let drawPath = UIBezierPath(CGPath: currentDrawingLayer.path!)

        let newX = CGFloat((hitTestResult.localCoordinates.x + 0.5) * Float(currentDrawingLayerSize))
        let newY = CGFloat((hitTestResult.localCoordinates.y + 0.5) * Float(currentDrawingLayerSize))
        
        drawPath.addLineToPoint(CGPoint(x: newX, y: newY))
        
        currentDrawingLayer.path = drawPath.CGPath
    }
```

...and that's kind of it! 

The source code to this project is available here at my GitHub repository. It was developed under Xcode 7 beta 5 and tested on my iPhone 6 running iOS 8.4.1.
