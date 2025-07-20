//
// --------------------------------------------------------------------------
// ScrollConfig.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

import Cocoa

@objc class ScrollConfig: NSObject, NSCopying /*, NSCoding*/ {
    
    /// This class has almost all instance properties
    /// You can request the config once, then store it.
    /// You'll receive an independent instance that you can override with custom values. This should be useful for implementing Modifications in Scroll.m
    ///     Everything in ScrollConfigResult is lazy so that you only pay for what you actually use
    /// Edit: Since we're always copying the scrollConfig before returning to apply some overrides, all this lazyness is sort of useless I think. Because during copy, all the lazy computed properties will be calculated from what I've seen. But this will only happen during the first copy, so it's whatever.
    ///
    /// Ideas for improving Smoothness: Regular [Apr 2025]
    ///         (Not sure this belongs here – do we have notes on this somewhere else?)
    ///     - Ease-out too slow on Smoothness: Regular?
    ///         I tested MMF 2 and after going back to MMF 3 the regular scrolling felt a bittt too slow. [Apr 2025]
    ///             One day I was kinda stressed out n angry and wanted to scan pages for something I was looking for. So you make lots of quick, large scrolls, followed by pauses to scan the page visually. The ease-out animation after the quick large scrolls felt a bit too long.
    ///             ... But now that I've used MMF 3 for a while and have calmed down, I don't feel that way anymore. It feels quite nice.
    ///     - Allow Increasing 'speed' for Smoothness: Regular by dynamically increasing animation duration?
    ///         IIRC, the 'speed' (sensitivity/acceleration) gets lower as you lower the smoothness. IIRC, this is because shortAnimations + high 'speed' means content moves so fast that it becomes jarring/disorientating for the eyes.
    ///         However, the lower 'speed' makes scrolling take more physical effort on lower smoothness settings, which I don't like.
    ///         Idea: Dynamically increase animation duration on large 'swipes' such that content doesn't move so fast as to be jarring. Then you could perhaps turn up the 'speed' for 'Smoothness: Regular'.
    
    // MARK: Convenience functions
    ///     For accessing top level dict and different sub-dicts
    
    private static var _scrollConfigRaw: NSDictionary? = nil /// This needs to be static, not an instance var. Otherwise there are weird crashes in Scroll.m. Not sure why.
    private func c(_ keyPath: String) -> NSObject? {
        return ScrollConfig._scrollConfigRaw?.object(forCoolKeyPath: keyPath) /// Not sure whether to use coolKeyPath here?
    }
    
    // MARK: Static functions
    
    @objc private(set) static var shared = ScrollConfig() /// Singleton instance
    
    @objc static func reload() {
        
        /// Guard not equal
        
        let newConfigRaw = config("Scroll") as! NSDictionary?
        guard !(_scrollConfigRaw?.isEqual(newConfigRaw) ?? false) else {
            return
        }
        
        /// Notes:
        /// - This should be called when the underlying config (which mirrors the config file) changes
        /// - All the property values are cached in `currentConfig`, because the properties are lazy. Replacing with a fresh object deletes this implicit cache.
        /// - TODO: Make a copy before storing in `_scrollConfigRaw` just to be sure the equality checks always work
        shared = ScrollConfig()
        _scrollConfigRaw = newConfigRaw
        cache = nil
//        ReactiveScrollConfig.shared.handleScrollConfigChanged(newValue: shared)
        SwitchMaster.shared.scrollConfigChanged(scrollConfig: shared)
    }
    @objc static func devToggles_deleteCache() { /// [May 2025] Added this function as a hack for DevToggles.m
        shared = ScrollConfig()
        cache = nil
    }
    private static var cache: [_HT<MFScrollModificationResult, MFAxis, CGDirectDisplayID>: ScrollConfig]? = nil
    
    // MARK: Overrides
    
    @objc static func scrollConfig(modifiers: MFScrollModificationResult, inputAxis: MFAxis, display: CGDirectDisplayID) -> ScrollConfig {
        
        /// Try to get result from cache
        
        if cache == nil {
            cache = .init()
        }
        let key = _HT(a: modifiers, b: inputAxis, c: display)
        
        if let fromCache = cache![key] {
            return fromCache

        } else {
            
            /// Cache retrieval failed -> Recalculate result
            
            /// Copy og settings
            let new = shared.copy() as! ScrollConfig
            
            /// Declare overridables
            var u_speed = new.u_speed
            var precise = new.u_precise
            var useQuickMod = modifiers.inputMod == kMFScrollInputModificationQuick
            var usePreciseMod = modifiers.inputMod == kMFScrollInputModificationPrecise
            var scaleToDisplay = true
            var animationCurveOverride: MFScrollAnimationCurveName? = nil
            
            ///
            /// Override settings
            ///
            
            /// 1. effectModifications
            if modifiers.effectMod == kMFScrollEffectModificationHorizontalScroll {
                
                
            } else if modifiers.effectMod == kMFScrollEffectModificationZoom {
                
                /// Override animation curve
                animationCurveOverride = kMFScrollAnimationCurveNameTouchDriver
                
                /// Adjust speed params
                scaleToDisplay = false
                
            } else if modifiers.effectMod == kMFScrollEffectModificationRotate {
                
                /// Override animation curve
                animationCurveOverride = kMFScrollAnimationCurveNameTouchDriver
                
                /// Adjust speed params
                scaleToDisplay = false
                
            } else if modifiers.effectMod == kMFScrollEffectModificationCommandTab {
                
                /// Disable animation
                animationCurveOverride = kMFScrollAnimationCurveNameNone
                
            } else if modifiers.effectMod == kMFScrollEffectModificationThreeFingerSwipeHorizontal {
                
                /// Override animation curve
                animationCurveOverride = kMFScrollAnimationCurveNameTouchDriverLinear;
                
                /// Adjust speed params
                precise = false
                if u_speed == kMFScrollSpeedSystem {
                    u_speed = kMFScrollSpeedMedium
                }
                scaleToDisplay = false
                
                /// Turn off inputMods
                useQuickMod = false
                usePreciseMod = false
                
                /// Disable speedup
                new.fastScrollCurve = nil
                
            } else if modifiers.effectMod == kMFScrollEffectModificationFourFingerPinch {
                
                /// Override animation curve
                animationCurveOverride = kMFScrollAnimationCurveNameTouchDriverLinear;
                
                /// Adjust speed params
                precise = false
                if u_speed == kMFScrollSpeedSystem {
                    u_speed = kMFScrollSpeedMedium
                }
                scaleToDisplay = false
                
                /// Turn off inputMods
                useQuickMod = false
                usePreciseMod = false
                
                /// Disable speedup
                new.fastScrollCurve = nil
                
            } else if modifiers.effectMod == kMFScrollEffectModificationNone {
            } else if modifiers.effectMod == kMFScrollEffectModificationAddModeFeedback {
                /// We don't wanna scroll at all in this case but I don't think it makes a difference.
            } else {
                assert(false);
            }
            
            /// 2. inputModifications
            
            if useQuickMod {
                
                /// Set animationCurve
                /// - Only do this if the effectMods haven't set their own curve already. That way effectMod animationCurves override quickMod animationCurve. We want this because the quickMod curve can be super long and inertial which feels really bad if you're e.g. trying to zoom.
                /// - Idea: If we only send the effects while the animationCurve is in the gesturePhase we might not need this? But the gesture phase curve is just linear which would feel non-so-smooth.
                /// - Should we also do this for preciseMod? If we use the linear touchDriver curve and then override it with the eased-out preciseMod curve that might not be what we want. But I think wherever we use the linear touchDriver curve we ignore preciseMod and QuickMod anyways
                
                if animationCurveOverride == nil {
                    animationCurveOverride = kMFScrollAnimationCurveNameQuickScroll
                }
                
                /// Adjust speed params
                precise = false
                scaleToDisplay = false /// Is scaled to windowSize instead
                
                /// Make fastScroll easier to trigger
                new.consecutiveScrollSwipeMaxInterval = 725.0/1000.0
                new.consecutiveScrollTickIntervalMax = 200.0/1000.0
                new.consecutiveScrollSwipeMinTickSpeed = 12.0
                
                /// Amp-up fastScroll
                new.fastScrollCurve = ScrollSpeedupCurve(swipeThreshold: 1, initialSpeedup: 2.0, exponentialSpeedup: 10)
                
            } else if usePreciseMod {
                
                /// Set animationCurve
                /// The idea is that:
                /// - inputMods may only override effectMod animationCurve overrides, if that shortens the animation. Because you don't want long animations during scroll-to-zoom, scroll-to-reveal-desktop, etc.
                /// - The precise input mod should never turn on smoothScrolling.
                if (animationCurveOverride == nil && new.animationCurve != kMFScrollAnimationCurveNameNone)
                    || (animationCurveOverride != nil && animationCurveOverride != kMFScrollAnimationCurveNameNone) {
                    
                    animationCurveOverride = kMFScrollAnimationCurveNamePreciseScroll
                }
                
                /// Adjust speed params
                precise = false
                scaleToDisplay = false
                
                /// Turn off fast scroll
                new.fastScrollCurve = nil
            }
            
            /// Apply animationCurve override
            if let ovr = animationCurveOverride {
                new.animationCurve = ovr
            }
            
            /// Get accelerationCurve
            if u_speed == kMFScrollSpeedSystem && !usePreciseMod && !useQuickMod {
                new.accelerationCurve = nil
            } else {
                new.accelerationCurve = getAccelerationCurve(forSpeed: u_speed, precise: precise, smoothness: new.u_smoothness, animationCurve: new.animationCurve, inputAxis: inputAxis, display: display, scaleToDisplay: scaleToDisplay, modifiers: modifiers, useQuickModSpeed: useQuickMod, usePreciseModSpeed: usePreciseMod, consecutiveScrollTickIntervalMax: new.consecutiveScrollTickIntervalMax, consecutiveScrollTickInterval_AccelerationEnd: new.consecutiveScrollTickInterval_AccelerationEnd)
            }
            
            /// Cache & return
            cache![key] = new
            return new
            
        }
    }
    
