//
// --------------------------------------------------------------------------
// LocalizationScreenshots.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

/// __Caution:__ Running these tests __does not build the MMF app__! [Sep 2025]
///     - Achieved this by making `Build Phases > Target Dependencies` empty
///     - You have to build the MMF target manually
///     -> This greatly speeds up iteration time, since it doesn't have to build the whole project every time you make a change to the automation/'test' code.

import XCTest
import Vision

final class LocalizationScreenshotClass: XCTestCase {
    
    ///
    /// Constants
    ///
    
    /// Keep-in-sync with .app
    let localized_string_annotation_activation_argument_for_screenshotted_app = "-MF_ANNOTATE_LOCALIZED_STRINGS"
    let localized_string_annotation_prefix_regex = "<mfkey:(.+):(.*)>" /// The first capture group is the localizationKey, the second capture group is the stringTableName
    let localized_string_annotation_suffix       = "</mfkey>"
    
    /// Keep-in-sync with python script
    let xcode_screenshot_taker_output_dir_variable = "MF_LOCALIZATION_SCREENSHOT_OUTPUT_DIR"
    
    /// Keep in sync with .xcloc format
    let xcode_screenshot_taker_outputted_metadata_filename = "localizedStringData.plist"
    typealias LocalizedStringData = [LocalizedStringDatum] /// localizedStringData.plist, which is found inside .xcloc screenshot folders, has this structure
    struct LocalizedStringDatum: Encodable {
        /// Core information
        let stringKey: String
        var screenshots: [Screenshot]
        struct Screenshot: Encodable {
            let name: String
            let frame: String /// Encoding of NSRect describing where the localized ui string associated with `stringKey` appears in the screenshot.
        }
        /// These fields can be whatever I think.
        let tableName: String
        let bundlePath: String
        let bundleID: String
    }
    
