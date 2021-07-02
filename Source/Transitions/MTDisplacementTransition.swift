//
//  MTDisplacementTransition.swift
//  MTTransitions
//
//  Created by alexiscn on 2019/1/28.
//

// TODO: displacementMap should be parameter
public class MTDisplacementTransition: MTTransition {
    
    public var strength: Float = 0.5

    public var displacementMap: String = "displacementMap.jpg"

    public override var fragmentName: String {
        return "DisplacementFragment"
    }

    override var parameters: [String: Any] {
        return [
            "strength": strength, 
        ]
    }
    
    override var samplers: [String : String] {
        return [
            "displacementMap": displacementMap,
        ]
    }
}
