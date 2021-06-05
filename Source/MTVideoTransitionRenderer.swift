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
 
    let effect: MTTransition.Effect
    
    private let transition: MTTransition
    
    public init(effect: MTTransition.Effect) {
        self.effect = effect
        self.transition = effect.transition
        super.init()
    }

    public func renderPixelBuffer(_ destinationPixelBuffer: CVPixelBuffer,
                                  usingForegroundSourceBuffer foregroundPixelBuffer: CVPixelBuffer,
                                  withTransform foregroundTransform: ((MTIImage) -> (MTIImage))?) {

        let foregroundImage = MTIImage(cvPixelBuffer: foregroundPixelBuffer, alphaType: .alphaIsOne)

        let transformedImage = foregroundTransform?(foregroundImage) ?? foregroundImage

        try? MTTransition.context?.render(transformedImage, to: destinationPixelBuffer)
    }
    
    public func renderPixelBuffer(_ destinationPixelBuffer: CVPixelBuffer,
                                  usingForegroundSourceBuffer foregroundPixelBuffer: CVPixelBuffer?,
                                  withTransform foregroundTransform: ((MTIImage) -> (MTIImage))?,
                                  andBackgroundSourceBuffer backgroundPixelBuffer: CVPixelBuffer?,
                                  withTransform backgroundTransform: ((MTIImage) -> (MTIImage))?,
                                  forTweenFactor tween: Float) {

        if let fpb = foregroundPixelBuffer {
            let foregroundImage = MTIImage(cvPixelBuffer: fpb, alphaType: .alphaIsOne)
            transition.inputImage = foregroundTransform?(foregroundImage) ?? foregroundImage
        } else {
            // background is an image
            transition.inputImage = nil
        }

        if let bpb = backgroundPixelBuffer {
            let backgroundImage = MTIImage(cvPixelBuffer: bpb, alphaType: .alphaIsOne)
            transition.destImage = backgroundTransform?(backgroundImage) ?? backgroundImage
        } else {
            transition.destImage = nil
        }

        if transition.inputImage == nil, let size = transition.destImage?.size {
            transition.inputImage = MTIImage(color: .black, sRGB: true, size: size)
        } else if transition.destImage == nil, let size = transition.inputImage?.size {
            transition.destImage = MTIImage(color: .black, sRGB: true, size: size)
        }

        transition.progress = tween

        if let output = transition.outputImage {
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
