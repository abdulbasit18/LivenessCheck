//
//  ViewController.swift
//  LivenessCheck-MLKIT
//
//  Created by Abdul Basit on 17/06/2020.
//  Copyright © 2020 Abdul Basit. All rights reserved.
//

import Foundation
import UIKit
import Firebase
import CoreMedia

final internal class LivenessCheckViewController: UIViewController {
    
    // MARK: - Outlets
    @IBOutlet weak private var stepIndicator: UILabel!
    @IBOutlet weak private var counterLabel: UILabel!
    @IBOutlet weak private var tableView: UITableView!
    @IBOutlet weak private var videoPreview: UIView!
    
    // MARK: - Properties
    private var videoCapture: CameraPreview!
    private var faceDetector: VisionFaceDetector!
    private var timer: Timer?
    private var remainingTime = 0
    private var currentStep = 1
    private let options = VisionFaceDetectorOptions()
    private lazy var vision = Vision.vision()
    private var initialEyeDetect: String?
    
    public var callback: ((_ isSuccess: Bool, _ error: NSError?) -> Void)?
    
    // MARK: - Data
    
    private var detectionOptions = [" 👱🏻‍♂️ Single Face Detection",
                                    " 👀 Blinking",
                                    " 👉🏻 Look Right",
                                    " 👈🏻 Look Left",
                                    " 🙂 Smile :)"]
    private var completedSteps =  [Int]()
    
    // MARK: - Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .dark
        options.performanceMode = .fast
        options.landmarkMode = .all
        options.classificationMode = .all
        options.minFaceSize = CGFloat(0.1)
        faceDetector = vision.faceDetector(options: options)
        setUpCamera()
        stepIndicator.layer.masksToBounds = true
        stepIndicator.clipsToBounds = true
        stepIndicator.layer.cornerRadius = 20
        stepIndicator.text = detectionOptions.first
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.prefersLargeTitles = false
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.navigationBar.prefersLargeTitles = true
    }
    
    // MARK: - SetUp Video
    private func setUpCamera() {
        videoCapture = CameraPreview()
        videoCapture.delegate = self
        videoCapture.fps = 5
        videoCapture.setUp(sessionPreset: .vga640x480) { success in
            if success {
                // add preview view on the layer
                if let previewLayer = self.videoCapture.previewLayer {
                    self.videoPreview.layer.addSublayer(previewLayer)
                    self.resizePreviewLayer()
                }
                // start video preview when setup is done
                self.videoCapture.start()
            }
        }
    }
    
    private func resizePreviewLayer() {
        videoCapture.previewLayer?.frame = videoPreview.bounds
    }
    
    // MARK: - Actions
    
    @IBAction private func restartAction(_ sender: Any) {
        invalidateAll()
    }
    
    // Remove All Checks
    private func invalidateAll() {
        currentStep = 1
        stepIndicator.text = detectionOptions.first
        timer?.invalidate()
        if completedSteps.count > 1 {
            let alertC = UIAlertController(title: "Error",
                                           message: "Movement during the Liveness check is not Allowed",
                                           preferredStyle: .alert)
            let action = UIAlertAction(title: "Ok", style: .cancel, handler: nil)
            alertC.addAction(action)
            
            self.present(alertC, animated: true, completion: nil)
            
        }
        completedSteps.removeAll()
        tableView.reloadData()
        counterLabel.text = ""
    }
    
    // Setup New Checks
    private func setupAutoDetection() {
        if completedSteps.count != detectionOptions.count {
            counterLabel.isHidden = false
            counterLabel.text = ""
            currentStep = randomStepGenerator()
            stepIndicator.text = detectionOptions[currentStep - 1]
            setupMonitor()
        } else {
            counterLabel.isHidden = true
            counterLabel.text = ""
            stepIndicator.text = "Done ✅"
            timer?.invalidate()
            self.callback?(true, nil)
        }
    }
    
    // Checks Time Management
    private func setupMonitor() {
        remainingTime = 10
        counterLabel.text = "10"
        timer?.invalidate()
        
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] (_) in
            self?.remainingTime -= 1
            self?.counterLabel.text = "\(self?.remainingTime ?? 0)"
            if self?.remainingTime == 0 {
                self?.invalidateAll()
            }
        }
    }
    
    //Random Check Generator
    private func randomStepGenerator () -> Int {
        let newStep = Int(arc4random_uniform(UInt32(detectionOptions.count))) + 1
        if completedSteps.contains(newStep) || newStep == 0 {
            return randomStepGenerator()
        } else {
            return newStep
        }
    }
    
    // MARK: - Detection Checks
    
    private func detectFace(_ pickedImage: UIImage) {
        let visionImage = VisionImage(image: pickedImage)
        faceDetector.process(visionImage) { [weak self] (faces, error) in
            
            guard let self = self, error == nil else {
                return
            }
            // Detect Face
            guard let faces = faces, !faces.isEmpty, faces.count == 1, let face = faces.first else {
                self.invalidateAll()
                return
            }
            
            self.validateLiveness(face)
        }
    }
    
    private func validateLiveness(_ face: VisionFace) {
        
        if self.currentStep == 1 { // Face Check
            self.completedSteps.append(1)
            self.tableView.reloadRows(at: [IndexPath(row: 0, section: 0)], with: .automatic)
            self.setupAutoDetection()
        } else if self.currentStep == 2 { // Blinking Check
            if face.leftEyeOpenProbability < 0.4 || face.rightEyeOpenProbability < 0.4 {
                if self.initialEyeDetect == nil {
                    self.initialEyeDetect = "Blinking"
                } else {
                    self.completedSteps.append(2)
                    self.tableView.reloadRows(at: [IndexPath(row: 1, section: 0)], with: .automatic)
                    self.setupAutoDetection()
                }
            }
        } else if self.currentStep == 3 { // Look Left Check
            if face.headEulerAngleY < -35 {
                self.completedSteps.append(3)
                self.tableView.reloadRows(at: [IndexPath(row: 2, section: 0)], with: .automatic)
                self.setupAutoDetection()
            }
        } else if self.currentStep == 4 { // Look Right Check
            if face.headEulerAngleY > 35 {
                self.completedSteps.append(4)
                self.tableView.reloadRows(at: [IndexPath(row: 3, section: 0)], with: .automatic)
                self.setupAutoDetection()
            }
        } else if self.currentStep == 5 { // Smile Check
            if face.smilingProbability > 0.3 {
                self.completedSteps.append(5)
                self.tableView.reloadRows(at: [IndexPath(row: 4, section: 0)], with: .automatic)
                self.setupAutoDetection()
            }
        }
    }
    
}

