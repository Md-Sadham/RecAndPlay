//
//  ViewController.swift
//  RecAndPlay
//
//  Created by Sadham on 03/05/2018.
//  Copyright © 2018 Sadham. All rights reserved.
//

import UIKit
import AVKit
import AVFoundation

class ViewController: UIViewController, AVAudioRecorderDelegate, AVAudioPlayerDelegate {

    // Button
    @IBOutlet weak var btnPlay: UIButton!
    @IBOutlet weak var btnPause: UIButton!
    @IBOutlet weak var btnDiscard: UIButton!
    @IBOutlet weak var btnRecord: UIButton!
    
    // Label
    @IBOutlet weak var lblRemainingTime: UILabel!
    @IBOutlet weak var lblPlayTime: UILabel!
    
    // Slider View
    @IBOutlet weak var sliderForPlayer: UISlider!
    
    // For Rec & Player
    var audioRecSession: AVAudioSession!
    var audioRecorder: AVAudioRecorder!
    var audioPlayer:AVAudioPlayer!
    
    var isIntroMusicEnds : Bool = false
    var funcIndex: Int = 0 // 1 - play; 2-pause; 3-recording running; 4-recording paused; 5-send file to server
    
    // Others
    var arrayRecordingList: NSMutableArray = []
    var dateFormatForPlayerTime = DateFormatter()
    
    // MARK: - View Life cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        lblPlayTime.text = "00:00"
        lblRemainingTime.text = ""
        lblPlayTime.isHidden = true
        lblRemainingTime.isHidden = true
        dateFormatForPlayerTime.dateFormat = "mm:ss"
        
        setupInitialUI(setColor: "DiscardOrSend")
        
        deleteExistDirectory(onDidLoad: true)
        
        getPermissionFromUserForRecording()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - Player Methods
    func playerDefaultLook(){
        lblPlayTime.text = "00:00"
        lblRemainingTime.text = ""
        lblPlayTime.isHidden = true
        lblRemainingTime.isHidden = true
        sliderForPlayer.setValue(Float(0.0), animated: true)
    }
    
    func playTheTrack(urlOfTrack: URL){
        // Give path to player
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: urlOfTrack)
            guard let audioPlayer = audioPlayer else { return }
            audioPlayer.delegate = self
            audioPlayer.prepareToPlay()
            print("Playing...")
            audioPlayer.play()
            