    // MARK: ???
    
    @objc static var linearCurve: Bezier = { () -> Bezier in
        
        let controlPoints: [P] = [_P(0,0), _P(0,0), _P(1,1), _P(1,1)]
        
        return Bezier(controlPoints: controlPoints, defaultEpsilon: 0.001) /// The default defaultEpsilon 0.08 makes the animations choppy
    }()
    
//    @objc static var stringToEventFlagMask: NSDictionary = ["command" : CGEventFlags.maskCommand,
//                                                            "control" : CGEventFlags.maskControl,
//                                                            "option" : CGEventFlags.maskAlternate,
//                                                            "shift" : CGEventFlags.maskShift]
    
    // MARK: Derived
    /// For convenience I guess? Should probably remove these
    
    
    @objc var smoothEnabled: Bool {
        /// Does this really have to exist?
        return _animationCurveName != kMFScrollAnimationCurveNameNone
    }
    @objc var useAppleAcceleration: Bool {
        return accelerationCurve == nil
    }
    
    // MARK: Invert Direction
    
    @objc lazy var u_invertDirection: MFScrollInversion = {
        /// This can be used as a factor to invert things. kMFScrollInversionInverted is -1.
        
//        if HelperState.shared.isLockedDown { return kMFScrollInversionNonInverted }
        return c("reverseDirection") as! Bool ? kMFScrollInversionInverted : kMFScrollInversionNonInverted
    }()
    
    // MARK: Old Invert Direction
    /// Rationale: We used to have the user setting be "Natural Direction" but we changed it to being "Reverse Direction". This is so it's more transparent to the user when Mac Mouse Fix is intercepting the scroll input and also to have the SwitchMaster more easily decide when to turn the scrolling tap on or off. Also I think the setting is slightly more intuitive this way.
    
//    @objc func scrollInvert(event: CGEvent) -> MFScrollInversion {
//        /// This can be used as a factor to invert things. kMFScrollInversionInverted is -1.
//
//        if HelperState.shared.isLockedDown { return kMFScrollInversionNonInverted }
//
//        if self.u_direction == self.semanticScrollInvertSystem(event) {
//            return kMFScrollInversionNonInverted
//        } else {
//            return kMFScrollInversionInverted
//        }
//    }
    
//    lazy private var u_direction: MFSemanticScrollInversion = {
//        c("naturalDirection") as! Bool ? kMFSemanticScrollInversionNatural : kMFSemanticScrollInversionNormal
//    }()
//    private func semanticScrollInvertSystem(_ event: CGEvent) -> MFSemanticScrollInversion {
//
//        /// Accessing userDefaults is actually surprisingly slow, so we're using NSEvent.isDirectionInvertedFromDevice instead... but NSEvent(cgEvent:) is slow as well...
//        ///     .... So we're using our advanced knowledge of CGEventFields!!!
//
////            let isNatural = UserDefaults.standard.bool(forKey: "com.apple.swipescrolldirection") /// User defaults method
////            let isNatural = NSEvent(cgEvent: event)!.isDirectionInvertedFromDevice /// NSEvent method
//        let isNatural = event.getIntegerValueField(CGEventField(rawValue: 137)!) != 0; /// CGEvent method
//
//        return isNatural ? kMFSemanticScrollInversionNatural : kMFSemanticScrollInversionNormal
//    }
    
    // MARK: Inverted from device flag
    /// Notes:
    /// - This flag will be set on GestureScroll events, as well as DockSwipe, and maybe other events and and will invert some interactions like scrolling to delete messages in Mail
    /// - Why did we decide to always have this off? My guess is that invertedFromDevice is meant to preserve physical relationship between fingers and UI for interactions like delete messages in Mail, but since this physical relationship doesn't exist on the scrollwheel, it makes sense to just set this to a constant value independent of scroll inversion. However, it might be better to always turn *on* invertedFromDevice, instead of keeping it turned *off*, since that's the default setting in macOS, and turning it off leads to bugs when sending pinch type Dock swipes to open Launchpad. We implemented a workaround for this bug, but still should be better to always turn this on. 
    ///     - Edit: Always turning inverted from device **on** now. Seems to work fine so far. It makes the direction of unread-swipes in Mail make more sense.
    
    @objc let invertedFromDevice = true;
    
    // MARK: Analysis
    
    @objc lazy var scrollSwipeThreshold_inTicks: Int = 2 /*other["scrollSwipeThreshold_inTicks"] as! Int;*/ /// If `scrollSwipeThreshold_inTicks` consecutive ticks occur, they are deemed a scroll-swipe.
    
    @objc lazy var scrollSwipeMax_inTicks: Int = 11 /// Max number of ticks that we think can occur in a single swipe naturally (if the user isn't using a free-spinning scrollwheel). (See `consecutiveScrollSwipeCounter_ForFreeScrollWheel` definition for more info)
    
    @objc lazy var consecutiveScrollTickIntervalMax: TimeInterval = SharedUtilitySwift.eval {
        
        switch animationCurve {
        case kMFScrollAnimationCurveNameNone:            160.0/1000
        case kMFScrollAnimationCurveNameVeryLowInertia:  /*200.0*/160.0/1000 /// Increasing this to 200 (vs the 160 we're using everywhere else) since we want the acceleration curve to kick in at lower finger-speeds [Jun 4 2025] || Update: [Jul 2025] IIRC, I decided lowering to 200 didn't make sense and 160 was already the lowest thing that feels "consecutive" at all, and what we probably want to do instead is change the shape of the acceleration curve.
        case kMFScrollAnimationCurveNameLowInertia:      160.0/1000
        case kMFScrollAnimationCurveNameHighInertia, kMFScrollAnimationCurveNameHighInertiaPlusTrackpadSim: 160.0/1000
        case kMFScrollAnimationCurveNameTouchDriver, kMFScrollAnimationCurveNameTouchDriverLinear:          160.0/1000
        case kMFScrollAnimationCurveNamePreciseScroll, kMFScrollAnimationCurveNameQuickScroll:              160.0/1000
        default: { assert(false); return -1.0 }()
        }
    }
    /// ^ Notes:
    ///     If more than `_consecutiveScrollTickIntervalMax` seconds passes between two scrollwheel ticks, then they aren't deemed consecutive.
    ///        other["consecutiveScrollTickIntervalMax"] as! Double;
    ///     msPerStep/1000 <- Good idea but we don't want this to depend on msPerStep
    
    @objc lazy var consecutiveScrollTickIntervalMin: TimeInterval = 1/1000
    /// ^ Notes:
    ///     - This variable is used to cap the observed scrollTickInterval to a reasonable value. We also use it for Math.scale() ing the timeBetweenTicks into a value between 0 and 1. But I'm not sure this is better than just using 0 instead of `consecutiveScrollTickIntervalMin`.
    ///     - 15ms seemst to be smallest scrollTickInterval that you can naturally produce. But when performance drops, the scrollTickIntervals that we see can be much smaller sometimes.
    ///     - Update: This is not true for my Roccat Mouse connected via USB. The tick times go down to around 5ms on that mouse. I can reproduce the 15ms minimum using my Logitech M720 connected via Bluetooth. I guess it depends on the mouse hardware or on the transport (bluetooth vs USB).
    ///         - Action: We're lowering the `consecutiveScrollTickIntervalMax` from 15 -> 1. Primarily to be able to implement the `baseMsPerStepCurve` algorithm better, but also because our assumption that the lowest possible value is 15 is not true for all mice.
    ///         **HACK**: We need to keep the  the `consecutiveScrollTickInterval_AccelerationEnd` at 15ms for now, because lowering that to 5ms would change the behaviour or the acceleration algorithm and make scrolling slower, and we don't have time to adjust the acceleration curves right now.

    @objc lazy var consecutiveScrollSwipeMaxInterval: TimeInterval = {
        /// If more than `_consecutiveScrollSwipeIntervalMax` seconds passes between two scrollwheel swipes, then they aren't deemed consecutive.
        
        let result: Double = SharedUtilitySwift.eval {
            
            switch animationCurve {
            case kMFScrollAnimationCurveNameNone:            325.0
            case kMFScrollAnimationCurveNameVeryLowInertia:  375.0 /// Haven't considered this. (Only matters for fastScroll I think, which we've turned off for VeryLow) [Jun 2025]
            case kMFScrollAnimationCurveNameLowInertia:      375.0
            case kMFScrollAnimationCurveNameHighInertia, kMFScrollAnimationCurveNameHighInertiaPlusTrackpadSim: 600.0
            case kMFScrollAnimationCurveNameTouchDriver, kMFScrollAnimationCurveNameTouchDriverLinear:          375.0
            case kMFScrollAnimationCurveNamePreciseScroll, kMFScrollAnimationCurveNameQuickScroll:              0.1234 /// Will be overriden
            default: -1.0
            }
        }
        assert(result != -1.0)
        return result/1000.0
    }()
    
