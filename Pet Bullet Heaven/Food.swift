//
//  Food.swift
//  Pet Bullet Heaven
//
//  Created by Jun Solomon on 2024-02-14.
//

import Foundation
import SceneKit

///
/// Rudimentary Food Class
///
class Food : SCNNode {
    
    var _Health : Int = 1
    
    var _Mesh : SCNBox?
    
    override init() {
        super.init()
        let cubeGeometry = SCNBox(width: 0.7, height: 0.7, length: 0.7, chamferRadius: 0.2)
        
        let cubeNode = SCNNode(geometry: cubeGeometry)
        
        // will be changed to whatever the model is
        cubeNode.geometry?.firstMaterial?.diffuse.contents = UIImage(named: "art.scnassets/goldblock.png")
        
        // not sure if we put it here or in gameviewcontroller
        cubeNode.position = SCNVector3(0, 0.5, 0)
        
        let angleInDegrees: Float = 45.0
        let angleInRadians = angleInDegrees * .pi / 180.0
        cubeNode.eulerAngles = SCNVector3(0, angleInRadians, 0)
        self.addChildNode(cubeNode)
        
        self._Mesh = cubeGeometry
        
        
        Task {
            await firstUpdate()
        }
        
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // TODO: add modifiable duration and increment
    func Move(increment: CGFloat) {
        let moveAction = SCNAction.moveBy(x: increment, y: 0, z: 0, duration: 0.5)
        let repeatAction = SCNAction.repeatForever(moveAction)
        self.runAction(repeatAction)
    }
    
    func firstUpdate() async {
        await reanimate() // Call reanimate on the first graphics update frame
    }
    
    // Your 'Update()' function
    @MainActor
    func reanimate() async {
        // code logic here
        
        // Repeat increment 'reanimate()' every 1/60 of a second (60 frames per second)
        try! await Task.sleep(nanoseconds: UInt64(1.0 / 60.0))
        await reanimate()
    }
}
