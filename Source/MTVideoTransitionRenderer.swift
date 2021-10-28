//
//  MTVideoTransitionRenderer.swift
//  MTTransitions
//
//  Created by xushuifeng on 2020/3/23.
//

import Foundation
import MetalPetal
import VideoToolbox

public class MTVideoTransitionRenderer: NSObject {

    let transition: MTTransition
    
    public init(transition: MTTransition) {
        self.transition = transition
        super.init()
    }

    public func renderPixelBuffer(_ destinationPixelBuffer: CVPixelBuffer,
                                  usingForegroundSourceBuffer foregroundPixelBuffer: CVPixelBuffer,
                                  withTransform foregroundTransform: ((MTIImage, Float) -> (MTIImage))?,
                                  forTweenFactor tween: Float) {

        let foregroundImage = MTIImage(cvPixelBuffer: foregroundPixelBuffer, alphaType: .alphaIsOne)

        let transformedImage = foregroundTransform?(foregroundImage, tween) ?? foregroundImage

        try? MTTransition.context?.render(transformedImage, to: destinationPixelBuffer)
    }
    
    public func renderPixelBuffer(_ destinationPixelBuffer: CVPixelBuffer,
                                  usingForegroundSourceBuffer foregroundPixelBuffer: CVPixelBuffer?,
                                  withTransform foregroundTransform: ((MTIImage, Float) -> (MTIImage))?,
                                  andBackgroundSourceBuffer backgroundPixelBuffer: CVPixelBuffer?,
                                  withTransform backgroundTransform: ((MTIImage, Float) -> (MTIImage))?,
                                  andPostTransform postTransform: ((MTIImage) -> (MTIImage))?,
                                  forTweenFactor tween: Float) {

        // Cleanup unused images upon complete
        defer {
            transition.inputImage = nil
            transition.destImage = nil
        }
        if let fpb = foregroundPixelBuffer {
            let foregroundImage = MTIImage(cvPixelBuffer: fpb, alphaType: .alphaIsOne)
            transition.inputImage = foregroundTransform?(foregroundImage, tween) ?? foregroundImage
        } else {
            // background is an image
            transition.inputImage = nil
        }

        if let bpb = backgroundPixelBuffer {
            let backgroundImage = MTIImage(cvPixelBuffer: bpb, alphaType: .alphaIsOne)
            transition.destImage = backgroundTransform?(backgroundImage, tween) ?? backgroundImage
        } else {
            transition.destImage = nil
        }

        if transition.inputImage == nil, let size = transition.destImage?.size {
            transition.inputImage = MTIImage(color: .black, sRGB: true, size: size)
        } else if transition.destImage == nil, let size = transition.inputImage?.size {
            transition.destImage = MTIImage(color: .black, sRGB: true, size: size)
        }

        transition.progress = tween

        if var output = transition.outputImage?.oriented(.downMirrored) {
            output = postTransform?(output) ?? output
            try? MTTransition.context?.render(output, to: destinationPixelBuffer)
        }
    }
}

extension UIImage {
    public convenience init?(pixelBuffer: CVPixelBuffer) {
        var cgImage: CGImage?
        VTCreateCGImageFromCVPixelBuffer(pixelBuffer, options: nil, imageOut: &cgImage)
        guard let image = cgImage else {
            return nil
        }
        self.init(cgImage: image)
    }
}