    @objc lazy var consecutiveScrollSwipeMinTickSpeed: Double = {
        /// The ticks per second need to be at least `consecutiveScrollSwipeMinTickSpeed` to register a series of scrollswipes as consecutive
        
        let result: Double = SharedUtilitySwift.eval {
            switch animationCurve {
            case kMFScrollAnimationCurveNameNone:           16.0
            case kMFScrollAnimationCurveNameVeryLowInertia: 16.0 /// Haven't considered this [Jun 2025]
            case kMFScrollAnimationCurveNameLowInertia:     16.0
            case kMFScrollAnimationCurveNameHighInertia, kMFScrollAnimationCurveNameHighInertiaPlusTrackpadSim: 12.0
            case kMFScrollAnimationCurveNameTouchDriver, kMFScrollAnimationCurveNameTouchDriverLinear:          16.0
            case kMFScrollAnimationCurveNamePreciseScroll, kMFScrollAnimationCurveNameQuickScroll:              0.1234 /// Will be overriden
            default: -1.0
            }
        }
        assert(result != -1.0)
        return result
    }()
    
    @objc lazy var consecutiveScrollTickInterval_AccelerationEnd: TimeInterval = 15/1000 //consecutiveScrollTickIntervalMin
    /// ^ Notes:
    ///     - Used to define accelerationCurve. If the time interval between two ticks becomes less than `consecutiveScrollTickInterval_AccelerationEnd` seconds, then the accelerationCurve becomes managed by linear extension of the bezier instead of the bezier directly.
    ///     - This should ideally be equal to `consecutiveScrollTickIntervalMin`. For an explanation why it's different at the moment, see the notes on consecutiveScrollTickIntervalMin
    
    /// Note: We are just using RollingAverge for smoothing, not ExponentialSmoothing, so this is currently unused.
    @objc lazy var ticksPerSecond_DoubleExponentialSmoothing_InputValueWeight: Double = 0.5
    @objc lazy var ticksPerSecond_DoubleExponentialSmoothing_TrendWeight: Double = 0.2
    @objc lazy var ticksPerSecond_ExponentialSmoothing_InputValueWeight: Double = 0.5
    /// ^  Notes:
    ///     1.0 -> Turns off smoothing. I like this the best
    ///     0.6 -> On larger swipes this counteracts acceleration and it's unsatisfying. Not sure if placebo
    ///     0.8 ->  Nice, light smoothing. Makes  scrolling slightly less direct. Not sure if placebo.
    ///     0.5 -> (Edit) I prefer smoother feel now in everything. 0.5 Makes short scroll swipes less accelerated which I like
    
    // MARK: Fast scroll
    
    
    @objc lazy var fastScrollCurve: ScrollSpeedupCurve? = {
        
        /// NOTES:
        /// - We're using swipeThreshold to configure how far the user must've scrolled before fastScroll starts kicking in.
        /// - It would probably be better to have an explicit mechanism that counts how many pixels the user has scrolled already and then lets fastScroll kick in after a threshold is reached. That would also scale with the scrollSpeed setting. These current `fastScrollSpeedup` values are chosen so you don't accidentally trigger it at the lowest scrollSpeed, but they could be higher at higher scrollspeeds.
        /// - Fastscroll starts kicking in on the `swipeThreshold + 1` th scrollSwipe
        /// - Edit: Why do we need speedup for kMFScrollAnimationCurveNameTouchDriver and kMFScrollAnimationCurveNameTouchDriverLinear?
        ///
        /// On how we chose parameters:
        /// - The `swipeThreshold` was chosen proportional to the max stepSize of the lowest scrollspeed setting of the respective animationCurve.
        /// - The `exponentialSpeedup` of the unanimated ScrollSpeedCurve is lower and the `initialSpeedup` is higher because without animation you quickly reach a speed where you can't tell how far or in which direction you scrolled. We want to have a few swipes in that window of speed where you can tell that it's speeding up but it's not yet so fast that you can't tell which direction you scrolled and how fast.
        
        
        switch animationCurve {
            
        case kMFScrollAnimationCurveNameNone:           return ScrollSpeedupCurve(swipeThreshold: 6, initialSpeedup: 1.4,  exponentialSpeedup: 3.0)
        case kMFScrollAnimationCurveNameVeryLowInertia: return ScrollSpeedupCurve(swipeThreshold: 1, initialSpeedup: 1,    exponentialSpeedup: 7.5) /// Turn off fastScroll, since we want _maximum control_ and linear feeling for this setting.
        case kMFScrollAnimationCurveNameLowInertia:     return ScrollSpeedupCurve(swipeThreshold: 3, initialSpeedup: 1.33, exponentialSpeedup: 7.5)
            
        case kMFScrollAnimationCurveNameHighInertia, kMFScrollAnimationCurveNameHighInertiaPlusTrackpadSim: return ScrollSpeedupCurve(swipeThreshold: 2, initialSpeedup: 1.33, exponentialSpeedup: 7.5)
        case kMFScrollAnimationCurveNameTouchDriver, kMFScrollAnimationCurveNameTouchDriverLinear:          return ScrollSpeedupCurve(swipeThreshold: 3, initialSpeedup: 1.33, exponentialSpeedup: 7.5)
        case kMFScrollAnimationCurveNamePreciseScroll, kMFScrollAnimationCurveNameQuickScroll:              return nil as ScrollSpeedupCurve? /// Will be overriden
        
        default:
            assert(false)
            return nil as ScrollSpeedupCurve?
        }
    }()
    
    // MARK: Animation curve
    
    /// User setting
    
    @objc lazy var u_smoothness: MFScrollSmoothness = {
        switch c("smooth") as! String {
        case "off":     return kMFScrollSmoothnessOff
        case "low":     return kMFScrollSmoothnessLow
        case "regular": return kMFScrollSmoothnessRegular
        case "high":    return kMFScrollSmoothnessHigh
        default: fatalError()
        }
    }()
    private lazy var u_trackpadSimulation: Bool = {
        return c("trackpadSimulation") as! Bool
    }()
    
    private lazy var _animationCurveName = {
        
        /// Maybe we should move the trackpad sim settings out of the MFScrollAnimationCurveName, (because that's weird?)
        
        switch u_smoothness {
        case kMFScrollSmoothnessOff:        return kMFScrollAnimationCurveNameNone
        case kMFScrollSmoothnessLow:        return kMFScrollAnimationCurveNameVeryLowInertia
        case kMFScrollSmoothnessRegular:    return kMFScrollAnimationCurveNameLowInertia
        case kMFScrollSmoothnessHigh:       return u_trackpadSimulation ? kMFScrollAnimationCurveNameHighInertiaPlusTrackpadSim : kMFScrollAnimationCurveNameHighInertia
        default: fatalError()
        }
    }()
    
    @objc var animationCurve: MFScrollAnimationCurveName {
        
        set {
            _animationCurveName = newValue
            self.animationCurveParams = animationCurveParamsMap(name: animationCurve)
        } get {
            return _animationCurveName
        }
    }
    
    @objc private(set) lazy var animationCurveParams: MFScrollAnimationCurveParameters? = { animationCurveParamsMap(name: animationCurve) }() /// Updates automatically to match `self.animationCurveName
    
    // MARK: Acceleration
    
    /// User settings
    
    @objc lazy var u_speed: MFScrollSpeed = {
        switch c("speed") as! String {
        case "system":  return kMFScrollSpeedSystem /// Ignore MMF acceleration algorithm and use values provided by macOS
        case "low":     return kMFScrollSpeedLow
        case "medium":  return kMFScrollSpeedMedium
        case "high":    return kMFScrollSpeedHigh
        default: fatalError()
        }
    }()
    @objc lazy var u_precise: Bool = { c("precise") as! Bool }()
    
    /// Stored property
    ///     This is used by Scroll.m to determine how to accelerate
    
    @objc lazy var accelerationCurve: Curve? = nil /// Initial value is unused I think. Will always be overriden before it's used anywhere. Edit: No, this stays nil, if we useAppleAcceleration
    
    // MARK: Keyboard modifiers
    
    /// Event flag masks
    @objc lazy var horizontalModifiers = CGEventFlags(rawValue: c("modifiers.horizontal") as! UInt64)
    @objc lazy var zoomModifiers = CGEventFlags(rawValue: c("modifiers.zoom") as! UInt64)
    
    @objc func copy(with zone: NSZone? = nil) -> Any {
        
        /// TODO: Think about whether this could have todo with the weird scrolling crashes for MMF 3.0.2. Any race conditions or sth?
        
        return SharedUtilitySwift.shallowCopy(ofObject: self)
    }
    
}

// MARK: - Helper stuff

/// Storage class for animationCurve params

@objc class MFScrollAnimationCurveParameters: NSObject {
    
    /// Notes:
    /// - I don't really think it make sense for sendGestureScrolls and sendMomentumScrolls to be part of the animation curve, but it works so whatever
    
