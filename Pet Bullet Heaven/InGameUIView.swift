//
//  InGameUIView.swift
//  Pet Bullet Heaven
//
//  Created by Delaine on 2024-02-08.
//

import UIKit
import Foundation

class InGameUIView: UIView {
    var pauseButtonTappedHandler: (() -> Void)?
    var nextStageButtonTappedHandler: (() -> Void)?
    var isStickVisible = false
    private var innerCircleLayer: CAShapeLayer?
    private var outerCircleLayer: CAShapeLayer?
    
    private var _hungerScore: Int = 0
    private var _maxHungerScore: Int = Globals.defaultMaxHungerScore
    private var _stageCount: Int = 0
    
    // variable getters
    public var getHungerScore: Int {
        get { return _hungerScore }
    }
    public var getMaxHungerScore: Int {
        get { return _maxHungerScore }
    }
    public var getStageCount: Int {
        get { return _stageCount }
    }
    
    lazy var pauseButton: UIButton = {
        let button = Utilities.makeButton(title: "Pause", image: UIImage(named: "cloud_yellow.png"), backgroundColor: .blue, target: self, action: #selector(pauseButtonTapped))
        return button
    }()
    
    lazy var nextStageButton: UIButton = {
        let button = Utilities.makeButton(title: "Next Stage", image: UIImage(named: "cloud_teal.png"), backgroundColor: .blue, target: self, action: #selector(nextStageButtonTapped))
        button.isHidden = true
        return button
    }()
    
    lazy var hungerMeter: UIProgressView = {
        let hungerMeterBar = UIProgressView(progressViewStyle: .bar)
        hungerMeterBar.progress = 0
        hungerMeterBar.layer.cornerRadius = 5
        hungerMeterBar.layer.masksToBounds = true
        hungerMeterBar.progressTintColor = .yellow
        hungerMeterBar.trackTintColor = .darkGray
        return hungerMeterBar
    }()
    
    lazy var hungerScoreLabel: UILabel = {
        let scoreLabel = UILabel()
        scoreLabel.text = "Score: \(_hungerScore) / \(_maxHungerScore)"
        scoreLabel.font = UIFont.systemFont(ofSize: 18)
        scoreLabel.textColor = .white
        return scoreLabel
    }()
    
    lazy var stageCountLabel: UILabel = {
        let stageCountLabel = UILabel()
        stageCountLabel.text = "Stage: \(_stageCount)"
        stageCountLabel.font = UIFont.systemFont(ofSize: 18)
        stageCountLabel.textColor = .white
        return stageCountLabel
    }()
    
    public lazy var stageClearLabel: UILabel = {
        let stageClearLabel = UILabel()
        stageClearLabel.text = "Stage \(_stageCount) Cleared!"
        let font = UIFont.systemFont(ofSize: 48)
        let textColor = UIColor.white
        
        let strokeColor = UIColor.black
        let strokeWidth = -1.0
        
        // Using NSAttributedString to set stroke
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
            .strokeColor: strokeColor,
            .strokeWidth: strokeWidth
        ]

        let attributedString = NSAttributedString(string: "Stage \(_stageCount) Cleared!", attributes: attributes)
        stageClearLabel.attributedText = attributedString
        
        return stageClearLabel
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    /// Adds a given hunger value to the hunger score.
    public func addToHungerMeter(hungerValue: Int) {
        updateHunger(newHungerValue: _hungerScore + hungerValue)
        
        var totalScore = UserDefaults.standard.integer(forKey: Globals.totalScoreKey)
        totalScore += hungerValue
        UserDefaults.standard.set(totalScore, forKey: Globals.totalScoreKey)
        
        // fill hunger meter (up to full at maxHungerScore)
        if (_hungerScore <= _maxHungerScore) {
            // animate the hunger meter filling up to new value
            let progress = Float(min(_hungerScore, _maxHungerScore)) / Float(_maxHungerScore)
            hungerMeter.setProgress(progress, animated: true)
        } else {
            let progress = Float(min(_maxHungerScore, _maxHungerScore)) / Float(_maxHungerScore)
            hungerMeter.setProgress(progress, animated: true)
        }
        stageProgressCheck()
    }
    
    /// Sets hunger score to the given hungerValue.
    public func setHungerMeter(hungerValue: Int) {
        updateHunger(newHungerValue: hungerValue)
        hungerMeter.setProgress(Float(hungerValue)/Float(_maxHungerScore), animated: false)
        stageProgressCheck()
    }

    /// Set stage count and update its UI given its value.
    public func setStageCount(stageCount: Int) {
        _stageCount = stageCount
        stageCountLabel.text = "Stage: \(_stageCount)"
    }

    /// Puts UI stick positions at the given location converted into the UI coordinate system. 
    public func setStickPosition(location: CGPoint) {
        let anchorPoint = convertGestureCoordinateSystemToUICoordinateSystem(point: location)
        
        innerCircleLayer?.position = anchorPoint
        outerCircleLayer?.position = anchorPoint
    }
    
    /// Updates the joystick's position (inner circle) to a given point.
    // Source: https://betterprogramming.pub/creating-a-joystick-control-in-swiftui-6c63d713ab9
    public func updateStickPosition(fingerLocation: CGPoint) {
        let outerPosition = outerCircleLayer?.position
        
        // get diameters of both circles and subtract to get range of which the inner circle may move
        let innerDiameter = max((innerCircleLayer?.path?.boundingBox.width)!, (innerCircleLayer?.path?.boundingBox.height)!)
        let outerDiameter = max((outerCircleLayer?.path?.boundingBox.width)!, (outerCircleLayer?.path?.boundingBox.height)!)
        let thumbStickRange = (outerDiameter - innerDiameter) / 2
        let translatedFingerPos = convertGestureCoordinateSystemToUICoordinateSystem(point: fingerLocation)
        
        // distance b/w finger-hold location and middle of thumbstick
        let distance = calculateDistanceBetweenPoints(point1: outerPosition!, point2: translatedFingerPos)
        
        // Get angle b/w center of thumbstick and finger
        let angle = atan2(translatedFingerPos.y - outerPosition!.y, translatedFingerPos.x - outerPosition!.x)
        let clamp = min(distance, thumbStickRange)
        
        // new coordinates of inner circle
        let newX = outerPosition!.x + cos(angle) * clamp
        let newY = outerPosition!.y + sin(angle) * clamp
        
        innerCircleLayer?.position = CGPoint(x: newX, y: newY)
    }

    /// Set the visibility of the joystick UI.
    public func stickVisibilty(isVisible: Bool) {
        innerCircleLayer?.isHidden = !isVisible
        outerCircleLayer?.isHidden = !isVisible
    }

    /// Translate gesture plot to UI kit plot.
    private func convertGestureCoordinateSystemToUICoordinateSystem(point: CGPoint) -> CGPoint {
        let xPoint = point.x - bounds.maxX/2
        let yPoint = point.y - bounds.maxY/2
        return CGPoint(x: xPoint, y: yPoint)
    }
    
    /// Can be a public func in a static math helper class
    private func calculateDistanceBetweenPoints(point1: CGPoint, point2: CGPoint) -> CGFloat {
        let dx = point2.x - point1.x
        let dy = point2.y - point1.y
        return sqrt(dx * dx + dy * dy)
    }
    
    /// Triggers stage progression button if the hunger score meets requirements to progress to next stage.
    private func stageProgressCheck() {
        if (_hungerScore >= _maxHungerScore && nextStageButton.isHidden == true) {
            // maybe have a fade-in animation?
            nextStageButton.isHidden = false
        }
    }
    
    private func setupUI() {
        // for debugging, comment line below out for working persistent data
        Utilities.initUserData()
        
        // Load hunger score from persistent storage
        let savedHungerScore = UserDefaults.standard.integer(forKey: Globals.stageScoreKey)
        let currMaxScore = UserDefaults.standard.integer(forKey: Globals.stageMaxScorekey)
        if (currMaxScore != 0) {
            _maxHungerScore = currMaxScore
        }
        setHungerMeter(hungerValue: savedHungerScore)
        setStageCount(stageCount: UserDefaults.standard.integer(forKey: Globals.stageCountKey))
        
        addSubview(pauseButton)
        addSubview(nextStageButton)
        addSubview(hungerMeter)
        addSubview(hungerScoreLabel)
        addSubview(stageCountLabel)
        addSubview(stageClearLabel)
        
        stageClearLabel.isHidden = true
            
        // Layout constraints for pause button
        pauseButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            pauseButton.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 20),
            pauseButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            pauseButton.widthAnchor.constraint(equalToConstant: 99),
            pauseButton.heightAnchor.constraint(equalToConstant: 66)
        ])
        
