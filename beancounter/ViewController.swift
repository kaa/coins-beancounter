//
//  ViewController.swift
//  beancounter
//
//  Created by Joakim Beijar on 16.02.2018.
//  Copyright © 2018 Joakim Beijar. All rights reserved.
//
import AVFoundation
import UIKit

struct Circle {
    let x:Double
    let y:Double
    let r:Double
}
class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {

    var captureSession: AVCaptureSession = AVCaptureSession()
    var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    var drawingLayer:CAShapeLayer = CAShapeLayer()
    let model:coins = coins.init()
    
    @IBOutlet weak var image: UIImageView!
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var previewView: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        captureSession.sessionPreset = .hd1280x720
        guard let captureDevice = AVCaptureDevice.default(for: AVMediaType.video) else {
            return
        }
        guard let input = try? AVCaptureDeviceInput(device: captureDevice) else {
            return
        }
        captureSession.addInput(input)
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_32BGRA]
        output.alwaysDiscardsLateVideoFrames = true
        let cameraQueue = DispatchQueue(label: "videoQueue")
        output.setSampleBufferDelegate(self, queue: cameraQueue)
        captureSession.addOutput(output)

        videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        videoPreviewLayer!.videoGravity = .resizeAspectFill
        videoPreviewLayer!.frame = view.layer.bounds
        previewView.layer.addSublayer(videoPreviewLayer!)
        previewView.layer.addSublayer(drawingLayer)
        captureSession.startRunning()

        do {
            let midscreenPoint = CGPoint(x: previewView.frame.midX, y: previewView.frame.midY)
            try captureDevice.lockForConfiguration()
            captureDevice.whiteBalanceMode = .continuousAutoWhiteBalance
            captureDevice.focusMode = .continuousAutoFocus
            captureDevice.focusPointOfInterest = midscreenPoint
            captureDevice.exposureMode = .continuousAutoExposure
            captureDevice.exposurePointOfInterest = midscreenPoint
            captureDevice.unlockForConfiguration()
        } catch {
            return
        }
}
    
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        let targetBox = 150.0
        let circles = detectCircles(pixelBuffer: pixelBuffer, targetBox: targetBox)
        renderCircles(circles: circles, bufferWidth: Double(CVPixelBufferGetWidth(pixelBuffer)))
        
        guard let maxRadius = (circles.map { $0.r }.max()) else {
           return
        }
        let scaling = targetBox / (maxRadius * 2.3)
        let sourceImg = CIImage(cvPixelBuffer: pixelBuffer)
        let filter = CIFilter(name: "CILanczosScaleTransform")!
        filter.setValue(sourceImg, forKey: "inputImage")
        filter.setValue(scaling, forKey: "inputScale")
        filter.setValue(1.0, forKey: "inputAspectRatio")
        let resizedImg = filter.value(forKey: "outputImage") as! CIImage
        let context = CIContext(options: [kCIContextUseSoftwareRenderer: false])
        let circleImages = circles
            .map { circle in
                return context.createCGImage(
                    resizedImg,
                    from: CGRect(
                        x: circle.x * scaling - targetBox/2,
                        y: (Double(CVPixelBufferGetHeight(pixelBuffer)) - circle.y) * scaling - targetBox/2,
                        width: targetBox,
                        height: targetBox
                    )
                )
            }
            .filter { img in img != nil }
            .map { img in img! }

        let circlePredictions = circleImages.map { image -> (String?,UIImage?) in
            let buffer = image.pixelBuffer(width: 80, height: 80)!
            do {
                let prediction = try model.prediction(image: buffer)
                let label = prediction.featureValue(for: "classLabel")!.stringValue
                let dic = prediction.featureValue(for: "output")!.dictionaryValue
                for (key,value) in dic {
                    print("\(key)=\(value)")
                }
                return (label, UIImage(pixelBuffer: buffer))
            } catch {
                print("Failed to predict \(error)")
            }
            return (nil, nil)
        }
        
        DispatchQueue.main.async() {
            if let (img, (label, uiimg)) = zip(circleImages, circlePredictions).first(where: { _ in true }) {
                print("Setting image")
                self.image.image = uiimg
                self.label.text = label
            } else {
                self.image.image = nil
                self.label.text = nil
            }
        }
    }
    
    func detectCircles(pixelBuffer: CVImageBuffer, targetBox: Double) -> [Circle] {
        CVPixelBufferLockBaseAddress( pixelBuffer, CVPixelBufferLockFlags.readOnly );
        defer { CVPixelBufferUnlockBaseAddress( pixelBuffer, CVPixelBufferLockFlags.readOnly) }

        let width = Int32(CVPixelBufferGetWidth(pixelBuffer))
        let height = Int32(CVPixelBufferGetHeight(pixelBuffer))
        let rowLength = Int32(CVPixelBufferGetBytesPerRow(pixelBuffer))
        let ptr = CVPixelBufferGetBaseAddress(pixelBuffer)
        var circles = [Circle]()
        for maybeItem in OpenCVWrapper.detectCircles(ptr, width:width, height:height, rowLength:rowLength, minRadius: Int32(targetBox*0.5*0.8), maxRadius: Int32(targetBox*0.5))! {
            let item = maybeItem as! NSArray
            let x = (item[0] as! Double)
            let y = (item[1] as! Double)
            let r = (item[2] as! Double)
            circles.append(Circle(x:x,y:y,r:r))
        }
        return circles
    }
    
    func renderCircles(circles: [Circle], bufferWidth: Double) {
        DispatchQueue.main.async() {
            let scale = Double(self.view.bounds.height) / bufferWidth
            let allCirclesPath = UIBezierPath()
            for circle in circles {
                let centerPoint = CGPoint(
                    x: self.view.bounds.width - CGFloat(circle.y * scale),
                    y: CGFloat(circle.x * scale)
                )
                allCirclesPath.append(UIBezierPath(
                    arcCenter: centerPoint,
                    radius: CGFloat(circle.r * scale),
                    startAngle: CGFloat(0),
                    endAngle: CGFloat(2.0 * .pi),
                    clockwise: true
                ))
                
                let textLayer = CATextLayer()
                textLayer.font = CTFontCreateWithName("Helvetica" as CFString, 20, nil)
                textLayer.position = centerPoint
                textLayer.string = "Hi there"
                textLayer.foregroundColor = UIColor.red.cgColor
//                textLayer.bounds = CGRect(x: 0, y: 0, width: 100, height: 100)
                self.previewView.layer.addSublayer(textLayer)
            }
            self.drawingLayer.lineWidth = 2.0
            self.drawingLayer.fillColor = nil
            self.drawingLayer.strokeColor = UIColor.red.cgColor
            self.drawingLayer.path = allCirclesPath.cgPath
        }
    }
    
    func captureOutput(_ output: AVCaptureOutput, didDrop: CMSampleBuffer, from: AVCaptureConnection) {
        print("Frame was dropped")
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
}

