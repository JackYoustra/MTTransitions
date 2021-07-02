//
//  MTLumaTransition.swift
//  MTTransitions
//
//  Created by alexiscn on 2019/1/28.
//

// TODO
public class MTLumaTransition: MTTransition {

    public var luma: String = "spiral-1.png"
    
    public override var fragmentName: String {
        return "LumaFragment"
    }
    
    override var samplers: [String : String] {
        return [
            "luma": luma
        ]
    }
}
