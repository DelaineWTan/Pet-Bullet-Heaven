//
//  GameViewController.swift
//  Pet Bullet Heaven
//
//  Created by Delaine on 2024-02-05.
//

import UIKit
import QuartzCore
import SceneKit
import AVFoundation

class GameViewController: UIViewController, SCNPhysicsContactDelegate, SceneProvider{
    let soundManager = SoundManager()
    let overlayView = GameUIView()

    // Camera node
    let cameraNode = SCNNode()
    
    // categories for object types
    let playerCategory: Int = 1
    let foodCategory: Int = 2
    
    var playerNode: SCNNode?
    var stageNode: SCNNode?
    var map: Map?
    
    var isMoving = false
    var touchDestination: CGPoint? = nil
    
    // radius for the joystick input
    var joyStickClampedDistance: CGFloat = 100
    
    let testAbility = OrbitingProjectileAbility(_InputAbilityDamage: 1, _InputAbilityDuration: 10, _InputRotationSpeed: 20, _InputDistanceFromCenter: 10, _InputNumProjectiles: 5)

    // create a new scene
    let mainScene = SCNScene(named: "art.scnassets/main.scn")!
    
    // Floating damage text
    let floatingText = FloatingDamageText()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        Task {
            await StartLoop()
        }
        
        
        // retrieve the SCNView
        let scnView = self.view as! SCNView
        
        // set the scene to the view
        scnView.scene = mainScene
        
        // set delegate to GameUIView
        overlayView.delegate = self
        
        mainScene.physicsWorld.contactDelegate = self
        
        // show statistics such as fps and timing information
        scnView.showsStatistics = true
        // show debug options
        scnView.debugOptions = [
            SCNDebugOptions.showPhysicsShapes
        ]
        // configure the view
        scnView.backgroundColor = UIColor.black
        
        // Add overlay view
        overlayView.frame = scnView.bounds
        overlayView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scnView.addSubview(overlayView)
        // add self rendering every frame logic
                
        // add a tap gesture recognizer
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        scnView.addGestureRecognizer(tapGesture)
        
