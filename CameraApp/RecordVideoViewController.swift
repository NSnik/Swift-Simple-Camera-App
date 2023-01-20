//
//  RecordVideoViewController.swift
//  CameraApp
//
//  Created by Marc Meinhardt on 28.06.20.
//  Copyright © 2020 Marc Meinhardt. All rights reserved.
//

import UIKit
import AVFoundation
import AVKit

class RecordVideoViewController: UIViewController, AVCaptureFileOutputRecordingDelegate {
        
    @IBOutlet weak var recordButton: UIButton!
    
    let captureSession = AVCaptureSession()
    var backCamera: AVCaptureDevice?
    var frontCamera: AVCaptureDevice?
    var currentDevice: AVCaptureDevice?
    var videoFileOutput:AVCaptureMovieFileOutput?
    var cameraPreviewLayer:AVCaptureVideoPreviewLayer?
    
    var isRecording = false
    var toggleCameraGestureRecognizer = UISwipeGestureRecognizer()
    
    var zoomInGestureRecognizer = UISwipeGestureRecognizer()
    var zoomOutGestureRecognizer = UISwipeGestureRecognizer()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        restartCamera()

        toggleCameraGestureRecognizer.direction = .up
        toggleCameraGestureRecognizer.addTarget(self, action: #selector(self.switchCamera))
        view.addGestureRecognizer(toggleCameraGestureRecognizer)
        
        // Zoom In recognizer
        zoomInGestureRecognizer.direction = .right
        zoomInGestureRecognizer.addTarget(self, action: #selector(zoomIn))
        view.addGestureRecognizer(zoomInGestureRecognizer)
        
        // Zoom Out recognizer
        zoomOutGestureRecognizer.direction = .left
        zoomOutGestureRecognizer.addTarget(self, action: #selector(zoomOut))
        view.addGestureRecognizer(zoomOutGestureRecognizer)
    }
    
    func restartCamera(sessionPreset: AVCaptureSession.Preset? = nil) {
        setupCaptureSession(sessionPreset: sessionPreset)
        setupDevice()
        setupInputOutput()
        setupPreviewLayer()
        startRunningCaptureSession()
    }
    
    private func setupCaptureSession(sessionPreset: AVCaptureSession.Preset?) {
        if let sessionPreset = sessionPreset {
            captureSession.sessionPreset = sessionPreset
        } else {
            captureSession.sessionPreset = AVCaptureSession.Preset.high
        }
    }
    
    func setupDevice() {
        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [AVCaptureDevice.DeviceType.builtInTripleCamera, AVCaptureDevice.DeviceType.builtInWideAngleCamera], mediaType: AVMediaType.video, position: AVCaptureDevice.Position.unspecified)
        
        let devices = deviceDiscoverySession.devices
        
        for device in devices {
            if device.position == AVCaptureDevice.Position.back {
                if device.deviceType == AVCaptureDevice.DeviceType.builtInTripleCamera {
                    backCamera = device
                }
                
                if backCamera == nil {
                    backCamera = device
                }
            } else if device.position == AVCaptureDevice.Position.front {
                frontCamera = device
            }
        }
        currentDevice = backCamera
        
    }
    
    func setupInputOutput() {
        do {
            let captureDeviceInput = try AVCaptureDeviceInput(device: currentDevice!)
            if let inputs = captureSession.inputs as? [AVCaptureDeviceInput] {
                for input in inputs {
                    captureSession.removeInput(input)
                }
            }
            captureSession.addInput(captureDeviceInput)
            videoFileOutput = AVCaptureMovieFileOutput()
            if let outputs = captureSession.outputs as? [AVCaptureOutput] {
                for output in outputs {
                    captureSession.removeOutput(output)
                }
            }
            captureSession.addOutput(videoFileOutput!)
        } catch {
            print(error)
        }
    }
    
    func setupPreviewLayer() {
        cameraPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        cameraPreviewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
        cameraPreviewLayer?.connection?.videoOrientation = AVCaptureVideoOrientation.portrait
        cameraPreviewLayer?.frame = self.view.frame
        self.view.layer.insertSublayer(cameraPreviewLayer!, at: 0)
    }
    
    func startRunningCaptureSession() {
        captureSession.startRunning()
    }
    // MARK: - Action methods
    
    @IBAction func unwindToCamera(segue:UIStoryboardSegue) {
        
    }
    
    @IBAction func capture(sender: UIButton) {
        if !isRecording {
            isRecording = true
            
            UIView.animate(withDuration: 0.5, delay: 0.0, options: [.repeat, .autoreverse, .allowUserInteraction], animations: { () -> Void in
                self.recordButton.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
            }, completion: nil)
            
            let outputPath = NSTemporaryDirectory() + "output.mov"
            let outputFileURL = URL(fileURLWithPath: outputPath)
            videoFileOutput?.startRecording(to: outputFileURL, recordingDelegate: self)
        } else {
            isRecording = false
            
            UIView.animate(withDuration: 0.5, delay: 1.0, options: [], animations: { () -> Void in
                self.recordButton.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
            }, completion: nil)
            recordButton.layer.removeAllAnimations()
            videoFileOutput?.stopRecording()
        }
    }
    
    
    // MARK: - AVCaptureFileOutputRecordingDelegate methods
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if error != nil {
            print(error?.localizedDescription)
            return
        }
        
        performSegue(withIdentifier: "playVideo", sender: outputFileURL)
    }
    
    
    
