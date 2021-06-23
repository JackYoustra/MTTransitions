//
//  MTWindTransition.swift
//  MTTransitions
//
//  Created by alexiscn on 2019/1/28.
//

public class MTWindTransition: MTTransition {
    
    public var size: Float = 0.2 

    public override var fragmentName: String {
        return "WindFragment"
    }

    override var parameters: [String: Any] {
        return [
            "size": size
        ]
    }
}