        // Layout constraints for next stage button
        nextStageButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            nextStageButton.topAnchor.constraint(equalTo: hungerMeter.bottomAnchor, constant: 10),
            nextStageButton.centerXAnchor.constraint(equalTo: hungerMeter.centerXAnchor),
            nextStageButton.widthAnchor.constraint(equalToConstant: 150),
            nextStageButton.heightAnchor.constraint(equalToConstant: 100),
        ])
        
        // Layout constraints for score label
        hungerScoreLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hungerScoreLabel.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 5),
            hungerScoreLabel.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 30),
        ])
        
        // Layout constraints for stage label
        stageCountLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stageCountLabel.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 5),
            stageCountLabel.leadingAnchor.constraint(equalTo: hungerScoreLabel.leadingAnchor, constant: 150),
        ])
        
        // Layout constraints for hunger meter
        hungerMeter.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hungerMeter.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 30),
            hungerMeter.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 20),
            hungerMeter.widthAnchor.constraint(equalToConstant: 240),
            hungerMeter.heightAnchor.constraint(equalToConstant: 10),
        ])
        
        // Layout constraints for stage clear label
        stageClearLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stageClearLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            stageClearLabel.centerYAnchor.constraint(equalTo: centerYAnchor, constant: 200)
        ])
        
        let innerCirclePath = UIBezierPath(arcCenter: CGPoint(x: bounds.midX+200, y: bounds.midY+400), radius: 30, startAngle: 0, endAngle: CGFloat(2*Double.pi), clockwise: true)
        
        // inner circle drawing
        innerCircleLayer = CAShapeLayer()
        innerCircleLayer?.opacity = 0.6
        innerCircleLayer?.path = innerCirclePath.cgPath
        
        innerCircleLayer?.fillColor = UIColor.lightGray.cgColor
        
        // outer circle drawing
        let outerCirclePath = UIBezierPath(arcCenter: CGPoint(x: bounds.midX+200, y: bounds.midY+400), radius: 50, startAngle: 0, endAngle: CGFloat(2*Double.pi), clockwise: true)
        outerCircleLayer = CAShapeLayer()
        outerCircleLayer?.strokeColor = UIColor.black.cgColor
        outerCircleLayer?.lineWidth = 3
        outerCircleLayer?.fillColor = nil
        outerCircleLayer?.path = outerCirclePath.cgPath
        
        // add circles as sublayers
        layer.addSublayer(innerCircleLayer!)
        layer.addSublayer(outerCircleLayer!)
        innerCircleLayer?.isHidden = true
        outerCircleLayer?.isHidden = true
        
    }
    
    @objc private func pauseButtonTapped() {
        pauseButtonTappedHandler?()
    }
    
    /// Set hunger score to the given value. 
    private func updateHunger(newHungerValue: Int) {
        _hungerScore = newHungerValue
        hungerScoreLabel.text = "Score: \(_hungerScore) / \(_maxHungerScore)"
        // Save stage and total hunger score persistently
        UserDefaults.standard.set(_hungerScore, forKey: Globals.stageScoreKey)
    }
    
    /// Resets the hunger score and its meter.
    public func resetHunger() {
        updateHunger(newHungerValue: 0)
        hungerMeter.progress = 0
    }
    
    /// Sets new hunger score and max score.
    public func increaseMaxHungerScore() {
        let increasedScore = Float(_maxHungerScore) * Globals.maxHungerScoreMultiplier
        _maxHungerScore = Int(increasedScore)
        UserDefaults.standard.set(_maxHungerScore, forKey: Globals.stageMaxScorekey)
        hungerScoreLabel.text = "Score: \(_hungerScore) / \(_maxHungerScore)"
        stageClearLabel.text = "Stage \(_stageCount) Cleared!"
    }
    
    @objc private func nextStageButtonTapped() {
        nextStageButtonTappedHandler?()
    }
}
