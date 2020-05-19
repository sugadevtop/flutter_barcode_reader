//
//  BarcodeScannerViewController.swift
//  barcode_scan
//
//  Created by Julian Finkler on 20.02.20.
//

import Foundation
import MTBBarcodeScanner

class BarcodeScannerViewController: UIViewController {
  private var previewView: UIView?
  private var scanRect: ScannerOverlay?
  private var scanner: MTBBarcodeScanner?
  
  var config: Configuration = Configuration.with {
    $0.strings = [
      "cancel" : "Cancel",
      "flash_on" : "Flash on",
      "flash_off" : "Flash off",
    ]
    $0.useCamera = -1 // Default camera
    $0.autoEnableFlash = false
  }
  
  private let formatMap = [
    BarcodeFormat.aztec : AVMetadataObject.ObjectType.aztec,
    BarcodeFormat.code39 : AVMetadataObject.ObjectType.code39,
    BarcodeFormat.code93 : AVMetadataObject.ObjectType.code93,
    BarcodeFormat.code128 : AVMetadataObject.ObjectType.code128,
    BarcodeFormat.dataMatrix : AVMetadataObject.ObjectType.dataMatrix,
    BarcodeFormat.ean8 : AVMetadataObject.ObjectType.ean8,
    BarcodeFormat.ean13 : AVMetadataObject.ObjectType.ean13,
    BarcodeFormat.interleaved2Of5 : AVMetadataObject.ObjectType.interleaved2of5,
    BarcodeFormat.pdf417 : AVMetadataObject.ObjectType.pdf417,
    BarcodeFormat.qr : AVMetadataObject.ObjectType.qr,
    BarcodeFormat.upce : AVMetadataObject.ObjectType.upce,
  ]
  
  var delegate: BarcodeScannerViewControllerDelegate?
  
  private var device: AVCaptureDevice? {
    return AVCaptureDevice.default(for: .video)
  }
  
  private var isFlashOn: Bool {
    return device != nil && (device?.flashMode == AVCaptureDevice.FlashMode.on || device?.torchMode == .on)
  }
  
  private var hasTorch: Bool {
    return device?.hasTorch ?? false
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    #if targetEnvironment(simulator)
    view.backgroundColor = .lightGray
    #endif
    
    previewView = UIView(frame: view.bounds)
    if let previewView = previewView {
      previewView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      view.addSubview(previewView)
    }
    setupScanRect(view.bounds)
    
    let restrictedBarcodeTypes = mapRestrictedBarcodeTypes()
    if restrictedBarcodeTypes.isEmpty {
      scanner = MTBBarcodeScanner(previewView: previewView)
    } else {
      scanner = MTBBarcodeScanner(metadataObjectTypes: restrictedBarcodeTypes,
                                  previewView: previewView
      )
    }
    setupNavigationBar()
  }
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    
    if scanner!.isScanning() {
      scanner!.stopScanning()
    }
    
    scanRect?.startAnimating()
    MTBBarcodeScanner.requestCameraPermission(success: { success in
      if success {
        self.startScan()
      } else {
        #if !targetEnvironment(simulator)
        self.errorResult(errorCode: "PERMISSION_NOT_GRANTED")
        #endif
      }
    })
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    scanner?.stopScanning()
    scanRect?.stopAnimating()
    
    super.viewWillDisappear(animated)
  }
  
  override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
    super.viewWillTransition(to: size, with: coordinator)
    setupScanRect(CGRect(origin: CGPoint(x: 0, y:0),
                         size: size
    ))
  }
  
  private func setupScanRect(_ bounds: CGRect) {
    if scanRect != nil {
      scanRect?.stopAnimating()
      scanRect?.removeFromSuperview()
    }
    scanRect = ScannerOverlay(frame: bounds)
    if let scanRect = scanRect {
      scanRect.translatesAutoresizingMaskIntoConstraints = false
      scanRect.backgroundColor = UIColor.clear
      view.addSubview(scanRect)
      scanRect.startAnimating()
    }
  }

  private func setupNavigationBar() {
    self.navigationController?.navigationBar.isTranslucent = false
    self.navigationController?.navigationBar.backgroundColor = .white
    self.navigationController?.navigationBar.tintColor = .black
    self.navigationController?.navigationBar.titleTextAttributes = [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 22), NSAttributedString.Key.foregroundColor: UIColor(red: 251/255, green: 173/255, blue: 27/255, alpha: 1.0)]
    self.title = "Sentinel"
    self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .stop, target: self, action:  #selector(cancel))
  }
  
  private func startScan() {
    do {
        if let scanRect = scanRect?.calculateScanRect() {
            scanner?.didStartScanningBlock = {
                self.scanner?.scanRect = scanRect
            }
        }
      

      try scanner!.startScanning(with: cameraFromConfig, resultBlock: { codes in
        if let code = codes?.first {
          let codeType = self.formatMap.first(where: { $0.value == code.type });
          let scanResult = ScanResult.with {
            $0.type = .barcode
            $0.rawContent = code.stringValue ?? ""
            $0.format = codeType?.key ?? .unknown
            $0.formatNote = codeType == nil ? code.type.rawValue : ""
          }
          self.scanner!.stopScanning()
          self.scanResult(scanResult)
        }
      })
    } catch {
      self.scanResult(ScanResult.with {
        $0.type = .error
        $0.rawContent = "\(error)"
        $0.format = .unknown
      })
    }
  }
  
  @objc private func cancel() {
    scanResult( ScanResult.with {
      $0.type = .cancelled
      $0.format = .unknown
    });
  }
  
  private func errorResult(errorCode: String){
    delegate?.didFailWithErrorCode(self, errorCode: errorCode)
    dismiss(animated: false)
  }
  
  private func scanResult(_ scanResult: ScanResult){
    self.delegate?.didScanBarcodeWithResult(self, scanResult: scanResult)
    dismiss(animated: false)
  }
  
  private func mapRestrictedBarcodeTypes() -> [String] {
    var types: [AVMetadataObject.ObjectType] = []
    
    config.restrictFormat.forEach({ format in
      if let mappedFormat = formatMap[format]{
        types.append(mappedFormat)
      }
    })
    
    return types.map({ t in t.rawValue})
  }
  
  private var cameraFromConfig: MTBCamera {
    return config.useCamera == 1 ? .front : .back
  }
}