    /// Keep in sync with project structure
    ///     (Paths relative to the project-root)
    func repoRoot() -> String { return (NSString(#file).deletingLastPathComponent as NSString).deletingLastPathComponent }
    let CapturedButtonsGuideMMF3_ScreenshotPath1 = "Markdown/Media/%@/CapturedButtons1.jpg" /// The `%@` is to be replaced with the locale code.
    let CapturedButtonsGuideMMF3_ScreenshotPath2 = "Markdown/Media/%@/CapturedButtons2.jpg"
    
    ///
    /// Internal datatypes
    ///
    
    struct ScreenshotAndMetadata : CustomStringConvertible {
    
        /// [Aug 2025] Swift/objc discussion: The whole reason I wrote LocalizationScreenshots.swift in Swift was because defining complex nested/serializable datastructures like this in objc felt way more cumbersome. But now we have MFDataClass, which would be much nicer to work with than this! Problems with the Swift approach: The struct names are too short/context-less without the namespace prefix, but extremely long with the namespace prefixes. Doesn't display well in the debugger due to length (`Localization_Screenshot_Taker.LocalizationScreenshotClass.ScreenshotAndMetadata.Metadata.Frame.String_.XCStringsData`). Harder to grep for. ... Do namespaces just duck or am I using them wrong?
        
        var description: String { ScreenshotAndMetadata_description_from_key_value_pairs([("screenshot", screenshot), ("metadata", metadata)]) } /// [Aug 2025] Define custom descriptions because Swift's are extremely verbose due to namespacing. (Example: `Localization_Screenshot_Taker.LocalizationScreenshotClass.ScreenshotAndMetadata.Metadata.Frame.String_.XCStringsData(key: <...>, table: <...>)`
        let screenshot: XCUIScreenshot
        let metadata: Metadata
        
        struct Metadata : CustomStringConvertible {
            var description: String { ScreenshotAndMetadata_description_from_key_value_pairs([("screenshotName", screenshotName), ("snapshotTree", "<description prolly to long and not useful>"), ("screenshotAnnotations", screenshotAnnotations)]) }
            let screenshotName: String
            let screenshotFrame: NSRect                     /// [Aug 2025] Position of the screenshot relative to the screen. Used to convert frames of `XCUIElementSnapshot`s into screenshot-space.
            let snapshotTree: TreeNode<XCUIElementSnapshot> /// [Aug 2025] Only used for `testTakeScreenshots_Documentation()`, not for `testTakeScreenshots_Localization()` – Should we use the same datastructure for both?
            let screenshotAnnotations: [Frame]
            
            struct Frame : CustomStringConvertible {
                var description: String { ScreenshotAndMetadata_description_from_key_value_pairs([("frame", frame.debugDescription), ("localizableStringsInFrame", localizableStringsInFrame)]) }
                let frame: NSRect
                let localizableStringsInFrame: [String_] /// [Aug 2025] Why can there be multiple `String_`s per `Frame`? – This happens if one AXUIElement has multiple 'attributes' containing localizable strings. (E.g. tooltips are stored in a separate attribute)
                
                struct String_ : CustomStringConvertible {
                    var description: String { ScreenshotAndMetadata_description_from_key_value_pairs([("uiString", uiString), ("stringAnnotations", stringAnnotations)]) }
                    let uiString: String
                    let stringAnnotations: [XCStringsData] /// [Aug 2025] Why can there be multiple `XCStringsData`s per `String_`? – This happens if a uiString is stitched together from multiple localizer-facing strings
                    
                    struct XCStringsData : CustomStringConvertible {
                        var description: String { ScreenshotAndMetadata_description_from_key_value_pairs([("key", key), ("table", table)]) }
                        let key: String
                        let table: String
                        let uiString: String    /// [Sep 2025] This is the exact string as it appears in the UI (including %@ substitutions)
                    }
                }
            }
        }
    }
    
    ///
    /// Global vars
    ///
    
    var appSnap: XCUIElementSnapshot? = nil /// This probably get out of date when the app state changes
    var appAXUIElement: AXUIElement? = nil  /// This doesn't get out of date I think
    var _app: XCUIApplication? = nil
    var app: XCUIApplication? {
        get { _app }
        set {
            _app = newValue
            appSnap = try! app!.snapshot()
            appAXUIElement = getAXUIElementForXCElementSnapshot(appSnap!)!.takeUnretainedValue()
        }
    }
    var alreadyLoggedHitTestFailers: [AXUIElement] = []
    
    ///
    /// (shared) (f)unctions between different screenshot-taking tests
    ///
    func sharedf_mainapp_url() -> URL  { return URL(fileURLWithPath: XCUIApplication().value(forKey: "path") as! String) }
    func sharedf_helper_url() -> URL   { return sharedf_mainapp_url().appendingPathComponent("Contents/Library/LoginItems/Mac Mouse Fix Helper.app") }
    
    func sharedf_validate_that_main_app_is_enabled(_ window: XCUIElement, _ toolbarButtons: XCUIElementQuery) {
        
        /// [Aug 2025] We launch the helper manually and only check that the mainApp has connected to the helper here. (Instead of trying to enable the helper through the mainApp UI)
        ///     This lets us pass launchArguments to the helper (not sure that's always necessary / overcomplicates things tho)
        
        if (!toolbarButtons["scrolling"].isEnabled) {
            XCTFail("Error: The app does not seem to be enabled, the test should do this automatically")
        }
    }
    
    func sharedf_do_test_intro(outputDir: String?, fallbackTempDirName: String?) -> URL {
        
        /// Configure test
        self.continueAfterFailure = false
        
        /// Get output folder
        var outputDir_URL: URL? = nil
        XCTContext.runActivity(named: "Get Output Folder") { activity in
            if let outputDir {
                outputDir_URL = URL(fileURLWithPath: outputDir).absoluteURL
            }
            else if let fallbackTempDirName {
                outputDir_URL = FileManager().temporaryDirectory.appending(component: fallbackTempDirName)
                DDLogInfo("No output directory provided. Using \(outputDir_URL!) as a fallback.")
            }
            else { fatalError() }
        }
        guard let outputDir_URL else { fatalError() }
        
        /// Check ax permissions
        ///     ([Aug 2025] We need AX permissions because we dive into the AX stuff underlying the XCUI stuff for some things (See AXUIElementCopyAttributeNames()])
        let isTrusted = AXIsProcessTrustedWithOptions(nil);
        assert(isTrusted)
        
        /// Return
        return outputDir_URL
    }
    
    func sharedf_find_elements_for_navigating_main_app() -> (NSScreen, XCUIElement, XCUIElementQuery, XCUIElement) {
        let screen = NSScreen.main!
        let window = app!.windows.firstMatch
        let toolbarButtons = window.toolbars.firstMatch.children(matching: .button) /// `window.toolbarButtons` doesn't work for some reason.
        let menuBar = app!.menuBars.firstMatch
        return (screen, window, toolbarButtons, menuBar)
    }
    func sharedf_position_main_app_window(_ screen: NSScreen, _ window: XCUIElement, targetWindowY: Double) {
        
        /// `targetWindowY` arg is normalized between 0 and 1
        
        let targetWindowPosition = NSMakePoint(screen.frame.midX - window.frame.width/2.0, /// Just center the window horizontally
                                               targetWindowY * (screen.frame.height - window.frame.height))
        let appleScript = NSAppleScript(source: """
        tell application "System Events"
            set position of window 1 of process "Mac Mouse Fix" to {\(targetWindowPosition.x), \(targetWindowPosition.y)}
        end tell
        """)
        var error: NSDictionary? = nil
        appleScript?.executeAndReturnError(&error)
        assert(error == nil)
    }
    
    struct StringLocation {
        var uiString: String
        var roughBoundingBox: NSRect?
        var exactBoundingBox: NSRect?
    }
    func sharedf_find_exact_bounding_boxes_using_ocr(_ screenshotAndMetadata: ScreenshotAndMetadata, desiredKeys: [String]) throws -> [StringLocation] {
        
        var result = [StringLocation]()
        
        /// Extract the `roughBoundingBox`es and `uiStrings` for the `desiredKeys` from the `screenshotAndMetadata`
        outerLoop: for annotation in screenshotAndMetadata.metadata.screenshotAnnotations {
            for locstring in annotation.localizableStringsInFrame {
                for stringAnnotation in locstring.stringAnnotations {
                    for desiredKey in desiredKeys
                    {
                        if desiredKey == stringAnnotation.key {
                            result.append(StringLocation.init(
                                uiString: stringAnnotation.uiString,
                                roughBoundingBox: MFCGRectFlip(annotation.frame, screenshotAndMetadata.screenshot.image.size.height) /// [Aug 2025] Flip the frame cause the VNImage framework expects that.`
                            ))
                            continue outerLoop;
                        }
                    }
                }
            }
        }
        
        /// Use OCR to find the `exactBoundingBox`es
        do {
            let requestHandler = VNImageRequestHandler(cgImage: screenshotAndMetadata.screenshot.image.cgImage(forProposedRect: nil, context: nil, hints: nil)!)
            let request = VNRecognizeTextRequest(completionHandler: nil)
            request.automaticallyDetectsLanguage = true
            /// Ideas:
            ///     For the `VNRecognizeTextRequest` we could pass in more information like `recognitionLanguages`, `usesLanguageCorrection`, `customWords` or `regionOfInterest`. But this works fine. [Sep 2025]
            ///         We actually tried using `regionOfInterest`. I guess that would be more efficient. But it seems to make the boundingBoxes buggy (See: FB20053876)
            try requestHandler.perform([request])
            outerLoop: for i in result.indices {
                for requestResult in request.results! {
                    for candidate in requestResult.topCandidates(999) {
                        if candidate.string.contains(result[i].uiString) {
                            let foundBoundingBox        = try candidate.boundingBox(for: candidate.string.range(of: result[i].uiString)!)
                            let foundBoundingBox_AsRect = VNImageRectForNormalizedRect(
                                foundBoundingBox!.boundingBox,
                                Int(screenshotAndMetadata.screenshot.image.size.width),
                                Int(screenshotAndMetadata.screenshot.image.size.height)
                            )
                            if !result[i].roughBoundingBox!.insetBy(dx: -20, dy: -20) /// [Sep 2025] Observing 6 to be necessary on the x axis for `taste 5 klicken + mittlere Taste klicken` in German. || Update: Now suddenly `dx:-16` is necessary for `5 Düğmesi` (Worked find before)
                                .contains(foundBoundingBox_AsRect) { continue }
                            /// Shrink the frame to the recognized region
                            do {
                                var foundBoundingBox_AsRect_YAdjusted = foundBoundingBox_AsRect
                                foundBoundingBox_AsRect_YAdjusted.origin.y = result[i].roughBoundingBox!.origin.y       /// Actually, the OCR tends to make the frames a bit too small on the Y-axis so we use the `roughBoundingBox`'s values for that.
                                foundBoundingBox_AsRect_YAdjusted.size.height = result[i].roughBoundingBox!.size.height
                                var frameToHighlight = result[i]
                                frameToHighlight.exactBoundingBox = foundBoundingBox_AsRect_YAdjusted
                                result[i] = frameToHighlight
                            }

                            continue outerLoop
                        }
                    }
                }
                assert(false, "No piece of recognized text found that matches \(result[i].uiString) in region of the image \(result[i].roughBoundingBox!)")
            }
        }
        
        return result
    }
    
    func sharedf_snapshot_frame_to_screenshot_frame(_ snapshot_frame: NSRect, screenshot_frame_in_screen: NSRect) -> NSRect {
        
        /// Convert from the frame of an `XCUIElementSnapshot` into the frame of that element in a screenshot of the app.
        ///     [Sep 2025] The result seems to be exactly the frame that an .xcloc file expects. For other APIs (like VNImage) we need to apply `MFCGRectFlip()` before passing these frames in.
        
        /// Convert from screen coordinate system to screenshot's coordinate system
        ///     This is a few pixels off from what I measured with PixelSnap 2 and the values in Interface Builder, but that should be ok.
        
        var frame = snapshot_frame
        frame = NSRect(x: frame.minX - screenshot_frame_in_screen.minX,
                       y: frame.minY - screenshot_frame_in_screen.minY,
                       width: frame.width,
                       height: frame.height)
        
        /// Scale to screenshot resolution
        ///     The screenshot will usually have double resolution compared the internal coordinate system. Retina stuff I think.
        let bsf = NSScreen.screens[0].backingScaleFactor /// Not sure it matters which screen we use.
        frame = NSRect(x: bsf*frame.minX,
                       y: bsf*frame.minY,
                       width: bsf*frame.width,
                       height: bsf*frame.height)
        
        return frame
    }
    
    
    func testTakeScreenshots_Documentation() throws {
        
        // --------------------------
        // MARK: Main - Documentation Screenshots
        // --------------------------
        
        /// [Aug 2025] Writing this for taking screenshots for our `CapturedButtonsMMF3.md` guide.
        ///     Why take these screenshots programmatically? – They update to new macOS / MMF designs, plus we can localize them.
        ///     Main technological difference to `testTakeScreenshots_Localization()`:
        ///         For both, we want screenshots with red rectangles highlighting specific sections. The difference is that here, we need to draw the highlight rectangles on the images ourselves before rendering them out. Whereas for .xcloc files (which  `testTakeScreenshots_Localization()` is for), we just create metadata that tells Xcode where to draw the highlight rectangles.
        
        /// [Aug 2025] Override remaps
        /**
                [Aug 2025] defines the following entries for the remapsTable]
                    1. Middle click -> Smart Zoom
                    2. Click Button 5 + Click Middle Button -> Mission Control
                    3. Click Button 4 -> Launchpad
                    4. Click and Drag Button 4 -> Scroll & Navigate
                
                We plan to use this in the CapturedButtonsGuideMMF3.md
                    There we plan to use two screenshots with the same base pic with different highlights:
                        1. First pic highlighted the first occurence of Middle Button, Button 5, and Button 4
                        2. The second pic highlighted 'Button 4' and the two '-' buttons under 'Button 4'

                TODOs:
                - Generate the screenshots programmatically
                - DELETE unnecessary comments above
             */
        
        do {
            /// Sidenote:
            ///     [Aug 2025] I tried to define `CapturedButtonsGuideMMF3_ScreenshotRemaps` as Swift by converting the plist to Swift source code via plutil, but plutil converted empty dict to empty array which made MMF crash.
        
            let configURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appending(path: "/com.nuebling.mac-mouse-fix/config.plist")
            let remapsOverrideURL = URL(fileURLWithPath: currentFilePath().deletingLastPathComponent + "/CapturedButtonsGuideMMF3_ScreenshotRemaps.plist")

            let remaps = NSDictionary(contentsOf: remapsOverrideURL)!                                      /// Read
            var config = NSDictionary(contentsOf: configURL)?.mutableCopy() as! NSMutableDictionary        /// Read
            config["Remaps"] = remaps["Remaps"]                                                            /// Modify
            try config.write(to: configURL)                                                                /// Write
        }
        
        /// Do test intro
        let outputDir = sharedf_do_test_intro(outputDir: nil, fallbackTempDirName: "MF_DOC_SCREENSHOT_TEST")
        
        var localizations =
            //["ko"]
            Bundle(url: sharedf_mainapp_url())!.localizations.filter { $0 != "Base" }
        
        let localization_ToContinueFrom: String? =
            nil
            //"tr"; /// Set this in case of interruption to avoid redoing all the already-completed localizations
        if let localization_ToContinueFrom {
            localizations = Array(localizations.suffix(from: localizations.firstIndex(of: localization_ToContinueFrom)!))
        }
        
        for languageCode in localizations {
            
            /// Launch main app.
            let app = sharedf_launch_app(
                url: sharedf_mainapp_url(),
                args: [
                    localized_string_annotation_activation_argument_for_screenshotted_app,
                    "-AppleLanguages", "(\(languageCode))"
                ],
                env: [:],
                leave_app_running: (localizations.count <= 1 ? true : false) /// Restart the app so its using the right language we specified ––– or leave it running for faster iterations if there's only one language
            )
            
            self.app = app
            
            /// Launch helper app
            let helperApp = sharedf_launch_app(
                url: sharedf_helper_url(),
                args: [
                    localized_string_annotation_activation_argument_for_screenshotted_app,
                    "-AppleLanguages", "(\(languageCode))"
                ],
                env: [:],
                leave_app_running: (localizations.count <= 1 ? true : false)
            )
            
            /// Find elements
            let (screen, window, toolbarButtons, menuBar) = sharedf_find_elements_for_navigating_main_app()
                
            /// Navigate to the buttons tab
            do {
                
                /// Validate mainApp enabled
                sharedf_validate_that_main_app_is_enabled(window, toolbarButtons)
                
                /// Switch to buttons tab
                toolbarButtons["buttons"].click()
                coolWait()
                
                /// Dismiss restoreDefaultsPopover, in case it pops up.
                ///     [Aug 2025] Copied from `navigateAppAndTakeScreenshots()`. Not sure if necessary here.
                hitEscape()
                coolWait()
            }
            
            /// Take screenshots
            do {
                
                /// Take screenshot!
                var screenshotAndMetadata: ScreenshotAndMetadata? = takeLocalizationScreenshot(of: window, name: "ButtonsTab Screenshot For Documentation")
                print("doc screenshot (and metadata): \(screenshotAndMetadata!)")
                let image = screenshotAndMetadata!.screenshot.image /// Shorthand for later
                
                
                /// keys we prolly wanna highlight:
                ///     First screenshot:
                ///     - trigger.y.group-row.button-name.middle
                ///     - trigger.y.group-row.button-name.numbered
                ///     - trigger.substring.button-name.numbered
                ///     Second screenshot:
                ///     - trigger.y.group-row.button-name.numbered
                ///     - The two minus buttons (Don't have localized strings attached to them I think)
                
                /// Find boundingBoxes
                
                var boundingBoxes1 = [NSRect]()
                var boundingBoxes2 = [NSRect]()
                
                do {
                    /// boundingBoxes for first image
                    do {
                        /// Highlight the first appearance of "Middle Button", "Button 5" and "Button 4", respectively
                        let searchedStrings = try sharedf_find_exact_bounding_boxes_using_ocr(screenshotAndMetadata!, desiredKeys: [
                            "trigger.y.group-row.button-name.middle",
                            "trigger.substring.button-name.numbered",
                            "trigger.y.group-row.button-name.numbered",
                        ])
                        for string in searchedStrings {
                            boundingBoxes1.append(string.exactBoundingBox!)
                        }
                    }
                    
                    /// boundingBoxes for second image
                    do {
                        
                        /// Highlight the "Button 4" groupRow
                        let locatedLocalizedStrings = try sharedf_find_exact_bounding_boxes_using_ocr(screenshotAndMetadata!, desiredKeys: [
                            "trigger.y.group-row.button-name.numbered"
                        ])
                        assert(locatedLocalizedStrings.count == 1)
                        boundingBoxes2.append(locatedLocalizedStrings[0].exactBoundingBox!)
                        
                        /// Highlight the '-' buttons below the "Button 4" groupRow
                        for node in screenshotAndMetadata!.metadata.snapshotTree.depthFirstEnumerator() {
                            let node = node as! TreeNode<XCUIElementSnapshot>
                            let elementSnapshot = node.representedObject!
                            if (elementSnapshot.elementType == .button && elementSnapshot.identifier == "deleteButton") {
                                var frame = sharedf_snapshot_frame_to_screenshot_frame(elementSnapshot.frame, screenshot_frame_in_screen: screenshotAndMetadata!.metadata.screenshotFrame)
                                frame = MFCGRectFlip(frame, screenshotAndMetadata!.screenshot.image.size.height)
                                if locatedLocalizedStrings[0].exactBoundingBox!.maxY < frame.minY { continue } /// We only wanna highlight the `deleteButton`s *below* the "Button 4" group row
                                frame = frame.insetBy(dx: -5, dy: -5)                                          /// Put small margin around the highlighted element for better visuals
                                boundingBoxes2.append(frame)
                            }
                        }
                    }
                }
                
                /// Create images with markup and write them to file
                let allBoundingBoxes = [boundingBoxes1, boundingBoxes2]
                let allFilePaths     = [CapturedButtonsGuideMMF3_ScreenshotPath1, CapturedButtonsGuideMMF3_ScreenshotPath2]
                let allUrls          = allFilePaths.map({ URL(fileURLWithPath: repoRoot() + "/" + String(format: $0, languageCode)) })
                for i in 0...1 {
                
                    /// Draw the images (with boundingBoxes)
                    let resultImage = NSImage.init(size: image.size, flipped: false) { rect in
                        image.draw(in: rect)
                        for var frameToHighlight in allBoundingBoxes[i] {
                            NSColor.systemRed.setStroke()
                            let rectPath = NSBezierPath()
                            rectPath.lineWidth = 3
                            frameToHighlight = frameToHighlight.insetBy(dx: -rectPath.lineWidth/2, dy: -rectPath.lineWidth/2) /// Make the line appear *outside* the frame
                            rectPath.appendRect(frameToHighlight)
                            rectPath.stroke()
                        }
                        return true
                    }
                    /// Write the images to file
                        
                    let cgImage = resultImage.cgImage(forProposedRect: nil, context: nil, hints: [:])!
                    let imageRep = NSBitmapImageRep(cgImage: cgImage) /// Could also use `CGImageDestinationCreateWithURL()` – not sure if there are differences - we care about having small, high-quality output (Since I plan to check in these images into git and display them to users in our docs)
                    let data = imageRep.representation(using: .jpeg, properties: [.compressionFactor : 0.0]) /// Lowest quality. TODO: Optimize. Idea: Downscale and compress less?
                    
                    try! FileManager.default.createDirectory(at: allUrls[i].deletingLastPathComponent(), withIntermediateDirectories: true, attributes: [:])
                    try! data?.write(to: allUrls[i], options: [.atomic])
                }
                NSWorkspace.shared.activateFileViewerSelecting(allUrls)
            }
        }
    }
    
    func sharedf_launch_app(url: URL, args: [String], env: [String: String], leave_app_running: Bool) -> XCUIApplication {
        
        if (leave_app_running) { /// This will not kill the app after the testrunner quits. And when the app is already running, it will attach the testrunner to the running app – the goal of this is to help speed-up iteration during development.
            
            let alreadyRunning = XCUIApplication(url: url).state == .notRunning
            if alreadyRunning || true { /// Open even if already running, to bring it to the foreground. Otherwise I see weird errors on .click() later [Sep 4 2025]
                let config = NSWorkspace.OpenConfiguration()
                config.arguments = args
                config.environment = env
                let semaphore = DispatchSemaphore(value: 0)
                NSWorkspace.shared.openApplication(at: url, configuration: config) { runningApp, err in semaphore.signal() }
                semaphore.wait() /// Wait until the app has opened.
            }
            var xcapp: XCUIApplication
            while (true) { /// Wait some more (not sure why this is necessary) [Sep 2025, Tahoe Beta 8]
                xcapp = XCUIApplication(url: url)
                if xcapp.state != .notRunning { break }
            }

            return xcapp
        }
        else {
            let xcapp = XCUIApplication(url: url)
            xcapp.launchArguments = args
            xcapp.launchEnvironment = env
            xcapp.launch()
            if (false) {
                let succ = xcapp.wait(for: .runningBackground, timeout: 100) /// Launch the app and wait until it has opened
                assert(succ)
            }
            return xcapp
        }
    }
    
    ///
    /// Main localizationScreenshot routine
    ///
    
    func testTakeScreenshots_Localization() throws {
        
        // --------------------------
        // MARK: Main - Localization Screenshots
        // --------------------------
        
        /// Do test intro
        let outputDir = sharedf_do_test_intro(
            outputDir:            ProcessInfo.processInfo.environment[xcode_screenshot_taker_output_dir_variable],
            fallbackTempDirName:  "MFLocalizationScreenshotsFallbackOutputFolder"
        )
        
        /// Declare result
        var screenshotsAndMetaData: [ScreenshotAndMetadata?] = []
        
        /// Log
        DDLogInfo("Localization Screenshot Test Runner launched with output directory: \(xcode_screenshot_taker_output_dir_variable): \(outputDir)")
        
        var mainApp = XCUIApplication()
        NSWorkspace.shared.openApplication(at: sharedf_mainapp_url(), configuration: NSWorkspace.OpenConfiguration())
        
        /// Prepare helper app
        ///     We should launch the helper first, and not let the app enable it, so we can control its launchArguments.
        let helperApp = XCUIApplication(url: sharedf_helper_url())
        helperApp.launchArguments.append(localized_string_annotation_activation_argument_for_screenshotted_app)
        helperApp.launch()
        
        /// Prepare mainApp
        mainApp.launchArguments.append(localized_string_annotation_activation_argument_for_screenshotted_app) /// `["-AppleLanguages", "(de)"]`
        mainApp.launch()
        
        ///
        /// Helper
        ///
        
        /// Take helper screenshots
        app = helperApp
        XCTContext.runActivity(named: "Take Helper Screenshots") { activity in
            screenshotsAndMetaData.append(contentsOf: testTakeScreenshots_Localization_NavigateHelperAppAndTakeScreenshots(outputDir))
        }
        
        ///
        /// Main App
        ///
        
        /// Take mainApp screenshots
        app = mainApp
        XCTContext.runActivity(named: "Take MainApp Screenshots") { activity in
            let newScreenshotsAndMetaData = testTakeScreenshots_Localization_NavigateAppAndTakeScreenshots(outputDir)
            screenshotsAndMetaData.append(contentsOf: newScreenshotsAndMetaData)
        }
        /// Validate with mainApp
        XCTContext.runActivity(named: "Validate Completeness") { activity in
            /// We only validate toasts. if we add a new screen or other UI to the app that should be screenshotted, we don't have a way to detect that here.
            let didShowAllToastsAndSheets = (MFMessagePort.sendMessage("didShowAllToastsAndSheets", withPayload: nil, toRemotePort: kMFBundleIDApp, waitForReply: true) as! NSNumber).boolValue
            if (!didShowAllToastsAndSheets) {
                XCTFail("The app says we missed screenshotting some toast notifications.")
            }
        }
        
        ///
        /// Write results
        ///
        
        XCTContext.runActivity(named: "Write results") { activity in
            testTakeScreenshots_Localization_writeResults(screenshotsAndMetaData, outputDir)
        }
    }
    
    // --------------------------
    // MARK: Helper Screenshots
    // --------------------------
    
    fileprivate func testTakeScreenshots_Localization_NavigateHelperAppAndTakeScreenshots( _ outputDirectory: URL) -> [ScreenshotAndMetadata?] {
        
        /// Declare result
        var result = [ScreenshotAndMetadata?]()
        
        /// Get menuBarItem
        let statusItem = app!.statusItems.firstMatch
        
        if (!statusItem.exists) {
            XCTFail("Couldn't get the the menuBarItem. Make sure to switch on 'Show in MenuBar' before running the test")
        }
        
        /// Take screenshot
        statusItem.click()
        let menu = statusItem.menus.firstMatch
        assert(menu.exists)
        let screenshot = takeLocalizationScreenshot(of: menu, name: "Status Item Menu")
        XCTAssert(screenshot != nil, "Could not take screenshots with any localization data for Status Bar Item. Perhaps, the Helper App was started without the localizedString annotation argument? (If so, close the helper and let this test-runner start it)")
        result.append(screenshot)
        
        /// Cleanup
        hitEscape()
        
        /// Return
        return result
    }
    
    // --------------------------
    // MARK: Main App Screenshots
    // --------------------------
    
    fileprivate func testTakeScreenshots_Localization_NavigateAppAndTakeScreenshots( _ outputDirectory: URL) -> [ScreenshotAndMetadata?] {
        
        /// Declare result
        var result = [ScreenshotAndMetadata?]()
        
        /// Define toast-screenshotting helper closure
        let takeToastScreenshots = { (toastSection: String, screenshotNameFormat: String) -> [ScreenshotAndMetadata?] in
            
            var toastScreenshots = [ScreenshotAndMetadata?]()
            var i = 0
            while true {
                
                /// Display next toast/sheet/popover
                let moreToastsToGo = MFMessagePort.sendMessage("showNextToastOrSheetWithSection", withPayload: (toastSection as NSString), toRemotePort: kMFBundleIDApp, waitForReply: true)
                self.coolWait() /// Wait for appear animation
                
                /// TEST
//                print("lastWasToast: \(lastWasToast)")
//                let snap = try! self.app!.snapshot()
//                let tree = TreeNode.tree(withKVCObject: snap, childrenKey: "children")
//                let toastWindowSnap = try! self.app!.dialogs["axToastWindow"].firstMatch.snapshot()
//                let toastWindowScreenshot = self.app!.dialogs["axToastWindow"].firstMatch.screenshot()
//                let testExist = self.app!.dialogs["axToastWindow"].firstMatch.exists
                
                /// Find transient window
                ///     Explanation for .isHittable usage:
                ///         When we fade out the toasts, we just set their alphaValue to 0, but they still exist in the view- and accessibility-hierarchy.
                ///         When the alphaValue is 0, `.isHittable` becomes false. That is it the easiest way I found to discern whether a toast is actually being displayed.
                var isToast = false
                var isPopover = false
                var isSheet = false
                
                var transientUIElement = self.app!.dialogs["axToastWindow"].firstMatch /// Check for toast
                if transientUIElement.exists && transientUIElement.isHittable {
                    isToast = true
                } else {
                    transientUIElement = self.app!.popovers.firstMatch /// Check for popover
                    if transientUIElement.exists && transientUIElement.isHittable {
                        isPopover = true
                    } else {
                        transientUIElement = self.app!.sheets.firstMatch /// Check for sheet
                        if transientUIElement.exists && transientUIElement.isHittable {
                            isSheet = true
                        } else {
                            assert(false)
                        }
                    }
                }
                
                if isToast {
                    
                    /// Take toast screenshot
                    toastScreenshots.append(self.takeLocalizationScreenshot(of: transientUIElement, name: String(format: screenshotNameFormat, i)))
                    
                    /// Dismiss toast
                    /// Note:
                    ///     We don't have to do this between toasts, because toasts automatically dismiss themselves before another toast comes in.
                    ///     Leveraging would allow us to speed up the test runs.
                    ///     Problem is that when we don't dismiss the toast that makes the isToast, isSheet, isPopover detection more difficult.
                    self.hitEscape()
                    self.coolWait()
                
                } else if isPopover || isSheet {
                    
                    /// Take sheet screenshot
                    toastScreenshots.append(self.takeLocalizationScreenshot(of: transientUIElement, name: String(format: screenshotNameFormat, i)))

                    /// Dismiss sheet
                    self.hitEscape()
                    self.coolWait()
                } else {
                    assert(false)
                }
                
                /// Break
                if (moreToastsToGo == nil || (moreToastsToGo! as! NSNumber).boolValue == false) {
                    break;
                }
                
                /// Increment
                i += 1
            }
            
            /// Return
            return toastScreenshots
        }
        /// Find navigation elements
        let (screen, window, toolbarButtons, menuBar) = sharedf_find_elements_for_navigating_main_app()
        
        /// Position the window
        sharedf_position_main_app_window(screen, window, targetWindowY: 0.2)
        
        /// Validate that the app is enabled
        sharedf_validate_that_main_app_is_enabled(window, toolbarButtons)
        
        ///
        /// Screenshot ButtonsTab
        ///
        
        toolbarButtons["buttons"].click()
        coolWait()
        
        /// Dismiss restoreDefaultsPopover, in case it pops up.
        hitEscape()
        coolWait()
        
        /// Screenshot states
        let restoreDefaultsButton = window.buttons["axButtonsRestoreDefaultsButton"].firstMatch
        assert(restoreDefaultsButton.exists)
        restoreDefaultsButton.click()
        let restoreDefaultsSheet = window.sheets.firstMatch
        let restoreDefaultsRadioButtons = restoreDefaultsSheet.radioButtons.allElementsBoundByIndex
        for (i, radioButton) in restoreDefaultsSheet.radioButtons.allElementsBoundByIndex.reversed().enumerated() { /// Reversed for debugging
            radioButton.click()
            hitReturn()
            hitEscape() /// Close any toasts
            result.append(takeLocalizationScreenshot(of: window, name: "ButtonsTab State \(i)"))
            restoreDefaultsButton.click() /// Open the sheet back up
        }
        
        /// Go to default state
        ///     (Default settings for 5+ buttons)
        let defaultRadioButton = restoreDefaultsSheet.radioButtons["axRestoreButtons5"]
        assert(defaultRadioButton.exists)
        defaultRadioButton.click()
        hitReturn()
        hitEscape()
        
        /// Screenshot menus
        ///     (Which let you pick the action in the remaps table)
        for (i, popupButton) in window.popUpButtons.allElementsBoundByIndex.enumerated() {
            
            /// Click
            popupButton.click()
            let menu = popupButton.menus.firstMatch
            
            /// Screenshot
            result.append(takeLocalizationScreenshot(of: menu, name: "ButtonsTab Menu \(i)"))
            
            /// Option screenshot
            XCUIElement.perform(withKeyModifiers: .option) {
                result.append(takeLocalizationScreenshot(of: menu, name: "ButtonsTab Menu \(i) (Option)"))
            }
            
            /// Clean up
            hitEscape()
        }
        
        /// Screenshot buttonsTab sheets
        ///     (The ones invoked by the two buttons in the bottom left and bottom right)
        for (i, button) in window.buttons.matching(NSPredicate(format: "identifier IN %@", ["axButtonsOptionsButton", "axButtonsRestoreDefaultsButton"])).allElementsBoundByIndex.enumerated() {
            
            /// Click
            button.click()
            coolWait() /// Not necessary. Sheets have a native animation where XCUITest automatically correctly
            
            /// Get sheet
            let sheet = window.sheets.firstMatch
            
            /// Screenshot
            result.append(takeLocalizationScreenshot(of: sheet, name: "ButtonsTab Sheet \(i)"))
            
            /// Cleanup
            hitEscape()
        }
        
        /// Screenshots ButtonsTab toasts
        result.append(contentsOf: takeToastScreenshots("buttons", "ButtonsTab Toast %d"))
        
        ///
        /// Screenshot GeneralTab
        ///
        
        /// Switch to general tab
        toolbarButtons["general"].click()
        coolWait() /// Need to wait so that the test runner properly waits for the animation to finish
        
        /// Enable updates
        ///     (So that the beta section is expanded)
        let updatesToggle = window.checkBoxes["axCheckForUpdatesToggle"].firstMatch
        if (updatesToggle.value as! Int) != 1 {
            updatesToggle.click()
            coolWait()
        }
        
        /// Take screenshot of fully expanded general tab
        result.append(takeLocalizationScreenshot(of: window, name: "GeneralTab"))

        /// Screenshot toasts
        result.append(contentsOf: takeToastScreenshots("general", "GeneralTab Toast %d"))
        
        ///
        /// Screenshot menubar
        ///
        
        /// Screenshot menuBar itself
        result.append(takeLocalizationScreenshot(of: menuBar, name: "MenuBar"))
        
        /// Screenshot each menuBarItem
        var didClickMenuBar = false
        for (i, menuBarItem) in menuBar.menuBarItems.allElementsBoundByIndex.enumerated() {
            
            /// Skip Apple menu
            if i == 0 { continue }
            
            /// Reveal menu
            if !didClickMenuBar {
                menuBarItem.click()
                didClickMenuBar = true
            } else {
                menuBarItem.hover()
            }
            let menu = menuBarItem.menus.firstMatch
            
            /// Take screenshot of menu
            result.append(takeLocalizationScreenshot(of: menu, name: "MenuBar Menu \(i)"))
            
            /// Take screenshot with option held (reveal secret/alternative menuItems)
            XCUIElement.perform(withKeyModifiers: .option) {
                result.append(takeLocalizationScreenshot(of: menu, name: "MenuBar Menu \(i) (Option)"))
            }
        }
        
        /// Dismiss menu
        if didClickMenuBar {
            hitEscape()
        }
        
        ///
        /// Screenshot special views only accessible through the menuBar
        ///
        
        /// Find "activate" license menu item
        let macMouseFixMenuItem = menuBar.menuBarItems.allElementsBoundByIndex[1]
        macMouseFixMenuItem.click()
        let macMouseFixMenu = macMouseFixMenuItem.menus.firstMatch
        let activateLicenseItem = macMouseFixMenu.menuItems["axMenuItemActivateLicense"].firstMatch
        
        /// Click
        activateLicenseItem.click()
        
        /// Delete license key
        /// Delete license key from the textfield, so it's hidden in the screenshot, and the placeholder appears instead
        app?.typeKey(.delete, modifierFlags: [])
        
        /// Find sheet
        var sheet = window.sheets.firstMatch
        
        /// Sheenshot
        result.append(takeLocalizationScreenshot(of: sheet, name: "ActivateLicenseSheet"))
        
        /// Screenshot toasts
        result.append(contentsOf: takeToastScreenshots("licensesheet", "ActivateLicenseSheet Toast %d"))
        
        /// Cleanup licenseSheet
        hitEscape()
        
        ///
        /// Screenshot AboutTab
        ///
        
        toolbarButtons["about"].click()
        coolWait()
        result.append(takeLocalizationScreenshot(of: window, name: "AboutTab"))
        
        /// Screenshot alert
        
        /// Click
        window.staticTexts["axAboutSendEmailButton"].firstMatch.click()
        
        /// Get sheet
        sheet = window.sheets.firstMatch
        
        /// Screenshot
        result.append(takeLocalizationScreenshot(of: sheet, name: "AboutTab Email Alert"))
        
        /// Cleanup
        hitEscape()
        
        ///
        /// Screenshot ScrollingTab
        ///
        
        toolbarButtons["scrolling"].click()
        coolWait()
        
        /// Initialize state of tab
        let restoreDefaultModsButton = window.buttons["axScrollingRestoreDefaultModifiersButton"].firstMatch
        if restoreDefaultModsButton.exists {
            restoreDefaultModsButton.click()
        }
        
        /// Screenshot states
        for (i, popUpButton) in window.popUpButtons.allElementsBoundByIndex.enumerated() {
            
            /// Gather menu items
            popUpButton.click()
            let menuItems = popUpButton.menuItems.allElementsBoundByIndex.enumerated()
            hitEscape()
            
            for (j, menuItem) in menuItems {
                
                /// Click popUpButton
                popUpButton.click()
                if (!menuItem.isHittable || !menuItem.isEnabled) {
                    hitEscape()
                    continue
                }
                
                /// Click menu item
                menuItem.click()
                coolWait()
                
                /// Screenshot state of scrolling tab
                result.append(takeLocalizationScreenshot(of: window, name: "ScrollingTab State \(i)-\(j)"))
            }
        }
        
        /// Screenshot scrollingTab menus
        for (i, popUpButton) in window.popUpButtons.allElementsBoundByIndex.enumerated() {
            
            /// Click popup button
            popUpButton.click()
            let menu = popUpButton.menus.firstMatch
            
            /// Take screenshot
            result.append(takeLocalizationScreenshot(of: menu, name: "ScrollingTab Menu \(i)"))
            XCUIElement.perform(withKeyModifiers: .option) {
                if ((false)) { /// The menus on the scrolling tab don't have secret options, at least at the time of writing. NOTE: Update this if you add secret options.
                    result.append(takeLocalizationScreenshot(of: menu, name: "ScrollingTab Menu \(i) (Option)"))
                }
            }
            
            /// Cleanup
            hitEscape()
        }
        
        /// Screenshots ScrollingTab toasts
        result.append(contentsOf: takeToastScreenshots("scrolling", "ScrollingTab Toast %d"))
        
        ///
        /// Return
        ///
        
        return result
    }
    
    // --------------------------
    // MARK: Write results
    // --------------------------
    
    fileprivate func testTakeScreenshots_Localization_writeResults(_ screenshotsAndMetadata: [ScreenshotAndMetadata?], _ outputDirectory: URL) {
        
        /// Write the screenshots and their metadata in the format found inside `.xcloc` localization catalogs [Aug 2025]
        
        /// Convert screenshotsAndMetadata to localizedStringData.plist structure
        var screenshotNameToScreenshotDataMap = [String: Data]()
        var localizedStringData: LocalizedStringData = []
        for scr in screenshotsAndMetadata {
            
            guard let scr = scr else { continue }
            
            var screenshotUsageCount = 0
            
            let screenshot = scr.screenshot
            let screenshotName = scr.metadata.screenshotName
            for fr in scr.metadata.screenshotAnnotations {
                let stringFrame = fr.frame
                for str in fr.localizableStringsInFrame {
                    let localizedString = str.uiString
                    for k in str.stringAnnotations {
                        let stringKey = k.key
                        var stringTable = k.table
                        
                        /// Map empty table to "Localizable"
                        ///     Otherwise the Xcode screenshot viewer breaks.
                        if stringTable == "" { stringTable = "Localizable" }
                        
                        /// Duplicate screenshot
                        ///     Each stringKey needs its own, unique screenshot file, otherwise the Xcode viewer breaks and shows the same frame for every string key. (Tested under Xcode 15 stable & Xcode 16 Beta)
                        screenshotUsageCount += 1
                        let screenshotName = "\(screenshotUsageCount). Copy - \(screenshotName).jpeg"
                        
                        /// Convert image
                        ///     In the WWDC demos they used jpeg, but .png is a bit higher res I think.
                        guard let bitmap = screenshot.image.representations.first as? NSBitmapImageRep else { fatalError() }
                        let imageData = bitmap.representation(using: .jpeg, properties: [:])
                        
                        /// Store name -> screenshot mapping
                        screenshotNameToScreenshotDataMap[screenshotName] = imageData
                        
                        /// Store the encodable data (everything except the screenshot itself) to the localizedStringData datastructure
                        var didAttachToExistingDatum = false
                        let newScreenshotData = LocalizedStringDatum.Screenshot(name: screenshotName, frame: NSStringFromRect(stringFrame))
                        for (i, var existingDatum) in localizedStringData.enumerated() {
                            if existingDatum.stringKey == stringKey && existingDatum.tableName == stringTable {
                                existingDatum.screenshots.append(newScreenshotData)
                                localizedStringData[i] = existingDatum /// Need to directly assign to index due to Swift value types
                                assert(!didAttachToExistingDatum)
                                didAttachToExistingDatum = true
                            }
                        }
                        if !didAttachToExistingDatum {
                            let newDatum = LocalizedStringDatum(stringKey: stringKey, screenshots: [newScreenshotData], tableName: stringTable, bundlePath: "some/path", bundleID: "some.id")
                            localizedStringData.append(newDatum)
                        }
                    }
                }
            }
        }
        
        /// Create the output directory
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: outputDirectory.path()) {
            do {
                try fileManager.createDirectory(atPath: outputDirectory.path(), withIntermediateDirectories: true, attributes: nil)
                DDLogInfo("Output directory created: \(outputDirectory)")
            } catch {
                XCTFail("Error creating output directory: \((error as NSError).code) : \((error as NSError).domain)") /// This is a weird attempt at getting a non-localized description of the string
                return
            }
        }
        
        /// Write metadata to file
        do {
            let plistFileName = xcode_screenshot_taker_outputted_metadata_filename
            let plistFilePath = (outputDirectory.path() as NSString).appendingPathComponent(plistFileName)
            let plistData = try PropertyListEncoder().encode(localizedStringData)
            try plistData.write(to: URL(fileURLWithPath: plistFilePath))
        } catch {
            XCTFail("Error: Failed to write screenshot metadata to file as json: \(error) \((error as NSError).code) : \((error as NSError).domain)")
        }
        
        /// Write screenshots to file
        for (screenshotName, screenshotData) in screenshotNameToScreenshotDataMap {
            let filePath = (outputDirectory.path() as NSString).appendingPathComponent(screenshotName)
            do {
                try screenshotData.write(to: URL(fileURLWithPath: filePath))
            } catch {
                XCTFail("Error: Failed to screenshot to file: \((error as NSError).code) : \((error as NSError).domain)")
            }
        }
        
        /// Log
        DDLogInfo("Wrote result to output directory \(outputDirectory.path())")
    }
    
    // --------------------------
    // MARK: Take Screenshot
    // --------------------------
    
    func takeLocalizationScreenshot(of element: XCUIElement, name screenshotBaseName: String) -> ScreenshotAndMetadata? {
        var result: ScreenshotAndMetadata? = nil
        do {
            result = try _takeLocalizationScreenshot(of: element, name: screenshotBaseName)
        } catch {
            DDLogInfo("Taking Localization screenshot threw error: \(error)")
        }
        return result
    }
    
    func _takeLocalizationScreenshot(of topLevelElement: XCUIElement, name screenshotBaseName: String) throws -> ScreenshotAndMetadata? {
        
        /// Windows and the menuBar are examples of topLevelElements
        ///     If we screenshot them separately we can screenshot all the UI our app is displaying without screenshotting the whole screen.
        
        /// Take screenshot
        let screenshot = topLevelElement.screenshot()
        
        /// Get screenshot frame
        var screenshotFrame = topLevelElement.screenshotFrame()
        
        /// Validate screenshot frame
        let displayBounds: CGRect = CGDisplayBounds(topLevelElement.screen().displayID()); /// Not sure if we should be flipping the coords
        let screenshotFrameOnScreenArea = screenshotFrame.intersection(displayBounds)
        if !screenshotFrame.equalTo(screenshotFrameOnScreenArea)  {
            if ((false)) { /// This check makes sense for menus inside the window, but for the menuBar menus this invevitably fails.
                XCTFail("Error: Screenshot would be cut off by the edge of the screen. Move the window to the center of the screen to prevent this.")
            } else {
                screenshotFrame = screenshotFrameOnScreenArea
            }
        }
        
        /// Get snapshot of ax hierarchy of topLevelElement
        let snapshot: XCUIElementSnapshot?
        do {
            snapshot = try topLevelElement.snapshot()
        } catch {
            snapshot = nil
        }
        
        /// Convert ax hierarchy to tree
        let tree = TreeNode<XCUIElementSnapshot>.tree(withKVCObject: snapshot!, childrenKey: "children")
        
        /// TEST
//        let treeDescription = tree.description()
//        DDLogInfo("The tree: \(treeDescription)")
        
        /// Find localizedStings
        ///     & their metadata
        var framesAndStringsAndKeys: [ScreenshotAndMetadata.Metadata.Frame] = []
        for nodeAsAny in tree.depthFirstEnumerator() {
            
            /// Unpack node
            let node = nodeAsAny as! TreeNode<XCUIElementSnapshot>
            let nodeSnapshot: XCUIElementSnapshot = node.representedObject!
            
            /// Get the underlying AXUIElement
            ///     (since its strings dont have 512 character limit we see in the nodeSnapshot.dictionaryRepresentation())
            ///     (We made a bunch of other decisions based on the 512 character limit, such as using space-efficient quaternaryEncoding for the secretMessages, now the limit doesn't exist anymore.)
            let axuiElement = getAXUIElementForXCElementSnapshot(nodeSnapshot)!.takeUnretainedValue()
            
            /// Get all attr names
            var attrNames: CFArray?
            AXUIElementCopyAttributeNames(axuiElement, &attrNames)
            
            /// Iterate attr names and get their values + any secret messages
            var stringsAndSecretMessages: [String: [FoundSecretMessage]] = [:]
            for attrName in (attrNames! as NSArray) {
                
                /// Get axAttr value
                var attrValue: CFTypeRef?
                AXUIElementCopyAttributeValue(axuiElement, (attrName as! CFString), &attrValue)
                
                /// Check: Is it a string?
                guard let string = attrValue as? String else {
                    continue
                }
                
                /// Extract any secret messages
                let secretMessages = string.secretMessages() as! [FoundSecretMessage]
                
                /// Skip if no secret messages
                if secretMessages.count == 0 {
                    continue
                }
                
                /// Store secret mesages
                stringsAndSecretMessages[string] = secretMessages
            }
            
            /// Skip
            ///     If this node doesn't have secretMessages
            if stringsAndSecretMessages.count == 0 {
                continue
            }
            
            /// Extract localization key+table from each secret message
            var localizedStrings = [ScreenshotAndMetadata.Metadata.Frame.String_]()
            for (string, secretMessages) in stringsAndSecretMessages {
                
                var localizationKeys = [ScreenshotAndMetadata.Metadata.Frame.String_.XCStringsData]()
                var prefixStack: [(found: FoundSecretMessage, key: String, table: String)]  = []
                for secretMessage in secretMessages {
                    if localized_string_annotation_suffix == secretMessage.secretMessage { /// Parse suffix
                        let lastPrefix = prefixStack.popLast()!
                        let prefixEnd = lastPrefix.found.rangeInString.upperBound
                        let suffixStart = secretMessage.rangeInString.lowerBound
                        let uiStringAfterLastPrefix = (string as NSString).substring(with: NSMakeRange(
                            prefixEnd,
                            suffixStart - prefixEnd
                        ))
                        localizationKeys.append(ScreenshotAndMetadata.Metadata.Frame.String_.XCStringsData(key: lastPrefix.key, table: lastPrefix.table, uiString: uiStringAfterLastPrefix))
                    }
                    else { /// Parse Prefix
                    
                        let prefix_regex = try NSRegularExpression(pattern: localized_string_annotation_prefix_regex, options: [])
                        let prefix_matches = prefix_regex.matches(in: secretMessage.secretMessage, options: [.anchored], range: .init(location: 0, length: secretMessage.secretMessage.utf16.count)) /// NSString and related objc classes are based on UTF16 so we should do .utf16 afaik
                        assert(prefix_matches.count <= 1)
                        
                        
                        if let match = prefix_matches.first {
                            assert(match.numberOfRanges == 3) /// Full match + 3 capture groups
                            if let keyRange   = Range(match.range(at: 1), in: secretMessage.secretMessage),
                               let tableRange = Range(match.range(at: 2), in: secretMessage.secretMessage)
                            {
                                prefixStack.append((secretMessage, key: String(secretMessage.secretMessage[keyRange]), table: String(secretMessage.secretMessage[tableRange])))
                            }
                        }
                    }
                }
                /// Append to result
                if localizationKeys.count > 0 {
                    localizedStrings.append(ScreenshotAndMetadata.Metadata.Frame.String_(uiString: string, stringAnnotations: localizationKeys))
                }
            }
            
            /// Guard: No localizedStrings for this node
            guard !localizedStrings.isEmpty else {
                continue
            }
            
            /// Get frame for this node
            var frame = nodeSnapshot.frame
            guard frame != .zero else {
                assert(false)
                continue
            }
            
            /// Guard: hitTest
            ///     This slows down the screenshot-taking noticably, so we're trying to do this as late as possible (after all the other filters)
            ///     What we really want to know is whether the element will be visible in our screenshots, but hit-testing like this is the closest I can find.
            /// Discussion:
            ///     We call `AXUIElementCopyElementAtPosition()` with the hitPoint that the element represented by `node` reports to have, and see if it returns a different element. If so, we assume that the element is
            ///     invisible or covered up by another element.
            ///     This successfully filters out alternate NSMenuItems, collapsed and swapped out stackViews (See Collapse.swift), and perhaps more.
            ///     I'm not sure if there are any false positives. Update: There don't seem to be.
            /// Alternatives:
            ///     The core of this is `AXUIElementCopyElementAtPosition()`, which is a little slow.
            ///     We also tried to use `XCUIHitPointResult.isHittable()` but that still returns true for the hidden/obscured elements we want to filter out.
            ///     We also tried to use the private `-[XCElementSnapshot hitTest]:`, but I think I couldn't figure out how to use it correctly, before we found the `AXUIElementCopyElementAtPosition()` approach.
            var hittedAXUIElement: AXUIElement? = nil
            var idk: AnyObject? = nil
            let hitPoint: XCUIHitPointResult = hitPointForSnapshot_ForSwift(nodeSnapshot, &idk)!
            assert(idk == nil)
            let rawHitPoint: NSPoint = hitPoint.hitPoint()
            AXUIElementCopyElementAtPosition(appAXUIElement!, Float(rawHitPoint.x), Float(rawHitPoint.y), &hittedAXUIElement) /// This is a little slow
            if let hittedAXUIElement = hittedAXUIElement, hittedAXUIElement == axuiElement {
            } else {
                if !alreadyLoggedHitTestFailers.contains(axuiElement) {
                    print("HitTest Failed: Skipping annotation of element: \(nodeSnapshot) || Skipped keys: \(localizedStrings.flatMap { s in s.stringAnnotations.map { k in k.key } })") /// If hitTest fails, the element is probably invisible or covered by another element.
                    alreadyLoggedHitTestFailers.append(axuiElement) /// We want to log all the elements that are filtered out due to failed hitTests - to check if there are any false positives. (Check if we still end up with correct annotations for those hitTestFailers in the resulting .xcloc file)
                }
                continue
            }
            
            /// Convert coordinate system of frame from screen coords to screenshot coords
            frame = sharedf_snapshot_frame_to_screenshot_frame(frame, screenshot_frame_in_screen: screenshotFrame)
            
            /// Append to result
            
            framesAndStringsAndKeys.append(ScreenshotAndMetadata.Metadata.Frame(frame: frame, localizableStringsInFrame: localizedStrings))
        }
        
        /// Filter out invalid frames
        ///     - Hidden (zero-height) menu items show up with height 2 - want to filter them out
        ///     - Update: The hitTest already filters the zero-height elements out, so this is unnecessary now.
        let groupedFrames = Dictionary(grouping: framesAndStringsAndKeys) { frameAndStringAndKey in
            let isValidFrame = frameAndStringAndKey.frame.width >= 5 && frameAndStringAndKey.frame.height >= 5
            return isValidFrame
        }
        let validFramesAndStringsAndKeys = groupedFrames[true]
        
        /// Validate
        let invalidFramesAndStringsAndKeys = groupedFrames[false]
        if (invalidFramesAndStringsAndKeys != nil) {
            assert(topLevelElement.elementType == XCUIElement.ElementType.menuBar ||
                   topLevelElement.elementType == XCUIElement.ElementType.menu)
        }
        
        /// Store result
        if let f = validFramesAndStringsAndKeys {
            let thisResult = ScreenshotAndMetadata(screenshot: screenshot,
                                                   metadata: ScreenshotAndMetadata.Metadata(screenshotName: screenshotBaseName,
                                                                                            screenshotFrame: screenshotFrame,
                                                                                            snapshotTree: tree,
                                                                                            screenshotAnnotations: f))
            return thisResult
        } else {
            return nil
        }
    }
    
    // --------------------------
    // MARK: Helper
    // --------------------------
    
    func hitEscape() {
        app?.typeKey(.escape, modifierFlags: [])
    }
    func hitReturn() {
        app?.typeKey(.return, modifierFlags: [])
    }
    func coolWait() {
        usleep(useconds_t(Double(USEC_PER_SEC) * 0.5))
        app?._waitForQuiescence()
    }
}

func ScreenshotAndMetadata_description_from_key_value_pairs(_ pairs: [(String, CustomStringConvertible)]) -> String {
    
    /// [Aug 2025] Helper for printing `struct ScreenshotAndMetadata`, because default swift description is extremely verbose
    ///     Have to define this far away, at file scope, cause of weird Swift compiler errors
    
    func addIndent(_ s: String) -> String { return s.replacingOccurrences(of: "(^|\n)(.)", with: "$1    $2", options: [.regularExpression]) } /// [Aug 2025] We have multiple implementations for indenting strings across the codebase but they didn't work properly here for some reason. (Tried `.string(byAddingIndent: 4, withCharacter: " ")`)
    
    var result = "{"
    
    for (i, (k, v)) in pairs.enumerated() {
        result += "\n    "
        
        let vDesc: String
        
        if let v = v as? Swift.Array<CustomStringConvertible> {
            let descs = v.map { x in x.description }
            let descsHaveNoLinebreaks = descs.allSatisfy({ desc in !desc.contains("\n") })
            if descsHaveNoLinebreaks    { vDesc = "[\(descs.joined(separator: ", "))]" }
            else                        { vDesc = "[\n\(addIndent(descs.joined(separator: ",\n")))\n]" }
        }
        else { vDesc = v.description; }
                    
        if vDesc.contains("\n") {
            result += "\(k):\n\(addIndent(vDesc))"
        } else {
            result += "\(k): \(vDesc)"
        }
    }
    
    result += "\n}"
    
    return result
}

func currentFilePath(_path: NSString = #file) -> NSString {
    return _path
}
