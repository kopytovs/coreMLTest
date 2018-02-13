//
//  ViewController.swift
//  testCoreMLObjFind
//
//  Created by Sergey Kopytov on 06.02.2018.
//  Copyright © 2018 Sergey Kopytov. All rights reserved.
//

import UIKit
import CoreML
import AVKit
import Vision

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {

    @IBOutlet weak var swapCamButton: UIButton!
    @IBOutlet weak var videoView: UIView!
    @IBOutlet weak var predLabel: UILabel!
    @IBOutlet weak var ageLabel: UILabel!
    @IBOutlet weak var genderLabel: UILabel!
    
    var captureSession = AVCaptureSession()
    
    var previewLayer: AVCaptureVideoPreviewLayer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        self.predLabel.text = ""
        self.ageLabel.text = ""
        self.genderLabel.text = ""
        
        self.setCamera()
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer?.frame = self.videoView.bounds
        self.videoView.layer.addSublayer(previewLayer!)
        self.videoView.layer.addSublayer(self.swapCamButton.layer)
        let dataOutput = AVCaptureVideoDataOutput()
        dataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        captureSession.addOutput(dataOutput)
        
    }
    
    private func swapCamera() {
        
        // Get current input
        guard let input = captureSession.inputs[0] as? AVCaptureDeviceInput else { return }
        
        // Begin new session configuration and defer commit
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }
        
        // Create new capture device
        let newDevice: AVCaptureDevice?
        if input.device.position == .back {
            newDevice = self.captureDeviceTake(with: .front)
        } else {
            newDevice = self.captureDeviceTake(with: .back)
        }
        
        // Create new capture input
        let deviceInput: AVCaptureDeviceInput!
        do {
            deviceInput = try AVCaptureDeviceInput(device: newDevice!)
        } catch let error {
            print(error.localizedDescription)
            return
        }
        
        // Swap capture device inputs
        captureSession.removeInput(input)
        captureSession.addInput(deviceInput)
    }
    
    private func captureDeviceTake(with position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        
        let devices = AVCaptureDevice.DiscoverySession(deviceTypes: [ .builtInWideAngleCamera, .builtInMicrophone, .builtInDualCamera, .builtInTelephotoCamera ], mediaType: AVMediaType.video, position: .unspecified).devices
        
        let devicess = devices
            for device in devicess {
                if device.position == position {
                    return device
                }
            }
        
        return nil
        
    }
    
    private func setCamera(){
        captureSession.stopRunning()
        captureSession.sessionPreset = .photo
        guard let captureDevice = AVCaptureDevice.default(for: .video) else {return}
        //guard let captureDevice = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .back) else {return}
        guard let input = try? AVCaptureDeviceInput(device: captureDevice) else {return}
        captureSession.addInput(input)
        captureSession.startRunning()
        
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        //print("Camera was able to capture a frame:", Date())
        
        guard let pixelBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {return}
        //guard let model:VNCoreMLModel = try? VNCoreMLModel(for: SqueezeNet().model) else {return}
        
        guard let modelRes = try? VNCoreMLModel(for: Resnet50().model) else {return}
        let requestRes = VNCoreMLRequest(model: modelRes, completionHandler: {
            (finishReq, err) in
            //print(finishReq.results)
            guard let results = finishReq.results as? [VNClassificationObservation] else {return}
            guard let firstObservation = results.first else {return}
            DispatchQueue.main.async {
                self.predLabel.text = String(firstObservation.identifier) + " (" + String(round(firstObservation.confidence*100000)/1000) + "%)"
            }
            //print(firstObservation.identifier, firstObservation.confidence)
        })
        
        guard let modelAge = try? VNCoreMLModel(for: AgeNet().model) else {return}
        let requestAge = VNCoreMLRequest(model: modelAge, completionHandler: {
            (finishReq, err) in
            
            guard let results = finishReq.results as? [VNClassificationObservation] else {return}
            guard let firstObservation = results.first else {return}
            DispatchQueue.main.async {
                self.ageLabel.text = String(firstObservation.identifier) + " (" + String(round(firstObservation.confidence*100000)/1000) + "%)"
            }
            
        })
        
        guard let modelGender = try? VNCoreMLModel(for: GenderNet().model) else {return}
        let requestGender = VNCoreMLRequest(model: modelGender, completionHandler: {
            (finishReq, err) in
            
            guard let results = finishReq.results as? [VNClassificationObservation] else {return}
            guard let firstObservation = results.first else {return}
            DispatchQueue.main.async {
                self.genderLabel.text = String(firstObservation.identifier) + " (" + String(round(firstObservation.confidence*100000)/1000) + "%)"
            }
            
        })
        
        
        try? VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:]).perform([requestRes, requestAge, requestGender])
    }
    
    @IBAction func changeCamera(_ sender: Any) {
        //TODO: create camera swap
        self.swapCamera()
        //self.setCamera()
    }
    

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

