//
//  MTVideoCompositor.swift
//  MTTransitions
//
//  Created by xushuifeng on 2020/3/23.
//

import AVFoundation
import MetalPetal

public class MTVideoCompositor: NSObject, AVVideoCompositing {
    
    /// Returns the pixel buffer attributes required by the video compositor for new buffers created for processing.
    public var requiredPixelBufferAttributesForRenderContext: [String : Any] =
    [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
    
    /// The pixel buffer attributes of pixel buffers that will be vended by the adaptor’s CVPixelBufferPool.
    public var sourcePixelBufferAttributes: [String : Any]? =
    [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
    
    /// Set if all pending requests have been cancelled.
    var shouldCancelAllRequests = false
    
    /// Dispatch Queue used to issue custom compositor rendering work requests.
    private let renderingQueue = DispatchQueue(label: "me.shuifeng.mttransitions.renderingqueue")
    
    /// Dispatch Queue used to synchronize notifications that the composition will switch to a different render context.
    private let renderContextQueue = DispatchQueue(label: "me.shuifeng.mttransitions.rendercontextqueue")
    
    /// The current render context within which the custom compositor will render new output pixels buffers.
    private var renderContext: AVVideoCompositionRenderContext?
    
    /// Maintain the state of render context changes.
    private var internalRenderContextDidChange = false
    /// Actual state of render context changes.
    private var renderContextDidChange: Bool {
        get {
            return renderContextQueue.sync { internalRenderContextDidChange }
        }
        set (newRenderContextDidChange) {
            renderContextQueue.sync { internalRenderContextDidChange = newRenderContextDidChange }
        }
    }
    
    private lazy var renderer = MTVideoTransitionRenderer(transition: transition)
    
    /// Effect apply to video transition
    var transition: MTTransition { return MTTransition.Effect.angular.transition }
    
    override init() {
        super.init()
    }
    
    public func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext) {
        renderContextQueue.sync { renderContext = newRenderContext }
        renderContextDidChange = true
    }
    
    enum PixelBufferRequestError: Error {
        case newRenderedPixelBufferForRequestFailure
    }
    
    public func startRequest(_ asyncVideoCompositionRequest: AVAsynchronousVideoCompositionRequest) {
        autoreleasepool {
            renderingQueue.async {
                autoreleasepool {
                    // Check if all pending requests have been cancelled.
                    if self.shouldCancelAllRequests {
                        asyncVideoCompositionRequest.finishCancelledRequest()
                    } else {
                        guard let currentInstruction = asyncVideoCompositionRequest.videoCompositionInstruction as? MTVideoCompositionInstruction else {
                            return
                        }
                        // Change effect if current instruction is non-passthrough
                        // and has a different effect
                        if currentInstruction.isTransition,
                           self.renderer.transition != currentInstruction.transition {
                            self.renderer = MTVideoTransitionRenderer(transition: currentInstruction.transition)
                        }

                        guard let resultPixels = self.newRenderedPixelBufferForRequest(asyncVideoCompositionRequest) else {
                            asyncVideoCompositionRequest.finish(with: PixelBufferRequestError.newRenderedPixelBufferForRequestFailure)
                            return
                        }
                        // The resulting pixelbuffer from Metal renderer is passed along to the request.
                        asyncVideoCompositionRequest.finish(withComposedVideoFrame: resultPixels)
                    }
                }
            }
        }
    }
    
    public func cancelAllPendingVideoCompositionRequests() {
        /*
         Pending requests will call finishCancelledRequest, those already rendering will call
         finishWithComposedVideoFrame.
         */
        renderingQueue.sync { shouldCancelAllRequests = true }
        renderingQueue.async {
            // Start accepting requests again.
            self.shouldCancelAllRequests = false
        }
    }
    
    func factorForTimeInRange( _ time: CMTime, range: CMTimeRange) -> Float64 { /* 0.0 -> 1.0 */
        let elapsed = CMTimeSubtract(time, range.start)
        return CMTimeGetSeconds(elapsed) / CMTimeGetSeconds(range.duration)
    }
    
    func newRenderedPixelBufferForRequest(_ request: AVAsynchronousVideoCompositionRequest) -> CVPixelBuffer? {

        /*
         tweenFactor indicates how far within that timeRange are we rendering this frame. This is normalized to vary
         between 0.0 and 1.0. 0.0 indicates the time at first frame in that videoComposition timeRange. 1.0 indicates
         the time at last frame in that videoComposition timeRange.
         */
        let tweenFactor = factorForTimeInRange(request.compositionTime, range: request.videoCompositionInstruction.timeRange)

        guard let currentInstruction = request.videoCompositionInstruction as? MTVideoCompositionInstruction else {
            print("No current instruction")
            return nil
        }

        // Check if we should run a mitigation algorithm
        if let skipBuffer = currentInstruction.vendBufferForSkippedStep?(currentInstruction, request.compositionTime) {
            return skipBuffer
        }

        let foregroundSourceBufferMaybe = request.sourceFrame(byTrackID: currentInstruction.foregroundTrackID)

        let layers = currentInstruction.layeredForegroundTrackIDs.compactMap { trackID -> MultilayerCompositingFilter.Layer? in
            guard let source = request.sourceFrame(byTrackID: trackID) else { return nil }
            return MultilayerCompositingFilter.Layer(content: MTIImage(cvPixelBuffer: source, alphaType: .alphaIsOne))
        }
        if layers.count > 0 {
            let layerer = currentInstruction.foregroundLayerer
            currentInstruction.foregroundLayerer = {
                let input = layerer?($0, $1) ?? $0
                let filter = MultilayerCompositingFilter()
                filter.inputBackgroundImage = input
                filter.layers = layers
                return filter.outputImage ?? input
            }
        }

        // Check if it's a passthrough-plus-transform or a transition
        if !currentInstruction.isTransition {
            // passthrough

            let foregroundSourceBuffer, dstPixels: CVPixelBuffer
            if currentInstruction.ignoreInput {
                guard let destination = renderContext?.newPixelBuffer() else {
                    print("Pixel allocation failure (passthrough)")
                    return nil
                }
                dstPixels = destination
                foregroundSourceBuffer = dstPixels
            } else {
                // Destination pixel buffer into which we render the output.
                guard let foregroundBuffer = foregroundSourceBufferMaybe else {
                    print("No foreground pixel buffer (track \(currentInstruction.foregroundTrackID))")
                    return nil
                }
                foregroundSourceBuffer = foregroundBuffer

                guard let destination = renderContext?.newPixelBuffer() else {
                    print("Pixel allocation failure (passthrough)")
                    return nil
                }
                dstPixels = destination
            }

            if renderContextDidChange { renderContextDidChange = false }

            renderer.renderPixelBuffer(dstPixels,
                                       usingForegroundSourceBuffer:foregroundSourceBuffer,
                                       withTransform: currentInstruction.foregroundLayerer, forTweenFactor: Float(tweenFactor))
            currentInstruction.newBufferRendered?(dstPixels)
            return dstPixels
        } else {
            // blend
            // Source pixel buffers are used as inputs while rendering the transition.
            let backgroundSourceBuffer = request.sourceFrame(byTrackID: currentInstruction.backgroundTrackID)

            if foregroundSourceBufferMaybe == nil && backgroundSourceBuffer == nil {
                // Wouldn't end up rendering anything, cancel
                print("No foreground or background source buffer")
                return nil
            }

            // Destination pixel buffer into which we render the output.
            guard let dstPixels = renderContext?.newPixelBuffer() else {
                print("Pixel allocation failure (blend)")
                return nil
            }

            if renderContextDidChange { renderContextDidChange = false }

            renderer.renderPixelBuffer(dstPixels,
                                       usingForegroundSourceBuffer:foregroundSourceBufferMaybe,
                                       withTransform: currentInstruction.foregroundLayerer,
                                       andBackgroundSourceBuffer:backgroundSourceBuffer,
                                       withTransform: currentInstruction.backgroundLayerer,
                                       andPostTransform: currentInstruction.postTransitionTransform,
                                       forTweenFactor:Float(tweenFactor))
            currentInstruction.newBufferRendered?(dstPixels)
            return dstPixels
        }
    }
}