        // add panning gesture for pet movement
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handleMovementPan(_:)))
        scnView.addGestureRecognizer(panGesture)
        
        // get player
        playerNode = mainScene.rootNode.childNode(withName: "mainPlayer", recursively: true)
        
        // get stage plane
        stageNode = mainScene.rootNode.childNode(withName: "stagePlane", recursively: true)
        map = Map(stageNode: stageNode!, playerNode: playerNode!)
        
        // spawn the initial attack patterns of active pets to game
        for petIndex in 0...((Globals.activePets.count) - 1) {
            // Add attack pattern into scene
            let testAbility = Globals.activePets[petIndex].attackPattern
            let abilityClone = testAbility.copy() as! Ability
            _ = abilityClone.ActivateAbility()
            abilityClone.name = Globals.petAbilityNodeName[petIndex]
            playerNode?.addChildNode(abilityClone)
        }
    
        _ = FoodSpawner(scene: mainScene)
        _ = FoodSpawner(scene: mainScene)
        
        // Add floating damage text
        scnView.addSubview(floatingText)
    }
    
    ///
    ///START OF PHYSICS STUFF (faiz)
    ///
    
    var nodeA : SCNNode? = SCNNode()
    var nodeB : SCNNode? = SCNNode()
    
    // food cooldown duration (in seconds)
    let foodHitCooldown: TimeInterval = 0.5

    // dictionary to track the cooldown time for each food item using their UUIDs
    var foodCooldowns: [UUID: TimeInterval] = [:]
    
    func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
        nodeA = contact.nodeA
        nodeB = contact.nodeB
    }
    
    //DO PHYSICS
    func doPhysics() {
        // Check if player collides with food or vice versa
        if let food = checkFoodCollision() {
            // Check if the food item is not on cooldown or the cooldown has expired
            if !isFoodOnCooldown(food) {
                applyDamageToFood(food)
                startCooldown(for: food)
            }
        }
        nodeA = nil
        nodeB = nil
        
    }
    
    //check which node is the food node and return it
    func checkFoodCollision() -> Food? {
        if (nodeA?.physicsBody?.categoryBitMask == playerCategory && nodeB?.physicsBody?.categoryBitMask == foodCategory) {
            return nodeB as? Food
        } else if (nodeA?.physicsBody?.categoryBitMask == foodCategory && nodeB?.physicsBody?.categoryBitMask == playerCategory) {
            return nodeA as? Food
        }
        return nil
    }
    
    //check if the collided food is currently on cooldown
    func isFoodOnCooldown(_ food: Food) -> Bool {
        if let lastHitTime = foodCooldowns[food.uniqueID] {
            return Date().timeIntervalSince1970 - lastHitTime < foodHitCooldown
        }
        return false
    }
    
    //start the cool down for colliding food
    func startCooldown(for food: Food) {
        foodCooldowns[food.uniqueID] = Date().timeIntervalSince1970
    }

    //use the ability to deal damage to the colliding food item
    func applyDamageToFood(_ food: Food) {
        food._Health -= testAbility._AbilityDamage!

        if food._Health <= 0 {
            overlayView.inGameUIView.addToHungerMeter(hungerValue: food.hungerValue)
            food.onDestroy(after: 0)
            soundManager.refreshEatingSFX()
        }
    }
    
    ///
    ///END OF PHYSICS STUFF
    ///
    
    func StartLoop() async {
        await ContinuousLoop()
    }
    
    @MainActor
    func ContinuousLoop() async {
        
        // read from thread-safe queue of to-be-deleted UUIDs
        LifecycleManager.Instance.update()
        doPhysics()
        // Repeat increment 'reanimate()' every 1/60 of a second (60 frames per second)
        try! await Task.sleep(nanoseconds: 1_000_000_000 / 60)
        await ContinuousLoop()
    }
    
    @objc
    func handleTap(_ gestureRecognize: UIGestureRecognizer) {
        // retrieve the SCNView
        let scnView = self.view as! SCNView
        
        // check what nodes are tapped
        let p = gestureRecognize.location(in: scnView)
        let hitResults = scnView.hitTest(p, options: [:])
        
        // check that we clicked on at least one object
        guard hitResults.count > 0, let result = hitResults.first else {
            return
        }
        
        // get its material
        let material = result.node.geometry!.firstMaterial!
        
        // Play duck sound if duck is tapped @TODO identify pet more reliably
        if (result.node.name == "Cube-002") {
            soundManager.playTapSFX()
        }
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.5
        
        // on completion - unhighlight
        SCNTransaction.completionBlock = {
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.5
            
            material.emission.contents = UIColor.black
            
            SCNTransaction.commit()
        }
        
        material.emission.contents = UIColor.red
        
        SCNTransaction.commit()
    }
    
    var intialCenter = CGPoint()
    
    @objc
    func handleMovementPan(_ gestureRecongnize: UIPanGestureRecognizer) {
        // Gets x, y values of pan. Does not return any when not detecting finger moving
        // Prob need to clamp it, have to create a helper method
        let translation = gestureRecongnize.translation(in: view)
        let location = gestureRecongnize.location(in: view)
        
        switch gestureRecongnize.state {
        case .began:
            Globals.playerIsMoving = true
            overlayView.inGameUIView.setStickPosition(location: location)
        case .changed:

            let x = translation.x.clamp(min: -joyStickClampedDistance, max: joyStickClampedDistance) / joyStickClampedDistance
            let z = translation.y.clamp(min: -joyStickClampedDistance, max: joyStickClampedDistance) / joyStickClampedDistance
            // Normalize xz vector so diagonal movement equals 1
            let length = sqrt(pow(x, 2) + pow(z, 2))
            Globals.inputX = x / length * 2 // TODO add speed mod
            Globals.inputZ = z / length * 2// TODO add speed mod
            
            print(Globals.inputX)
            print(Globals.inputZ)
            // Stick UI
            overlayView.inGameUIView.stickVisibilty(isVisible: true)
            overlayView.inGameUIView.updateStickPosition(fingerLocation: location)
        case .ended:
            Globals.playerIsMoving = false
            overlayView.inGameUIView.stickVisibilty(isVisible: false)
        default:
            break
        }
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom == .phone {
            return .allButUpsideDown
        } else {
            return .all
        }
    }

    func getSceneNode() -> SCNNode? {
        return mainScene.rootNode
    }
}

protocol SceneProvider: AnyObject {
    func getSceneNode() -> SCNNode?
}