    /// baseCurve params
    @objc let baseCurve: Bezier?
    @objc let speedSmoothing: Double        /// `speedSmoothing` replaces `baseCurve`. If it is active, the baseCurve will be dynamically calculated, such that the animation speed doesn't jump after a scrollwheel-tick occurs.
    @objc let baseMsPerStep: Int            /// Duration of the baseCurve || When using dragCurve, that will make the actual msPerStep longer
    @objc let baseMsPerStepCurve: Curve?    /// If this is not nil, the duration of the baseCurve will be controlled by this curve. The point at which this curve is sampled will increase from 0 to 1 as the time between physical scrollWheel ticks decreases.
    /// dragCurve params
    @objc let useDragCurve: Bool /// If false, use only baseCurve, and ignore dragCurve
    @objc let dragExponent: Double
    @objc let dragCoefficient: Double
    @objc let stopSpeed: Int
    /// Other params
    @objc let sendGestureScrolls: Bool  /// If false, send simple continuous scroll events (like MMF 2) instead of using GestureScrollSimulator
    @objc let sendMomentumScrolls: Bool /// Only works if sendGestureScrolls and useDragCurve is true. If true, make Scroll.m send momentumScroll events (what the Apple Trackpad sends after lifting your fingers off) when scrolling is controlled by the dragCurve (and in some other cases, see TouchAnimator). Only use this when the dragCurve closely mimicks the Apple Trackpads otherwise apps like Xcode will behave differently from other apps during momentum scrolling.
    
    /// Init
    init(baseCurve: Bezier?, speedSmoothing: Double, baseMsPerStep: Int, baseMsPerStepCurve: Curve?, dragExponent: Double, dragCoefficient: Double, stopSpeed: Int, sendGestureScrolls: Bool, sendMomentumScrolls: Bool) {
        
        /// Init for using hybridCurve      [(baseCurve + dragCurve) or (speedSmoothingCurve + dragCurve)]
        
        if sendMomentumScrolls { assert(sendGestureScrolls) }
        assert((baseCurve == nil)     ^ (speedSmoothing == -1))
        assert((baseMsPerStep == -1)  ^ (baseMsPerStepCurve == nil))
        
        self.baseCurve = baseCurve
        self.speedSmoothing = speedSmoothing
        self.baseMsPerStepCurve = baseMsPerStepCurve
        self.baseMsPerStep = baseMsPerStep
        
        self.useDragCurve = true
        self.dragExponent = dragExponent
        self.dragCoefficient = dragCoefficient
        self.stopSpeed = stopSpeed
        
        self.sendGestureScrolls = sendGestureScrolls
        self.sendMomentumScrolls = sendMomentumScrolls
    }
    init(justBaseCurve baseCurve: Bezier?, speedSmoothing: Double, baseMsPerStep: Int, baseMsPerStepCurve: Curve?, sendGestureScrolls: Bool) {
        
        assert((baseCurve == nil)     ^ (speedSmoothing == -1))
        assert((baseMsPerStep == -1)  ^ (baseMsPerStepCurve == nil))
        
        /// Init for using just baseCurve
        
        self.baseCurve = baseCurve
        self.speedSmoothing = speedSmoothing
        self.baseMsPerStepCurve = baseMsPerStepCurve
        self.baseMsPerStep = baseMsPerStep
        
        self.useDragCurve = false
        self.dragExponent = -1
        self.dragCoefficient = -1
        self.stopSpeed = -1
        
        self.sendGestureScrolls = sendGestureScrolls
        self.sendMomentumScrolls = false
    }
}