            sliderForPlayer.value = 0.0
            sliderForPlayer.minimumValue = 0.0
            sliderForPlayer.maximumValue = Float(audioPlayer.duration)
            lblPlayTime.isHidden = false
            lblRemainingTime.isHidden = false
            
            Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(updateAudioProgressView), userInfo: nil, repeats: true)
        }
        catch let error {
            print(error.localizedDescription)
        }
    }
    
    func preparePlayTheMergedFiles(){
        // Set path before play
        funcIndex = 0
        let myFileInfo: Dictionary = arrayRecordingList[arrayRecordingList.count-1] as! [String : Any]
        let filePath = myFileInfo["Path"] as! URL
        print("Selected Path: ", filePath)
        playTheTrack(urlOfTrack: filePath)
        
        setupInitialUI(setColor: "Play")
    }
    
    @objc func updateAudioProgressView()
    {
        if audioPlayer.isPlaying
        {
            // Update progress
            sliderForPlayer.setValue(Float(audioPlayer.currentTime), animated: true)
            
            // Current time
            var PlayerTime = Int(audioPlayer.currentTime)
            var minutes = PlayerTime/60
            var seconds = PlayerTime - minutes * 60
            lblPlayTime.text = NSString(format: "%02d:%02d", minutes,seconds) as String
            print("Current: ", lblPlayTime.text)
            
            // REmaining Time
            PlayerTime = Int(audioPlayer.duration-audioPlayer.currentTime)
            minutes = PlayerTime/60
            seconds = PlayerTime - minutes * 60
            lblRemainingTime.text = NSString(format: "-%02d:%02d", minutes,seconds) as String
            print("Remaining: ", lblRemainingTime.text)
            
        }
    }
    
    // MARK: - Player Delegates
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool){
        if(!isIntroMusicEnds){
            print("Playing ends")
            lblPlayTime.text = "00:00"
            lblRemainingTime.text = ""
            lblPlayTime.isHidden = true
            lblRemainingTime.isHidden = true
            sliderForPlayer.setValue(Float(0.0), animated: true)
            setupInitialUI(setColor: "Pause")
        }
    }
    
    // MARK: - Recorder Methods
    func getPermissionFromUserForRecording(){
        audioRecSession = AVAudioSession.sharedInstance()
        
        do {
            try audioRecSession.setCategory(AVAudioSessionCategoryPlayAndRecord, with: AVAudioSessionCategoryOptions.defaultToSpeaker)
            try audioRecSession.setActive(true)
            audioRecSession.requestRecordPermission() { [unowned self] allowed in
                DispatchQueue.main.async {
                    if allowed {
                        print("Successfully allowed the recording for this app")
                        self.btnRecord.setTitle("Start", for: .normal) // For just use self and avoid warning
                    } else {
                        // failed to record!
                        print("You not allowed the recording for this app")
                    }
                }
            }
        } catch {
            print("failed to record!")
        }
    }
    
    func startRecording() {
        print("===START RECORDING===")
        
        let myDateFormat = DateFormatter()
        myDateFormat.dateFormat = "yyyy-MM-dd_hh-mm-ss"
        let presentDateAndTimeAsString = myDateFormat.string(from: Date())
        let fileName = presentDateAndTimeAsString + ".m4a"
        
        let audioFilePath:NSURL = NSURL(fileURLWithPath: getDocumentsDirectory()+"/"+fileName)
        print("AUDIO FILE PATH ", audioFilePath)
        
        // Save file path in array
        let dictFileInfo: Dictionary = ["Name" : fileName, "Path" : audioFilePath] as [String : Any]
        arrayRecordingList.add(dictFileInfo)
        
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 12000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioFilePath as URL, settings: settings)
            audioRecorder.delegate = self
            audioRecorder.record()
        } catch {
            finishRecording(success: false)
        }
    }
    
    func finishRecording(success: Bool) {
        audioRecorder.stop()
    }
    
    func reRecording(){
        setupInitialUI(setColor: "Record")
        
        // Start the recording
        funcIndex = 3
        startRecording()
    }
    
    func combineTheRecordsAndSaveit(){
        
        // 1
        if(arrayRecordingList.count<2){
            if(self.funcIndex == 1){
                self.preparePlayTheMergedFiles()
            }
            else{
                reRecording()
            }
            return
        }
        
        // 2
        let fileManager = FileManager.default
        var fileDestinationUrl: URL!
        
        do {
            let url = try fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            fileDestinationUrl = url.appendingPathComponent("resultMerge.m4a")
            print("FINAL URL:",fileDestinationUrl)
        }
        catch  {
            print(error)
        }
        
        // 3
        var duration: CMTime = kCMTimeZero
        let composition = AVMutableComposition()
        let compositionAudioTrack:AVMutableCompositionTrack = composition.addMutableTrack(withMediaType: AVMediaType.audio, preferredTrackID: CMPersistentTrackID())!
        
        print("ALL FILE INFO: ", arrayRecordingList)
        
        for i in 0...arrayRecordingList.count-1 {
            var myFileInfo: Dictionary = arrayRecordingList[i] as! [String : Any]
            let filePath = myFileInfo["Path"] as! URL
            
            let myAvAsset = AVURLAsset(url: filePath, options: nil) //mod
            let myArrTracks = myAvAsset.tracks(withMediaType: AVMediaType.audio) // mod
            
            if(myArrTracks.count == 0){
                print("NO TRACKS PRESENT.")
            }
            
            let myTimeRange = CMTimeRangeMake(kCMTimeZero, myAvAsset.duration)
            var tracks =  myAvAsset.tracks(withMediaType: AVMediaType.audio)
            let myAssetTrack:AVAssetTrack = tracks[0]
            
            print("FilePath: ",filePath)
            print("AVURLASSET: ", myAvAsset)
            print("ASSET TYPE: ",myArrTracks)
            print("TIME RANGE: ",myTimeRange)
            print("TYPE 2: ", tracks)
            print("FINAL TRACK: ", myAssetTrack)
            
            do {
                try compositionAudioTrack.insertTimeRange(myTimeRange, of: myAssetTrack, at: duration)
            }
            catch let error as NSError {
                print("Ooops! Something went wrong: \(error)")
            }
            
            duration = CMTimeAdd(duration, myTimeRange.duration)
        }
        
        // 4
        let assetExport = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetAppleM4A)
        assetExport?.outputFileType = .m4v
        assetExport?.outputURL = fileDestinationUrl
        
        assetExport?.exportAsynchronously(completionHandler: {
            print("EXPORT COMPLETED")
            let assetStatus : AVAssetExportSessionStatus = (assetExport?.status)!
            print(assetStatus)
            
            switch assetStatus{
            case .unknown:
                print("unknown")
            case .waiting:
                print("waiting")
            case .exporting:
                print("exporting")
            case .completed:
                print("completed")
                
                DispatchQueue.main.async( execute: {
                    print("Async2")
                    print("completed")
                    self.deleteExistDirectory(onDidLoad: false)
                    self.arrayRecordingList.removeAllObjects()
                    
                    // Move final result to our recorded files folder
                    do {
                        let documentDirectory = try fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                        let originPath = documentDirectory.appendingPathComponent("resultMerge.m4a")
                        var destinationPath = documentDirectory.appendingPathComponent("RecordedFiles")
                        destinationPath = destinationPath.appendingPathComponent("MergedFile.m4a")
                        try FileManager.default.moveItem(at: originPath, to: destinationPath)
                        
                        let dictFileInfo: Dictionary = ["Name" : "MergedFile.m4a", "Path" : destinationPath] as [String : Any]
                        self.arrayRecordingList.add(dictFileInfo)
                    }
                    catch {
                        print(error)
                    }
                    
                    if(self.funcIndex == 1){
                        self.preparePlayTheMergedFiles()
                    }
                    else{
                        self.reRecording()
                    }
                })
                
            case .failed:
                print("failed")
            case .cancelled:
                print("cancelled")
            }
        })
    }
    
    // MARK: Recorder Delegates
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            finishRecording(success: false)
        }
    }
    
    // MARK: - Action
    @IBAction func actionDiscard(_ sender: AnyObject) {
        
        if(audioRecorder.isRecording){
            audioRecorder.stop()
        }
        
        funcIndex = 0
        deleteExistDirectory(onDidLoad: false)
        arrayRecordingList.removeAllObjects()
        setupInitialUI(setColor: "DiscardOrSend")
    }
    
    @IBAction func actionStartRecording(_ sender: AnyObject) {
        
        if(funcIndex == 3){
            // Resume the recording
            audioRecorder.record()
            setupInitialUI(setColor: "Record")
            
        }
        else if(funcIndex == 4 || funcIndex == 1 || funcIndex == 2 || funcIndex == 0){
            // Need to start recording
            
            // combine all track as one before start new one
            combineTheRecordsAndSaveit()
        }
        
    }
    
    @IBAction func actionPlayerFunctions(_ sender: UIButton) {
        
        if(sender.tag == 1){
            // Play
            if(funcIndex == 2){
                funcIndex = 0
                audioPlayer.play()
                setupInitialUI(setColor: "Play")
            }
            else{
                funcIndex = 1
                finishRecording(success: true)
                
                combineTheRecordsAndSaveit()
            }
        }
        else if(sender.tag == 2){
            // Pause
            
            if(funcIndex == 3){
                // Recording -> Pause
                audioRecorder.pause()
                setupInitialUI(setColor: "Pause")
            }
            else{
                // Play -> Pause
                print("Audio Player -> Pause", funcIndex)
                funcIndex = 2
                audioPlayer.pause()
                setupInitialUI(setColor: "Pause")
            }
        }
        else if(sender.tag == 3){
            // Save & Send
            print("UNDER DEVELPOMENT")
            /*funcIndex = 5
            finishRecording(success: true)
            setupInitialUI(setColor: "Pause")
            combineTheRecordsAndSaveit()*/
        }
    }
    
    @IBAction func actionSliderValueChanged(_ sender: AnyObject) {
        print("Slider - Value Changed")
        audioPlayer.currentTime = TimeInterval(sliderForPlayer.value)
    }
    
    
    // MARK: - Other Methods
    func deleteExistDirectory(onDidLoad: Bool){
        let fileManager = FileManager.default
        let logsPath: URL!
        do {
            let url = try fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            
            if(!onDidLoad){
                logsPath = url.appendingPathComponent("RecordedFiles")
            }
            else{
                logsPath = url
            }
            
            if let enumerator = fileManager.enumerator(at: logsPath, includingPropertiesForKeys: nil) {
                while let fileURL = enumerator.nextObject() as? URL {
                    print("delete")
                    try fileManager.removeItem(at: fileURL)
                }
            }
        }  catch  {
            print(error)
        }
    }
    
    func setupInitialUI(setColor: String){
        
        print("UI STATUS: ", setColor)
        
        if(setColor == "DiscardOrSend"){
            btnDiscard.backgroundColor = UIColor.red
            btnPlay.backgroundColor = UIColor.red
            btnPause.backgroundColor = UIColor.red
            btnRecord.backgroundColor = hexStringToUIColor(hex: "#0078FF")
            
            btnDiscard.isUserInteractionEnabled = false
            btnPlay.isUserInteractionEnabled = false
            btnPause.isUserInteractionEnabled = false
            btnRecord.isUserInteractionEnabled = true
            
            btnRecord.setTitle("Start", for: .normal)
            
            playerDefaultLook()
        }
        else if(setColor == "Record"){
            btnDiscard.backgroundColor = UIColor.red
            btnPlay.backgroundColor = UIColor.red
            btnPause.backgroundColor = hexStringToUIColor(hex: "#0078FF")
            btnRecord.backgroundColor = UIColor.red
            
            btnDiscard.isUserInteractionEnabled = false
            btnPlay.isUserInteractionEnabled = false
            btnPause.isUserInteractionEnabled = true
            btnRecord.isUserInteractionEnabled = false
            
            btnRecord.setTitle("Recording", for: .normal)
            
            playerDefaultLook()
        }
        else if(setColor == "Pause"){
            btnDiscard.backgroundColor = hexStringToUIColor(hex: "#0078FF")
            btnPlay.backgroundColor = hexStringToUIColor(hex: "#0078FF")
            btnPause.backgroundColor = UIColor.red
            btnRecord.backgroundColor = hexStringToUIColor(hex: "#0078FF")
            
            btnDiscard.isUserInteractionEnabled = true
            btnPlay.isUserInteractionEnabled = true
            btnPause.isUserInteractionEnabled = false
            btnRecord.isUserInteractionEnabled = true
            
            btnRecord.setTitle("Resume", for: .normal)
        }
        else if(setColor == "Play"){
            btnDiscard.backgroundColor = UIColor.red
            btnPlay.backgroundColor = UIColor.red
            btnPause.backgroundColor = hexStringToUIColor(hex: "#0078FF")
            btnRecord.backgroundColor = UIColor.red
            
            btnDiscard.isUserInteractionEnabled = false
            btnPlay.isUserInteractionEnabled = false
            btnPause.isUserInteractionEnabled = true
            btnRecord.isUserInteractionEnabled = false
            
            btnRecord.setTitle("Resume", for: .normal)
        }
    }
    
    func getDocumentsDirectory() -> String {
        
        let fileManager = FileManager.default
        do {
            let url = try fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let logsPath = url.appendingPathComponent("RecordedFiles")
            print("DOCUMENT DIRECTORY: ", url)
            print(logsPath)
            try fileManager.createDirectory(at: logsPath, withIntermediateDirectories: true, attributes: nil)
            return logsPath.path
        }
        catch  {
            print(error)
        }
        
        let docuDirectory = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        return docuDirectory
    }
    
    func hexStringToUIColor (hex:String) -> UIColor {
        var cString:String = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        if (cString.hasPrefix("#")) {
            cString.remove(at: cString.startIndex)
        }
        
        if ((cString.characters.count) != 6) {
            return UIColor.gray
        }
        
        var rgbValue:UInt32 = 0
        Scanner(string: cString).scanHexInt32(&rgbValue)
        
        return UIColor(
            red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
            alpha: CGFloat(1.0)
        )
    }
}