// MARK: - Video Delegate

extension LivenessCheckViewController: CameraPreviewDelegate {
    func videoCapture(_ capture: CameraPreview, didCaptureVideoFrame pixelBuffer: CVPixelBuffer?, timestamp: CMTime) {
        // the captured image from camera is contained on pixelBuffer
        if let pixelBuffer = pixelBuffer {
            //Stops detecting if all check are completed
            if completedSteps.count != detectionOptions.count {
                self.predictUsingVision(pixelBuffer: pixelBuffer)
            }
        }
    }
}

// MARK: - Pridict Images

extension LivenessCheckViewController {
    
    private func predictUsingVision(pixelBuffer: CVPixelBuffer) {
        let ciimage: CIImage = CIImage(cvImageBuffer: pixelBuffer)
        // crop found word
        let ciContext = CIContext()
        guard let cgImage: CGImage = ciContext.createCGImage(ciimage, from: ciimage.extent) else {
            // end of measure
            return
        }
        let uiImage: UIImage = UIImage(cgImage: cgImage)
        // predict!
        detectFace(uiImage)
    }
}

// MARK: - TableView Delegates

extension LivenessCheckViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return detectionOptions.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell")
            ?? (UITableViewCell(style: .default, reuseIdentifier: "cell"))
        cell.textLabel?.text = detectionOptions[indexPath.row]
        cell.textLabel?.font = UIFont.systemFont(ofSize: 15)
        if completedSteps.contains(indexPath.row + 1) {
            cell.accessoryType = .checkmark
        } else {
            cell.accessoryType = .none
        }
        return cell
    }
    
}