fileprivate func animationCurveParamsMap(name: MFScrollAnimationCurveName) -> MFScrollAnimationCurveParameters? {
    
    /// Map from animationCurveName -> animationCurveParams
    /// For the origin behind these curves see ScrollConfigTesting.md
    /// @note I just checked the formulas on Desmos, and I don't get how this can work with 0.7 as the exponent? (But it does??) If the value is `< 1.0` that gives a completely different curve that speeds up over time, instead of slowing down.
    
    switch name {
        
    /// --- User selected ---
        
    case kMFScrollAnimationCurveNameNone:
        
        return nil
        
    case kMFScrollAnimationCurveNameNoInertia:
        
        fatalError()
        
        let baseCurve =
        Bezier(controlPoints: [_P(0, 0), _P(0, 0), _P(0.66, 1), _P(1, 1)], defaultEpsilon: 0.001)
//            Bezier(controlPoints: [_P(0, 0), _P(0.31, 0.44), _P(0.66, 1), _P(1, 1)], defaultEpsilon: 0.001)
//            ScrollConfig.linearCurve
//            Bezier(controlPoints: [_P(0, 0), _P(0.23, 0.89), _P(0.52, 1), _P(1, 1)], defaultEpsilon: 0.001)
        return MFScrollAnimationCurveParameters(justBaseCurve: baseCurve, speedSmoothing: -1, baseMsPerStep: 250, baseMsPerStepCurve: nil, sendGestureScrolls: false)
    
    case kMFScrollAnimationCurveNameVeryLowInertia:
        /// Added [Jun 4 2025] to support a new "Smoothness: Low" option in the MMF interface.
        ///     (kMFScrollAnimationCurveNameLowInertia) currently supports the "Smoothness: Regular" option.)
        ///     (Maybe we should move this code into kMFScrollAnimationCurveNameNoInertia, buit I don't wanna delete any code right now)
        ///     Context: [May 2025]
        ///         Recently I felt like Option 3 (in kMFScrollAnimationCurveNameLowInertia) is way too unresponsive. I'm doing a lot of 'scanning' of large text recently – quickly scrolling back and forth, and Option 3 feels wayy to 'gooey', so I'm experimenting with a new curve.
        ///         I also felt like one design goal of the previous curves – making text visible during scroling – didn't matter to me much right now? I feel like super fast movement is fine – you can still follow it, as long as your eyes have some context clues through animation. Plus once you're used to the scrolling, your brain anticipates where things end up.
        ///     Inspiration:
        ///         [May 17 2025] CLion's smooth scrolling looked quite good in this YouTube video: https://youtu.be/nnt5_qWX0eg. The CLion animation curve can be customized. The default might be https://cubic-bezier.com/#.17,.67,.83,.67 (those values are mentioned in the docs) ... But in the CLion Bezier editor it looks like the default settings are (0.25, 0.5, 0.5, 0.5). It's also possible that the default settings are different under Linux/Windows – the docs mention differences. The YouTuber might also have been using non-default settings. (Docs: https://www.jetbrains.com/help/clion/settings-appearance.html#ui?)
        ///         [Jun 4 2025] Linux Firefox scrolling looked good in this Tscoding video: https://www.youtube.com/watch?v=G9piTswOQZY
        ///             I have a theory that Firefox and Chrome might have different smoothing on macOS (compared to LInux/Window).
        ///                 - This would sort of make sense since the default acceleration curves are totally different on macOS, which makes the smoothing feel different, too.
        ///                 - Smooth scrolling not available in Chrome on macOS (?) https://www.reddit.com/r/chrome/comments/153tfev/smooth_scrolling_not_available_on_mac/
        ///         [Jun 4 2025] SmoothFox.js for Firefox – I've seen this recommended. I should try it.
        ///         [Jun 4 2025] I saw some Logitech Mouse have nice scrolling recently and some MMF user asked for less smoothing on GitHub recently after coming from Logitech's Driver. I remember I used to hate Logi Options scrolling but maybe they improved it or my tasted have changed?
        
        #if false /// [Jul 2025] Would like to use `MF_TEST 0` here, but not sure how in Swift
        if _1 {
            var baseCurve:          Bezier?          = nil
            var baseSpeedupCurve:   Curve?           = nil
            
            if (_1) {
                /// Option 3
                ///     Context: [Jun 2] I like the 6.2 values and have been using them over the last weeks.
                ///         Only issues I noticed:
                ///             - Things can feel a tad big abrupt at some points  ––– but I feel like it's a necessary tradeoff for having very short, responsive, predictable animations. (?)
                ///             - Animations feel like they 'match' finger speed when moving finger slowly or quickly, but animations 'lag behind' finger movement a bit at medium speeds ––– 6.3 is trying to address that
                ///         Plan 1:
                ///             Add curvature to make animation higher at medium finger speed.
                ///             Conclusion: [Jun 2 2025]|(Possibly premature) Not sure curve great here. Higher-medium speeds feel good now, but lower-medium speeds still feel too slow. We usually used the BezierCappedAccelerationCurveto scale animation *distance* relative to user input speed. (I found it nice for pointer acceleration and scroll acceleration) But here, we're scaling animation *duration* instead. It feels more sound to scale animation duration linearly relative to input speed. I feel like adjusting the lo-end and hi-end of when we start and stop to apply the linear acceleration might be more appropriate. Alternatively we could use a Cubic Bezier instead of BezierCappedAccelerationCurve to boost animation speed at lower-medium finger-speeds
                ///         Plan 2:
                ///             Adjust the `consecutiveScrollTickIntervalMax` up. [Jun 4 2025]
                ///     Sidequest: (Maybe move these notes somewhere else) [Jun 2 2025]
                ///         Looked into what 'defaultEpsilon' values to use for the BezierCappedAccelerationCurve here. I tested 0.001 and 300. Surprisingly, both were effectively the same in both speed and accuracy. Even though 300 basically turns off the entire algorithm after it makes its 'first guess', while 0.001 demands very high accuracy, and should cause the algorithm to run several newton/bisection iterations.
                ///             It seems that  that the "initialGuess" of the newton algorithm is so good that doesn't ever need any further iterations even with epsilon 0.001. I'm not sure why this is. I think it might have to do with the range of x-values being small (0,1) while the range of y values is large (250,100) (The algorithm we're talking about tries to find a 't' for a given x value, and apparently the x and t values are (almost?) exactly equal here, which makes the 'initialGuess' of the algorithm highly accurate.)
                ///             I've used CurveVisualizer.swift to test this (I built it for this purposes)
                ///             Conclusion: You can use 0.001 as the 'defaultEpsilon'. it has no overhead and might make things more robust than a higher value if we change things later.
                ///     Experiences: [Jun 7 2025]
                ///         Over the last few days I have been using the old 'LowInertia' in the mornings since the new 'VeryLowInertia' felt too harsh and unsmooth, and then during the day after I really woke up and got into work I wanted the 'VeryLowInertia' since it gives more control.
                ///         Over the last 1-2 days I've noticed that
                ///             for slow and medium finger-speed the 'LowInertia' is actually nice. I especially like that you can make small-but-fast 2-tick scroll-swipes, without having the animation speed become too fast. This is nice since that's is the lowest-effort way to scroll small distances IMO – Inputting single ticks at a time requires more finger-tension (Pretty sure I wrote about this finger-tension-thing before but can't remember where.)
                ///             However, for fast-and-large swipes, the 'LowInertia' scrolling is very annoying since it feels like the page is sliding around when you want it to stop. A an examples is when you quickly go up and down 3/4 of a page to cross-examine the content. Having to wait for the animation there is very annoying.
                ///                 Idea: We might want to control the scroll-tick-smoothing in ScrollAnalyzer.m based on the ScrollConfig. That would let us influence how those small-but-fast two-tick-swipes are handled. With higher inertia, those swipes are somewhat smoothed out naturally, but with very-low inertia it can feel more erratic and I think more scroll-tick-smoothing could help.
                ///             Thought: This makes me think that instead of introducing a new 'VeryLowInertia' setting it might be better to first try to tweak the 'LowInertia' animations. I think the  'LowInertia' animations would be pretty usable for me if they weren't so 'slidey' for the fast-and-large swipes.
                var curv: Double = 0.85
                baseCurve = Bezier(controlPoints: [_P(0, 0), _P(0, 0), _P(curv, 1), _P(1, 1)], defaultEpsilon: 0.001)
                var tup: (Double, Double) = ((1000.0/60)*15, (1000.0/60)*6)
                var animationSpeedupCurvature: Double = -1
                if (_0) { animationSpeedupCurvature = 1.0 } /// Makes for unpredictable, jerky speedup when trying to scroll slowly but then accidentally producing 2 wheel ticks that are a bit closer together [Jun 3 2025]
                if (_1) { animationSpeedupCurvature = 0.00 } /// Turn off curvature, now that we've increased consecutiveScrollTickIntervalMax from 160 -> 200 ms
                
                baseSpeedupCurve = BezierCappedAccelerationCurve(xMin: 0, xMax: 1, yMin: tup.0, yMax: tup.1, curvature: animationSpeedupCurvature,
                                                                 reduceToCubic: false, defaultEpsilon: 0.001)
                
                
                /// DEBUG
                if #available(macOS 15.0, *) {
                    CurveVisualizer.setCurveTrace1(baseSpeedupCurve!.traceAsPoints(startX: 0.0, endX: 1.0, nOfSamples: 1000))
                }
            }
            
            if (_0)  {
                /// Option 2
                ///     Context: [May 10] A few days later, I wanted a bit more fluid, less unnatural/abrupt animations, so we added an ease-out instead of a linear curve
                ///     Update [May 12] I liked 0.95, but a few days later, the abrupt stops feel offputting while scrolling slowly and continuously to scan for text in small IDA Output window. I scrolled at a speed right at the edge of where the animation becomes continuous - Solution idea: Maybe we could have a stronger ease-out while scrolling slowly but keep the mostly linear curve for faster movements? I generally prefer slower animation today and am Happy with Option 3. - Perhaps cause I'm more tired/relaxed than the last days. Update: Actually using 0.85 seems to solve the problem without making other stuff feel weird I think ... Update2: Nah 0.85 makes the speed feel 'inconsistent'. Update3: I played around with Firefox today and it also feels 'inconsistent'. The mostly linear animation curve is good because it keeps the animations speed steady and directly tied to the speed of the user's finger movement. But perhaps a hybrid solution where we have a smooth ease-out for slow finger movements but become close-to-linear at medium and fast finger movements would solve this.
                ///         Update: [May 20] Setting the lo speed lower (20 frames is nice but I haven't tested much) Makes the problem with slow, continuous scrolling go away! ... But it makes medium-speed scrolls feel sluggish. This suggests that we could make this feel really great by keeping a linear animation curve but refining the speedup curve. Update 2: Actually with 15 frames it feels even better. Maybe we can keep the linear speedup curve like that.
                var curv: Double = .nan
                if (_0) { curv = 0.9 }
                if (_0) { curv = 0.95 } /** I like 0.95. It's very subtle, might be placebo.  With 0.75 if felt the speed was too 'fluctuating' and inconsistent. But with 1.0 I felt the animation stop looks abrupt. */
                if (_0) { curv = devToggles_C }
                if (_1) { curv = 0.85 } /**[May 20 2025] I accidentally got used to this over the last few days and I like it now. Stops feel less abrupt than 0.95  */
                print("ScrollConfig: DevToggles: curvature: \(curv)")
                baseCurve = Bezier(controlPoints: [_P(0, 0), _P(0, 0), _P(curv, 1), _P(1, 1)], defaultEpsilon: 0.001)
                var tup: (Double, Double) = (-1, -1)
                if (_0) { tup = ((1000.0/60)*12, (1000.0/60)*6) }
                if (_0) { tup = ((1000.0/60)*Double(devToggles_Lo), (1000.0/60)*Double(devToggles_Hi)) }
                if (_1) { tup = ((1000.0/60)*15, (1000.0/60)*6) }
                baseSpeedupCurve = Curve(rawCurve: { x in Math.scale(x, (0,1), tup) })
            }
            
            if (_0)  {
                /// Option 1
                baseCurve = ScrollConfig.linearCurve
                var tup: (Double, Double) = (-1, -1)
                if (_0) { tup = (160, 90)                          }
                if (_0) { tup = ((1000.0/60)*3,  (1000.0/60)*3)    }
                if (_0) { tup = ((1000.0/60)*12, (1000.0/60)*3)    }
                if (_0) { tup = ((1000.0/60)*12, (1000.0/60)*5)    }
                if (_1) { tup = ((1000.0/60)*12, (1000.0/60)*6)    }
                if (_0) { tup = ((1000.0/60)*12, (1000.0/60)*12)   }
                baseSpeedupCurve = Curve(rawCurve: { x in Math.scale(x, (0,1), tup) })
            }
            if (_0) {
                /// Option 0
                baseCurve = ScrollConfig.linearCurve
                let curvature = 4.0
                let baseMsPerStepCurveMax = 200.0
                let baseMsPerStepCurveMin = 90.0
                if curvature == 0.0 {
                    let e = { x in Math.scale(x, (0, 1), (baseMsPerStepCurveMax, baseMsPerStepCurveMin)) }
                    baseSpeedupCurve = Curve(rawCurve: e)
                } else {
                    
                    let e1 = { x in exp(x * curvature) - 1 }
                    let e2 = { x in e1(x) / e1(1) }
                    let e3 = CurveTools.transformCurve(e2) { y in Math.scale(y, (0, 1), (baseMsPerStepCurveMax, baseMsPerStepCurveMin)) }
                    baseSpeedupCurve = Curve(rawCurve: e3)
                }
            }
            return MFScrollAnimationCurveParameters(justBaseCurve: baseCurve!, speedSmoothing:-1, baseMsPerStep:-1, baseMsPerStepCurve: baseSpeedupCurve!, sendGestureScrolls: false)
        }
        
        #endif
        
        fatalError()
        
    case kMFScrollAnimationCurveNameLowInertia:

        /// Option 5: Higher baseMsPerStep
        if _0 {
            return MFScrollAnimationCurveParameters(baseCurve: nil, speedSmoothing: -1, baseMsPerStep: -1, baseMsPerStepCurve: Curve(rawCurve: { x in Math.scale(x, (0,1), (90, 160)) }), dragExponent: 1.0, dragCoefficient: 23, stopSpeed: 30, sendGestureScrolls: false, sendMomentumScrolls: false)
        }
        
        /// Option 4: Combination of previous 2 (below I think)
        if _0 {
            return MFScrollAnimationCurveParameters(baseCurve: nil, speedSmoothing: -1, baseMsPerStep: -1, baseMsPerStepCurve: Curve(rawCurve: { x in Math.scale(x, (0,1), (90, 140)) }), dragExponent: 1.05, dragCoefficient: 15, stopSpeed: 30, sendGestureScrolls: false, sendMomentumScrolls: false)
        }
        
        /// Option 3: This tries to 'feel' like MMF 2.
        ///     (Update: [May 2025] This shipped with the latest version of MMF (3.0.3 and 3.0.4 Beta 1) – IIRC we tried Option 4 and Option 5 but went back to Option 3 before shipping)
        ///     - For medium and large scroll swipes it feels similarly responsive snappy to MMF 2 due to the 90 baseMsPerStepMin. (In MMF 2 the baseMsPerStep was 90)
        ///     - For single ticks on default settings, the speed feels similar to MMF 2 due to the 140 baseMsPerStep and due to the step size being larger than MMF 2.
        ///     - In MMF 2, exponent is 1.0 and coeff is 2.3. Here the coeff is 23. Not sure if that's the same but feels similar.
        ///     - Update:
        ///         - We've now replaced baseMsPerStepMin with baseMsPerStepCurve and changed all the parameters around. (See below for more info on that) Not sure this feels like MMF 2 anymore. But it feels really good.
        
        /// Define curve for the baseMsPerStepCurve speedup
        ///
        /// Notes:
        ///
        /// - The reason why we introduced a curve, is that when we tried linear interpolation for the baseMsPerStepMin, we found that little 2-3 tick swipes were too fast, but larger/faster swipes were too slow. Initially, we tried to fix that by adding additional smoothing inside ScrollAnalyzer by initializing the `_tickTimeSmoother` with a value. However, this messed up the scroll distance acceleration, so we turned that back off. This curve is our second attempt at making the 2-3 tick swipes animate slower while making the larger or faster swipes animate faster. In contrast to the previous ScrollAnalyzer-based approach, this approach doesn't have a time component, where if you scroll at the same speed for a longer time it speeds up more. Not sure if this is a good or bad thing.
        /// - The curve we're using (at the time of writing) is basically just a shifted and scaled exponential function. I designed it using this desmos page: https://www.desmos.com/calculator/l8plcdlpmn. I first tried using a Bezier curve, but it didn't get curved enough. I thought about using a curve based on 1/x instead of e^x, but they looked very similar in desmos and e^x is simpler to deal with.
        /// 
        /// - Sidenotes:
        ///     - It's overall a little messy that we have these hybrid curves whose duration we can't directly control, but then we create complex curves for the duration of the baseCurve of the HybridCurve to gain back some control of the overall duration. It's sort of messy and confusing. All in the name of having the deceleration feel 'physical'. (That's the purpose of the HybridCurves) I mean this is still the best feeling scrolling algorithm I know of so I guess it works, but I really wonder if it wouldn't have been possible to design something more elegant. Maybe we could've done a sort of spring animator and then dynamically chose the starting speed such that the animation covers a certain distance in a certain time. That's the thing we really want to have explicit control over: The distance. But we also want to have control over the feel and over the duration. However, if you want to have a 'physical' feel it's complicated to also control the distance and duration. And actually in case of the high smoothness curves I think I'm pretty happy not having to explicitly control the duration. The duration just falls out of the physics in a nice way. Update: Stared at Desmos for a while and came to the conclusion that our current idea is the best and with spring animations we'd have more or less the same problem. (Can't easily control both duration and distance while keeping consistent physics)
        ///
        /// - **Ideaaa**: It seems that what I'm currently trying to to when designing these curves is 1. Make the animations speed for fastest scrollwheel movements as fast as possible without becoming disorientating to look at 2. Adjust the animation speed for lower scrollwheel speed to feel 'the same' or 'consistent' with the fastest scrollwheel speed - because the 'consistent' feel makes it easier to control. (I'm not sure what consistent means, it's just a feeling) --- Maybe we could do this stuff explicitly somehow. Like explicitly cap the animation speed. Update: Just measured the overall animation duration (including drag) after finding a `baseMsPerStepCurve` that feels 'consistent' to us and I found the duration is relatively close to being constant! It's currently between 260 and 300 ms - This gives me the idea that what we were subconsciously doing with the `baseMsPerStepCurve` was to try and make the overall animation duration constant. Maybe that's what made it feel 'consistent' to us. Update: Also did some testing for curves that feel 'inconsistent' to us and the variation in overall animation duration wasn't thatt much more as I thought. I think what I observed was like 240 to 340 ms. Maybe this means that the 'consistent' feel has other aspects aside from low variation in overall animation duration.
        ///     - **Implementation Ideas**: These thoughts give me two concrete ideas for potentially improving our scrolling algorithms:
        ///         1. Idea: Make a way to create a `HybridCurve` with a fixed duration along with a fixed distance. The HybridCurve should then automatically figure out what the baseCurve should be / how fast the baseMsPerStep should be. Having explicit control over the duration might allow us to create better, more 'consistent' feeling and more controllable curves. I don't think we'd want to use this for High Smoothness scrolling, since there we want a large variability in animation duration, and the way the current algorithms behave feels very natural and predictable to me already. But for the regular smoothness setting (Which uses this code right here), this could potentially be nice. But on the other hand, maybe the bit of variability in animation duration is good? I'm not sure. Butt, if we implemented a system for explicitly controlling the animation duration, we could still vary the animation duration with the animation distance or with the scrollwheel speed. We'd simply have more control over it, which I think really couldn't hurt?
        ///             - Conclusion: This idea is interesting. I think it would be good to try at some point. But to really ship this, we'd have to be careful and dedicate a lot of time to testing. I think for now, the current approach of defining a `baseSpeedupCurve` to get some control over the scroll animation duration seems like it's good enough. Maybe it's even inherently better than this idea. I'm not sure. That's why I should test it at some point. But not now.
        ///         2. Idea: Make a way to explicitly specify a maxAnimationSpeed(Target) which is the highest speed where your eyes can follow scrolling content on the screen (This probably depends on screen refresh rate and other stuff, but we can assume our own screen as a heuristic I think). The duration of the animation curve could then be dynamically determined to be such that, when the user does a scroll swipe at max speed, the resulting animation has a max speed of maxAnimationSpeed(Target). Note that this means we'd choose different animation durations for different "Scrolling Speed" user settings that the user might choose (These user settings really determine sensitivity to be precise) . As a simpler-to-implement stand-in for such a mechanism, we could simply scale the baseMsPerStep with the accelerationCurve. E.g. we could desing the baseMsPerStep around the mediumSpeed accelerationCurve, then sample both the mediumSpeed accelerationCurve and the currentSpeed accelerationCurve at let's say 80% of the maximum scrollwheel speed that the user can input, and then get the scaling factor `s` between the 80% values of those two curves. Then we could multiply the baseMsPerStep with `s`. That way we only have to find a suitable baseMsPerStep for the mediumSpeed accelerationCurve and the rest would be adjusted such that the user can produce an animation speed of *up to* maxAnimationSpeed(Target) no matter what "Scrolling Speed" setting they choose.
        ///             - Sidenote: I'm putting "Target" in `maxAnimationSpeed(Target)` because it's not supposed to be a hard cap for the animation speed it's more like a heuristic saying: if the user inputs the fastest scroll they can, then the movement on the screen should be about this fast.
        ///             - Conclusion: I think this is an idea worth exploring, especially when we introduce more options for the user to choose a "Scrolling Speed".  However, this would need a lot of testing to make sure we're getting it right, and I should only do it if I have time to dedicate to this. So not now.
        ///
        /// - Idea:
        ///     - What's interesting is that the animationDuration is influenced by both the baseMsPerStep speed up mechanism as well as by the Drag physics inside the HybridCurve. But at the time of writing, the baseMsPerStep speed up is applied purely based on timeBetweenscrollwheelTicks, while the animationDuration modification from the drag physics is applied based on how many pixels are left to scroll. (Which is also a result of the timeBetweenscrollwheelTicks but with an additional time component I think). This is quite messy to think about. Based on these thoughts, I would think that the animationDuration is very unpredictable. But in practise it doesn't feel that way. 
        ///
        /// - Finding parameters:
        ///     - I liked 4.0, 140.0, 60.0 for a while - It feels super direct and immediate. And still smoother than Chrome. However I found that it's hard to follow scrolling movements with your eyes at least on my displays.
        ///     - I liked 4.0, 180.0, 110.0
        ///         - Notes:
        ///             - 110 feels like MMF 2 on fast swipes, it's slow enough that  you can still see the content well. 110 is the lower end for clear visibiliy during scrolling I think. Setting the max to 180 makes the speed feel 'consistent' for slow and fast swipes which helps controllability.
        ///             - I have played around with small changes to this a bit. E.g. using 170 instead of 180. I had the impression that 4.0, 180.0, 110.0 is close to a local optimum.
        ///                 - I also tried 200.0, 120.0 - I thought 120 feelt less grating and confusing to eyes, but that made it feel a bit too unresponsive
        ///             - The max animation speed of this feels similar to the pre 3.0.1 algorithm. We did this whole baseMsPerStepCurve (and the predecessor baseMsPerStepMin) stuff because we thought that things felt too unresponsive and now it feels like we've arrived at something similar to the starting point. But, I really think this is at the upper end of animation speed that is nice to use, and the responsiveness is noticably better than pre 3.0.1. Controllability is also better I think.
        ///             - You'd think that the whole baseCurveSpeedup and curvature stuff would make the scrolling less predictable/controllable. Not totally sure, but I feel like for this curve if we turn the speedup off it becomes harder to control/predict. Update: I looked at the overall animation duration (including DragCurve and BaseCurve) and there's less variation in that with this speedup mechanism. Maybe decreased variability makes things more predictable / easy to control. See **Ideaaa** above for more on this.
        
        if _1 {
            let curvature = 4.0                  /* 5.0   4.0 */ /// Should be >= 0.0
            let baseMsPerStepCurveMax = 180.0    /* 140.0 150.0  180.0  200.0 */
            let baseMsPerStepCurveMin = 110.0    /* 60.0  90.0    110.0  120.0 */ /// MMF 2 feels more like 110 not 90 or 60
            
            let baseSpeedupCurve: Curve
            
            if curvature == 0.0 {
                let e = { x in Math.scale(x, (0, 1), (baseMsPerStepCurveMax, baseMsPerStepCurveMin)) }
                baseSpeedupCurve = Curve(rawCurve: e)
            } else {
                
                let e1 = { x in exp(x * curvature) - 1 }
                let e2 = { x in e1(x) / e1(1) }
                let e3 = CurveTools.transformCurve(e2) { y in Math.scale(y, (0, 1), (baseMsPerStepCurveMax, baseMsPerStepCurveMin)) }
                baseSpeedupCurve = Curve(rawCurve: e3)
            }
            
            return MFScrollAnimationCurveParameters(baseCurve: ScrollConfig.linearCurve, speedSmoothing: -1, baseMsPerStep: -1, baseMsPerStepCurve: baseSpeedupCurve, dragExponent: 1.0, dragCoefficient: 23, stopSpeed: 30, sendGestureScrolls: false, sendMomentumScrolls: false)
        }
        
        /// Option 2: Pre 3.0.1 curve (I think)
        /// - I don't like this curve atm. It's still too slow. I'm currently 'tuned into' liking the MMF 2 algorithm and it's much quicker than this.
        /// - MMF 2 has baseMsPerStep 90, this makes medium and large scroll swipes feel much more responsive. But single scroll ticks feel too fast. Maybe we could implement an algorithm where the baseMSPerStep is variable and it shrinks on consecutive scroll swipes or as the scroll speed gets higher, or sth like that. Ideas:
        ///    - Add a cap to the base scroll speed.
        ///    - Make the msPerStep a mix between baseMSPerStep and the actual msPerStep of the scrollwheel. Maybe as soon as `scrollWheelMsPerStep < baseMSPerStep` we use `scrollWheelMsPerStep` or do an interpolation between the 2
        ///         Update: Implemented this with the `baseMsPerStepMin`param (Update: Now changed to `baseMsPerStepCurve`)
        
        if _0 {
            return MFScrollAnimationCurveParameters(baseCurve: ScrollConfig.linearCurve, speedSmoothing: -1, baseMsPerStep: 140, baseMsPerStepCurve: nil, dragExponent: 1.05, dragCoefficient: 15, stopSpeed: 30, sendGestureScrolls: false, sendMomentumScrolls: false)
        }
        
        /// Option 1: I think I like this curve better. Still super responsive and much smoother feeling. But I'm not sure I'm 'tuned into' what the lowInertia should feel like. Bc when I designed it I really liked the snappy, 'immediate' feel, but now I don't like it anymore and wanna make everything much smoother. So I'm not sure I should change it now. Also we should adjust the speed curves if we adjust the feel of this so much.
        if _0 {
            return MFScrollAnimationCurveParameters(baseCurve: nil,                      speedSmoothing: 0.15, baseMsPerStep: 175, baseMsPerStepCurve: nil, dragExponent: 0.9, dragCoefficient: 25, stopSpeed: 30, sendGestureScrolls: false, sendMomentumScrolls: false)
        }
        
        fatalError()
        
    case kMFScrollAnimationCurveNameMediumInertia:
        
        fatalError()
        
        return MFScrollAnimationCurveParameters(baseCurve: ScrollConfig.linearCurve, speedSmoothing: -1, baseMsPerStep: 200, baseMsPerStepCurve: nil, dragExponent: 1.05, dragCoefficient: 15, stopSpeed: 30, sendGestureScrolls: false, sendMomentumScrolls: false)
        
        return MFScrollAnimationCurveParameters(baseCurve: ScrollConfig.linearCurve, speedSmoothing: -1, baseMsPerStep: 190, baseMsPerStepCurve: nil, dragExponent: 1.0, dragCoefficient: 17, stopSpeed: 50, sendGestureScrolls: false, sendMomentumScrolls: false)
        
    case kMFScrollAnimationCurveNameHighInertia:
        
        /// - This uses the snappiest dragCurve that can be used to send momentumScrolls.
        ///    If you make it snappier then it will cut off the built-in momentumScroll in apps like Xcode
        /// - We tried setting baseMsPerStep 205 -> 240, which lets medium scroll speed look slightly smoother since you can't tell the ticks apart, but it takes longer until text becomes readable again so I think I like it less. Edit: In MOS's scrollAnalyzer, 240 is the lowest baseMSPerStep where the animationSpeed is constant for low medium scrollwheel speed. Edit: But 215 - 220 is also almost perfect for medium speeds, and in AB testing it's barely different-feeling than 205. In AB testing, I liked 220 slightly more than 240, but the difference is small.
        /// - Speed smoothing prevents the slightly unsmooth look at medium and low scroll speeds, but it can also make scrolling feel less responsive and direct. From my testing, at 0.4 it becomes sluggish feeling. Edit: From more testing, I think 0.15 makes especially single ticks a bit smoother, and doesn't noticably impact responsiveness. I did some performance testing, since with speedSmoothing, the BezierCurves can't be optimized into simple straight lines anymore. Scrolling to the bpm of a song the CPU usage went from 1.2% -> 1.6% percent. That's a 30% increase, but it's still very fast. Currently we're using an epsilon of 0.01 for the BezierCurves. If we lower that we might get even better performance, but it already gives slightly different curves in MOS scroll analyzer with this epsilon compared to more accurate epsilon, so I don't think we should make it lower.
        /// Update: Turned speedSmoothing from 0.15 -> 0.00 rn for more responsive/predictable feel.
        ///     - This is an experiment. I thought it made it easier to use the 'scrollStop' feature where you scroll one tick in the opposite direction to stop the scroll animation. 'Throwing' the page and then stopping it felt more predictable with speedSmoothing off.
        ///     - I also heard some reports from people that scrolling in 3.0.1 is worse / performs worse than before. (I'm fairly sure we introduced speedSmoothing in 3.0.1) So maybe the performance issues could also have to do with speedSmoothing? (I don't think it should be performance intensive enough to make a difference though, but who knows?)
        ///     - However I also found that scrolling felt refreshingly responsive after turning speed smoothing off. Might be placebo, but I think I like it better.
        
        return MFScrollAnimationCurveParameters(baseCurve: nil/*ScrollConfig.linearCurve*/, speedSmoothing: /*0.15*/0.0, baseMsPerStep: 220, baseMsPerStepCurve: nil, dragExponent: 0.7, dragCoefficient: 40, stopSpeed: /*50*/30, sendGestureScrolls: false, sendMomentumScrolls: false)
        
    case kMFScrollAnimationCurveNameHighInertiaPlusTrackpadSim:
        /// Same as highInertia curve but with full trackpad simulation. The trackpad sim stuff doesn't really belong here I think.
        return MFScrollAnimationCurveParameters(baseCurve: nil/*ScrollConfig.linearCurve*/, speedSmoothing: /*0.15*/0.0, baseMsPerStep: 220, baseMsPerStepCurve: nil, dragExponent: 0.7, dragCoefficient: 40, stopSpeed: /*50*/30, sendGestureScrolls: true, sendMomentumScrolls: true)
        
    /// --- Dynamically applied ---
        
    case kMFScrollAnimationCurveNameTouchDriver:
        /// v Note: At the time of writing, this curve is equivalent to a BezierCappedAccelerationCurve with curvature 1.
        let baseCurve = Bezier(controlPoints: [_P(0, 0), _P(0, 0), _P(0.5, 1), _P(1, 1)], defaultEpsilon: 0.001)
        return MFScrollAnimationCurveParameters(justBaseCurve: baseCurve,                   speedSmoothing:-1, baseMsPerStep: /*225*/250/*275*/, baseMsPerStepCurve:nil, sendGestureScrolls: false)
        
    case kMFScrollAnimationCurveNameTouchDriverLinear:
        return MFScrollAnimationCurveParameters(justBaseCurve: ScrollConfig.linearCurve,    speedSmoothing:-1, baseMsPerStep: 180/*200*/, baseMsPerStepCurve:nil, sendGestureScrolls: false)
    case kMFScrollAnimationCurveNameQuickScroll:
        
        /// - Almost the same as `highInertia` just more inertial. Actually same feel as trackpad-like parameters used in `GestureScrollSimulator` for autoMomentumScroll.
        /// - Should we use trackpad sim (sendMomentumScrolls and sendGestureScrolls) here?
        return MFScrollAnimationCurveParameters(baseCurve: ScrollConfig.linearCurve, speedSmoothing: -1, baseMsPerStep: /*220*/300, baseMsPerStepCurve: nil, dragExponent: 0.7, dragCoefficient: 30, stopSpeed: 1, sendGestureScrolls: true, sendMomentumScrolls: true)
        
    case kMFScrollAnimationCurveNamePreciseScroll:
        
        /// Similar to `lowInertia`
//        return MFScrollAnimationCurveParameters(baseCurve: ScrollConfig.linearCurve, baseMsPerStep: 140, dragExponent: 1.0, dragCoefficient: 20, stopSpeed: 50, sendGestureScrolls: false, sendMomentumScrolls: false)
        return MFScrollAnimationCurveParameters(baseCurve: ScrollConfig.linearCurve, speedSmoothing: -1, baseMsPerStep: 140, baseMsPerStepCurve: nil, dragExponent: 1.05, dragCoefficient: 15, stopSpeed: 50, sendGestureScrolls: false, sendMomentumScrolls: false)
        
    /// --- Testing ---
        
    case kMFScrollAnimationCurveNameTest:
        
        return MFScrollAnimationCurveParameters(justBaseCurve: ScrollConfig.linearCurve, speedSmoothing:-1, baseMsPerStep: 350, baseMsPerStepCurve: nil, sendGestureScrolls: false)
        
    /// --- Other ---
    
    default:
        fatalError()
    }
}

