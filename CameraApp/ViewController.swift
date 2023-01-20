//
//  ViewController.swift
//  CameraApp
//
//  Created by Marc Meinhardt on 26.06.20.
//  Copyright © 2020 Marc Meinhardt. All rights reserved.
//

import UIKit
import AVFoundation
import VisionKit

class ViewController: UIViewController, UIGestureRecognizerDelegate {

    // source: https://www.youtube.com/watch?v=YxiE-2fTbeI
    
    var captureSession = AVCaptureSession()
    var backCamera: AVCaptureDevice?
    var frontCamera: AVCaptureDevice?
    var currentCamera: AVCaptureDevice?
    
    var photoOutput: AVCapturePhotoOutput?
    
    var toggleCameraGestureRecognizer = UISwipeGestureRecognizer()
    
    var zoomInGestureRecognizer = UISwipeGestureRecognizer()
    var zoomOutGestureRecognizer = UISwipeGestureRecognizer()
    
    var image: UIImage?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
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
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTapToFocus))
        tap.delegate = self
        view.addGestureRecognizer(tap)
    }
    
    func restartCamera(sessionPreset: AVCaptureSession.Preset? = nil) {
        setupCaptureSession(sessionPreset: sessionPreset)
        setupDevice()
        setupInputOutput()
        setupPreviewLayer(sessionPreset: sessionPreset)
        startRunningCaptureSession()
    }
    
    private func setupCaptureSession(sessionPreset: AVCaptureSession.Preset?) {
        if let sessionPreset = sessionPreset {
            captureSession.sessionPreset = sessionPreset
        } else {
            captureSession.sessionPreset = AVCaptureSession.Preset.photo
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
        currentCamera = backCamera
    }
    
    func setupInputOutput() {
        do {
            let captureDeviceInput = try AVCaptureDeviceInput(device: currentCamera!)
            if let inputs = captureSession.inputs as? [AVCaptureDeviceInput] {
                for input in inputs {
                    captureSession.removeInput(input)
                }
            }
            captureSession.addInput(captureDeviceInput)
            photoOutput = AVCapturePhotoOutput()
            if let outputs = captureSession.outputs as? [AVCaptureOutput] {
                for output in outputs {
                    captureSession.removeOutput(output)
                }
            }
            photoOutput?.setPreparedPhotoSettingsArray([AVCapturePhotoSettings(format: [AVVideoCodecKey : AVVideoCodecType.jpeg])], completionHandler: nil)
            captureSession.addOutput(photoOutput!)
        } catch {
            print(error.localizedDescription)
        }
        
    }
    
    func setupPreviewLayer(sessionPreset: AVCaptureSession.Preset?) {
        var cameraPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        cameraPreviewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        cameraPreviewLayer.connection?.videoOrientation = AVCaptureVideoOrientation.portrait
        
        let screenWidth = UIScreen.main.bounds.size.width
        let screenHeight = UIScreen.main.bounds.size.height
        
        
        if let sessionPreset = sessionPreset {
            if sessionPreset == AVCaptureSession.Preset.photo {
                cameraPreviewLayer.frame = CGRect(x: 0, y: 0, width: screenWidth, height: (screenWidth / 3 * 4))
                self.view.layer.insertSublayer(cameraPreviewLayer, at: 0)
            } else {
                cameraPreviewLayer.frame = CGRect(x: 0, y: 0, width: screenWidth, height: (screenWidth / 9 * 16))
                self.view.layer.insertSublayer(cameraPreviewLayer, at: 0)
            }
        } else {
            cameraPreviewLayer.frame = CGRect(x: 0, y: 0, width: screenWidth, height: (screenWidth / 3 * 4))
            self.view.layer.insertSublayer(cameraPreviewLayer, at: 0)
        }
        
//        cameraPreviewLayer.frame = self.view.frame
        self.view.layer.insertSublayer(cameraPreviewLayer, at: 0)
    }
    
    func startRunningCaptureSession() {
        captureSession.startRunning()
    }
    
    @IBAction func cameraButton(_ sender: UIButton) {
        let settings = AVCapturePhotoSettings()
        print("camera button pressed")
        photoOutput?.capturePhoto(with: settings, delegate: self)
        //performSegue(withIdentifier: "showPhotoPreviewSegue", sender: nil)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showPhotoPreviewSegue" {
            let previewVC = segue.destination as! PreviewViewController
            previewVC.image = self.image
        }
    }
    
    @objc func switchCamera() {
        captureSession.beginConfiguration()
        
        // Change the device based on the current camera
        let newDevice = (currentCamera?.position == AVCaptureDevice.Position.back) ? frontCamera : backCamera
        
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
        
        currentCamera = newDevice
        captureSession.commitConfiguration()
    }
    
    @objc func zoomIn() {
        if let zoomFactor = currentCamera?.videoZoomFactor {
            if zoomFactor < 5.0 {
                let newZoomFactor = min(zoomFactor + 1.0, 5.0)
                do {
                    try currentCamera?.lockForConfiguration()
                    currentCamera?.ramp(toVideoZoomFactor: newZoomFactor, withRate: 1.0)
                    currentCamera?.unlockForConfiguration()
                } catch {
                    print(error)
                }
            }
        }
    }
    
    @objc func zoomOut() {
        if let zoomFactor = currentCamera?.videoZoomFactor {
            if zoomFactor > 1.0 {
                let newZoomFactor = max(zoomFactor - 1.0, 1.0)
                do {
                    try currentCamera?.lockForConfiguration()
                    currentCamera?.ramp(toVideoZoomFactor: newZoomFactor, withRate: 1.0)
                    currentCamera?.unlockForConfiguration()
                } catch {
                    print(error)
                }
            }
        }
    }
    
    
    @objc func handleTapToFocus(sender: UITapGestureRecognizer) {
        if let device = currentCamera {
            let focusPoint = sender.location(in: view)
            let focusScaledPointX = focusPoint.x / view.frame.size.width
            let focusScaledPointY = focusPoint.y / view.frame.size.height
            if device.isFocusModeSupported(.autoFocus) && device.isFocusPointOfInterestSupported {
                do {
                    try device.lockForConfiguration()
                } catch {
                    print("ERROR: Could not lock camera device for configuration")
                    return
                }
                 
                device.focusMode = .autoFocus
                device.focusPointOfInterest = CGPoint(x: focusScaledPointX, y: focusScaledPointY)
                    
                device.unlockForConfiguration()
            }
        }
    }
    
    @IBAction func selectQuality(_ sender: Any) {
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
    
    @IBAction func configureDocumentView(_ sender: Any) {
        let scaningDocumentViewController = VNDocumentCameraViewController()
        scaningDocumentViewController.delegate = self
        
        self.present(scaningDocumentViewController, animated: true)
    }
    
    @IBAction func openVideoMod(_ sender: Any) {
        let mainStoryboard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
        if let viewController = mainStoryboard.instantiateViewController(withIdentifier: "recordVideoViewController") as? UIViewController {
            UIApplication.shared.windows.first?.rootViewController = viewController
            UIApplication.shared.windows.first?.makeKeyAndVisible()
        }
    }
    
}

extension ViewController: VNDocumentCameraViewControllerDelegate {
    
    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
        for pageNumber in 0..<scan.pageCount {
            let image = scan.imageOfPage(at: pageNumber)
            
            self.image = image
            performSegue(withIdentifier: "showPhotoPreviewSegue", sender: nil)
        }
        
        controller.dismiss(animated: true)
    }
}

extension ViewController : AVCapturePhotoCaptureDelegate {
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        
        if let imageData = photo.fileDataRepresentation() {
            print(imageData)
            image = UIImage(data: imageData)
            performSegue(withIdentifier: "showPhotoPreviewSegue", sender: nil)
        }
    }
}
