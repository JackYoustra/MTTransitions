//
//  MTVideoCompositionInstruction.swift
//  MTTransitions
//
//  Created by xushuifeng on 2020/3/23.
//

import Foundation
import AVFoundation
import MetalPetal

public class MTVideoCompositionInstruction: NSObject, AVVideoCompositionInstructionProtocol {
    
    /// ID used to identify the foreground frame.
    public var foregroundTrackID: CMPersistentTrackID = kCMPersistentTrackID_Invalid

    /// ID used to identify whether other tracks should be layered on top of the foreground track
    public var layeredForegroundTrackIDs: [CMPersistentTrackID] = []
    
    /// ID used to identify the background frame.
    public var backgroundTrackID: CMPersistentTrackID = kCMPersistentTrackID_Invalid

    /// A transformation applied to the foreground of a given transition or, if no transition exists, the single track image
    public var foregroundLayerer: ((MTIImage, Float) -> (MTIImage))? = nil

    /// A transformation applied to the background of a given transition
    public var backgroundLayerer: ((MTIImage, Float) ->(MTIImage))? = nil

    /// A transformation applied after rendering a transition frame
    public var postTransitionTransform: ((MTIImage) -> (MTIImage))? = nil

    /// There's a bug on AVPlayerItem that has seeking occasionally yield the wrong time.
    /// This can be mitigated by returning a cached pixel buffer to use on dead frames during these times (usually the beginning of a transition track)
    public var vendBufferForSkippedStep: ((MTVideoCompositionInstruction, CMTime) -> (CVPixelBuffer?))? = nil

    /// Helper updater for the vendBufferForSkippedStep function
    public var newBufferRendered: ((CVPixelBuffer) -> ())? = nil

    /// Ignore the actual video frames in a foreground-only instruction
    public var ignoreInput: Bool = false

    /// Effect applied to video transition
    public var transition: MTTransition = MTTransition.Effect.angular.transition
    
    public var timeRange: CMTimeRange {
        get { return self.overrideTimeRange }
        set { self.overrideTimeRange = newValue }
    }
    
    public var enablePostProcessing: Bool {
        get { return self.overrideEnablePostProcessing }
        set { self.overrideEnablePostProcessing = newValue }
    }
    
    public var containsTweening: Bool {
        get { return self.overrideContainsTweening }
        set { self.overrideContainsTweening = newValue }
    }
    
    public var requiredSourceTrackIDs: [NSValue]? {
        get { return self.overrideRequiredSourceTrackIDs }
        set { self.overrideRequiredSourceTrackIDs = newValue }
    }
    
    public var passthroughTrackID: CMPersistentTrackID {
        get { return self.overridePassthroughTrackID }
        set { self.overridePassthroughTrackID = newValue }
    }

    public var isTransition: Bool {
        guard let IDs = requiredSourceTrackIDs else { return true }
        return IDs.count - layeredForegroundTrackIDs.count > 1
    }
    
    /// The timeRange during which instructions will be effective.
    private var overrideTimeRange: CMTimeRange = CMTimeRange()
    
    /// Indicates whether post-processing should be skipped for the duration of the instruction.
    private var overrideEnablePostProcessing = false
    
    /// Indicates whether to avoid some duplicate processing when rendering a frame from the same source and destinatin at different times.
    private var overrideContainsTweening = false
    
    /// The track IDs required to compose frames for the instruction.
    private var overrideRequiredSourceTrackIDs: [NSValue]?
    
    /// Track ID of the source frame when passthrough is in effect.
    private var overridePassthroughTrackID: CMPersistentTrackID = 0
    
    public init(thePassthroughTrackID: CMPersistentTrackID, forTimeRange theTimeRange: CMTimeRange) {
        super.init()
        passthroughTrackID = thePassthroughTrackID
        timeRange = theTimeRange

        requiredSourceTrackIDs = [NSValue]()
        containsTweening = false
        enablePostProcessing = false
    }

    /// Initialize the instruction with one (or two, in the case of a transition) tracks
    /// - Parameters:
    ///   - theSourceTrackIDs: The IDs of the source tracks
    ///   - theTimeRange: The time range for which the instruction should be active
    public init(theSourceTrackIDs: [NSValue], forTimeRange theTimeRange: CMTimeRange) {
        super.init()

        requiredSourceTrackIDs = theSourceTrackIDs
        timeRange = theTimeRange

        passthroughTrackID = kCMPersistentTrackID_Invalid
        containsTweening = true
        enablePostProcessing = false
    }
}