/// Define function that maps userSettings -> accelerationCurve
fileprivate func getAccelerationCurve(forSpeed speedArg: MFScrollSpeed, precise: Bool, smoothness: MFScrollSmoothness, animationCurve: MFScrollAnimationCurveName, inputAxis: MFAxis, display: CGDirectDisplayID, scaleToDisplay: Bool, modifiers: MFScrollModificationResult, useQuickModSpeed: Bool, usePreciseModSpeed: Bool, consecutiveScrollTickIntervalMax: Double, consecutiveScrollTickInterval_AccelerationEnd: Double) -> Curve {
    
    /// Notes:
    /// - The inputs to the curve can sometimes be ridiculously high despite smoothing, because our time measurements of when ticks occur are very imprecise
    ///     - Edit: Not sure this is still true since we switched to using CGEvent timestamps instead of CACurrentMediaTime() time at some point. I think we also made some changes so the timeBetweenTicks is always reported to be at least `consecutiveScrollTickIntervalMin` or `consecutiveScrollTickInterval_AccelerationEnd`, which would mean we don't have to worry about this here.
    /// - `_n` stands for 'normalized', so the value is between 0.0 and 1.0
    /// - Before we used the `BezierCappedAccelerationCurve` we used `capHump` / `accelerationHump` curvature system. The last commit with that system (commented out) is 1304067385a0e77ed1c095e39b8fa2ae37b9bde4
    
    /**
     
     General thoughts / explanation on how our BezierCappedAccelerationCurve class works in this context:
     
      Define a curve describing the relationship between the inputSpeed (in scrollwheel ticks per second) (on the x-axis) and the sensitivity (In pixels per tick) (on the y-axis).
      We'll call this function y(x).
      y(x) is composed of 3 other curves. The core of y(x) is a BezierCurve *b(x)*, which is defined on the interval (xMin, xMax).
      y(xMin) is called yMin and y(xMax) is called yMax
      There are two other components to y(x):
      - For `x < xMin`, we set y(x) to yMin
      - We do this so that the acceleration is turned off for tickSpeeds below xMin. Acceleration should only affect scrollTicks that feel 'consecutive' and not ones that feel like singular events unrelated to other scrollTicks. `self.consecutiveScrollTickIntervalMax` is (supposed to be) the maximum time between ticks where they feel consecutive. So we're using it to define xMin.
      - For `xMax < x`, we lineraly extrapolate b(x), such that the extrapolated line has the slope b'(xMax) and passes through (xMax, yMax)
      - We do this so the curve is defined and has reasonable values even when the user scrolls really fast
      - (Our uses of tick and step are interchangable here)
     
      HyperParameters:
      - `curvature` raises sensitivity for medium scrollSpeeds making scrolling feel more comfortable and accurate. This is especially nice for very low minSens.
     */

    var screenSize: size_t = -1
    if useQuickModSpeed || scaleToDisplay {
        
        if inputAxis == kMFAxisHorizontal
            || modifiers.effectMod == kMFScrollEffectModificationHorizontalScroll {
            screenSize = CGDisplayPixelsWide(display);
        } else if inputAxis == kMFAxisVertical {
            screenSize = CGDisplayPixelsHigh(display);
        } else {
            fatalError()
        }
    }
    
    let speed_n: Double = SharedUtilitySwift.eval {
        switch speedArg {
        case kMFScrollSpeedLow: 0.0
        case kMFScrollSpeedMedium: 0.5
        case kMFScrollSpeedHigh: 1.0
        case kMFScrollSpeedSystem: -1.0
        default: -1.0
        }
    }
    
    let minSend_n = speed_n
    let maxSens_n = speed_n
    let curvature_n = speed_n
    
    var minSens: Double
    var maxSens: Double
    var curvature: Double
    
    if useQuickModSpeed {
        
        let windowSize = Double(screenSize)*0.85 /// When we use unanimated line-scrolling this doesn't hold up, but I think we always animate when using quickMod
        
        minSens = windowSize * 0.5 //100
        maxSens = windowSize * 1.5 //500
        curvature = 0.0
        
    } else if usePreciseModSpeed {

        minSens = 1
        maxSens = 20
        curvature = 2.0
        
    } else if animationCurve == kMFScrollAnimationCurveNameTouchDriver
                || animationCurve == kMFScrollAnimationCurveNameTouchDriverLinear {
        
        /// At the time of writing, this is an exact copy of the `regular` smoothness acceleration curves. Not totally sure if that makes sense. One reason I can come up with for adjusting this to the user's scroll speed settings is that the user might use the scroll speed settings to compensate for differences in their physical scrollwheel and therefore the speed should apply to everything they do with the scrollwheel
        
        minSens =   CombinedLinearCurve(yValues: [45.0, 60.0, 90.0]).evaluate(atX: minSend_n)
        maxSens =   CombinedLinearCurve(yValues: [90.0, 120.0, 180.0]).evaluate(atX: maxSens_n)
        if !precise {
            curvature = CombinedLinearCurve(yValues: [0.25, 0.0, 0.0]).evaluate(atX: curvature_n)
        } else {
            curvature = CombinedLinearCurve(yValues: [0.75, 0.75, 0.25]).evaluate(atX: curvature_n)
        }

        
    } else if smoothness == kMFScrollSmoothnessOff { /// It might be better to use the animationCurve instead of smoothness in these if-statements
        
        minSens =   CombinedLinearCurve(yValues: [20.0, 30.0, 40.0]).evaluate(atX: minSend_n)
        maxSens =   CombinedLinearCurve(yValues: [40.0, 60.0, 80.0]).evaluate(atX: maxSens_n)
        if !precise {
            /// For the other smoothnesses we apply more curvature if precise == true, but here it felt best to have them the same. Don't know why.
            curvature = CombinedLinearCurve(yValues: [4.25, 3.0, 2.25]).evaluate(atX: curvature_n)
        } else {
            curvature = CombinedLinearCurve(yValues: [4.25, 3.0, 2.25]).evaluate(atX: curvature_n)
        }

    } else if smoothness == kMFScrollSmoothnessLow { /// kMFScrollAnimationCurveNameVeryLowInertia

        minSens =   CombinedLinearCurve(yValues: [30.0, 60.0, 120.0]).evaluate(atX: minSend_n)
        maxSens =   CombinedLinearCurve(yValues: [90.0, 120.0, 180.0]).evaluate(atX: maxSens_n)
        if !precise {
            curvature = CombinedLinearCurve(yValues: [0.25, 0.0, 0.0]).evaluate(atX: curvature_n)
        } else {
            curvature = CombinedLinearCurve(yValues: [0.75, 0.75, 0.25]).evaluate(atX: curvature_n)
        }

    } else if smoothness == kMFScrollSmoothnessRegular {

        minSens =   CombinedLinearCurve(yValues: [/*20.0, 40.0,*/ 30.0, 60.0, 120.0]).evaluate(atX: minSend_n)
        maxSens =   CombinedLinearCurve(yValues: [/*60.0, 90.0,*/ 90.0, 120.0, 180.0]).evaluate(atX: maxSens_n)
        if !precise {
            curvature = CombinedLinearCurve(yValues: [0.25, 0.0, 0.0]).evaluate(atX: curvature_n)
        } else {
            curvature = CombinedLinearCurve(yValues: [0.75, 0.75, 0.25]).evaluate(atX: curvature_n)
        }
        
    } else if smoothness == kMFScrollSmoothnessHigh {
        
        minSens =   CombinedLinearCurve(yValues: [/*30.0,*/ 60.0, 90.0, 150.0]).evaluate(atX: minSend_n)
        maxSens =   CombinedLinearCurve(yValues: [/*90.0,*/ 120.0, 180.0, 240.0]).evaluate(atX: maxSens_n)
        if !precise {
            curvature = 0.0
        } else {
            curvature = CombinedLinearCurve(yValues: [1.5, 1.25, 0.75]).evaluate(atX: curvature_n)
        }
        
    } else {
        fatalError()
    }
    
    
    /// Precise
    
    if precise {
        minSens = 10
    }
    
    /// Screen height
    
    if scaleToDisplay {
        
        /// Get screenHeight factor
        let baseScreenSize = inputAxis == kMFAxisHorizontal ? 1920.0 : 1080.0
        let screenSizeFactor = Double(screenSize) / baseScreenSize
        
        let screenSizeWeight = 0.1
        
        /// Apply screenSizeFactor
        
        maxSens = (maxSens * (1-screenSizeWeight)) + ((maxSens * screenSizeWeight) * screenSizeFactor)
    }
    
    /// vv Old screenSizeFactor formula
    ///     Replaced this with the new formula without in-depth testing, so this might be better
    
//    if screenHeightFactor >= 1 {
//        screenHeightSummand = 20*(screenHeightFactor - 1)
//    } else {
//        screenHeightSummand = -20*((1/screenHeightFactor) - 1)
//    }
//    maxSens += screenHeightSummand
    
    /// Get Curve
    /// - Not sure if 0.08 defaultEpsilon is accurate enough when we create the curve.
    
    let xMin: Double = 1 / Double(consecutiveScrollTickIntervalMax)
    let yMin: Double = minSens
    
    let xMax: Double = 1 / consecutiveScrollTickInterval_AccelerationEnd
    let yMax: Double = maxSens
    
    let curve = BezierCappedAccelerationCurve(xMin: xMin, xMax: xMax, yMin: yMin, yMax: yMax, curvature: curvature, reduceToCubic: false, defaultEpsilon: 0.05)
    
    /// Debug
    
//    DDLogDebug("Recommended epsilon for Acceleration Curve: \(curve.getMinEpsilon(forResolution: 1000, startEpsilon: 0.02/*0.08*/, epsilonEpsilon: 0.001))")
    
    /// Return
    return curve
    
}