    @objc func switchCamera() {
        captureSession.beginConfiguration()
        
        // Change the device based on the current camera
        let newDevice = (currentDevice?.position == AVCaptureDevice.Position.back) ? frontCamera : backCamera
        
        // Remove all inputs from the session
        for input in captureSession.inputs {
            captureSession.removeInput(input as! AVCaptureDeviceInput)
        }
        
        // Change to the new input
        let cameraInput:AVCaptureDeviceInput
        do {
            cameraInput = try AVCaptureDeviceInput(device: newDevice!)
        } catch {
            print(error)
            return
        }
        
        if captureSession.canAddInput(cameraInput) {
            captureSession.addInput(cameraInput)
        }
        
        currentDevice = newDevice
        captureSession.commitConfiguration()
    }
    
    @objc func zoomIn() {
        if let zoomFactor = currentDevice?.videoZoomFactor {
            if zoomFactor < 5.0 {
                let newZoomFactor = min(zoomFactor + 1.0, 5.0)
                do {
                    try currentDevice?.lockForConfiguration()
                    currentDevice?.ramp(toVideoZoomFactor: newZoomFactor, withRate: 1.0)
                    currentDevice?.unlockForConfiguration()
                } catch {
                    print(error)
                }
            }
        }
    }
    
    @objc func zoomOut() {
        if let zoomFactor = currentDevice?.videoZoomFactor {
            if zoomFactor > 1.0 {
                let newZoomFactor = max(zoomFactor - 1.0, 1.0)
                do {
                    try currentDevice?.lockForConfiguration()
                    currentDevice?.ramp(toVideoZoomFactor: newZoomFactor, withRate: 1.0)
                    currentDevice?.unlockForConfiguration()
                } catch {
                    print(error)
                }
            }
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "playVideo" {
            let videoPlayerViewController = segue.destination as! AVPlayerViewController
            let videoFileURL = sender as! URL
            videoPlayerViewController.player = AVPlayer(url: videoFileURL)
        }
    }
    
    @IBAction func selectQuality() {
        let qualityAlert = UIAlertController(title: "Качество", message: "выберите качество", preferredStyle: UIAlertController.Style.alert)

        qualityAlert.addAction(UIAlertAction(title: "1080", style: .default, handler: { [weak self] (action: UIAlertAction!) in
            self?.restartCamera(sessionPreset: .hd1920x1080)
        }))
        
        qualityAlert.addAction(UIAlertAction(title: "720", style: .default, handler: { [weak self] (action: UIAlertAction!) in
            self?.restartCamera(sessionPreset: .hd1280x720)
        }))
        
        qualityAlert.addAction(UIAlertAction(title: "540", style: .default, handler: { [weak self] (action: UIAlertAction!) in
            self?.restartCamera(sessionPreset: .iFrame960x540)
        }))

        qualityAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))

        present(qualityAlert, animated: true, completion: nil)
    }
    
    
    @IBAction func openPhotoMod(_ sender: Any) {
        let mainStoryboard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
        if let viewController = mainStoryboard.instantiateViewController(withIdentifier: "photoViewController") as? UIViewController {
            UIApplication.shared.windows.first?.rootViewController = viewController
            UIApplication.shared.windows.first?.makeKeyAndVisible()
        }
    }
    
}
