//
//  MTTransition+Codable.swift
//  MTTransitions
//
//  Created by Jack Youstra on 6/23/21.
//

import MetalPetal

enum SupportedTypes : Codable, Equatable {
    case int(Int)
    case float(Double)
    case vector(MTIVector)
    case string(String)
    case list([SupportedTypes])
    case dictionary([String : SupportedTypes])

    init(from decoder: Decoder) throws {
        // Can be made prettier, but as a simple example:
        let container = try decoder.singleValueContainer()
        do {
            self = .int(try container.decode(Int.self))
        } catch {
            do {
                self = .float(try container.decode(Double.self))
            } catch {
                do {
                    self = .vector(try container.decode(VectorWrapper.self).vector())
                } catch {
                    do {
                        self = .string(try container.decode(String.self))
                    } catch {
                        do {
                            self = .list(try container.decode([SupportedTypes].self))
                        } catch {
                            self = .dictionary(try container.decode([String : SupportedTypes].self))
                        }
                    }
                }
            }
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
            case .int(let int): try container.encode(int)
            case .float(let float): try container.encode(float)
            case .string(let string): try container.encode(string)
            case .vector(let vector): try container.encode(VectorWrapper(from: vector))
            case .list(let list): try container.encode(list)
            case .dictionary(let dictionary): try container.encode(dictionary)
        }
    }

    static func ==(_ lhs: SupportedTypes, _ rhs: SupportedTypes) -> Bool {
        switch (lhs, rhs) {
            case (.int(let int1), .int(let int2)): return int1 == int2
            case (.float(let int1), .float(let int2)): return int1 == int2
            case (.vector(let v1), .vector(let v2)): return v1 == v2
            case (.string(let string1), .string(let string2)): return string1 == string2
            case (.list(let list1), .list(let list2)): return list1 == list2
            case (.dictionary(let dict1), .dictionary(let dict2)): return dict1 == dict2
            default: return false
        }
    }

    func erased() -> Any {
        switch self {
            case .int(let int): return int
            case .float(let int): return int
            case .string(let int): return int
            case .vector(let int): return int
            case .list(let list): return list.map { $0.erased() }
            case .dictionary(let dict): return dict.mapValues { $0.erased() }
        }
    }

    private struct VectorWrapper : Codable {
        /// Base64 strat
        let data: String
        let type: MTIVector.ScalarType.RawValue

        init(from vector: MTIVector) {
            data = Data(bytes: vector.bytes(), count: Int(vector.byteLength)).base64EncodedString()
            type = vector.scalarType.rawValue
        }

        func vector() -> MTIVector {
            Data(base64Encoded: data)!.withUnsafeBytes { bytes in
                switch MTIVector.ScalarType(rawValue: type)! {
                    case .char:
                        return MTIVector.create(bytes: bytes, creator: MTIVector.init(charValues:count:))
                    case .float:
                        return MTIVector.create(bytes: bytes, creator: MTIVector.init(floatValues:count:))
                    case .int:
                        return MTIVector.create(bytes: bytes, creator: MTIVector.init(intValues:count:))
                    case .uint:
                        return MTIVector.create(bytes: bytes, creator: MTIVector.init(uintValues:count:))
                    case .short:
                        return MTIVector.create(bytes: bytes, creator: MTIVector.init(shortValues:count:))
                    case .ushort:
                        return MTIVector.create(bytes: bytes, creator: MTIVector.init(ushortValues:count:))
                    case .uchar:
                        return MTIVector.create(bytes: bytes, creator: MTIVector.init(ucharValues:count:))
                    @unknown default: fatalError()
                }
            }
        }
    }
}

func containerize(value: Any) -> SupportedTypes {
    if let integer = value as? Int {
        return SupportedTypes.int(integer)
    } else if let float = value as? Float {
        return SupportedTypes.float(Double(float))
    } else if let float = value as? Double {
        return SupportedTypes.float(float)
    } else if let string = value as? String {
        return SupportedTypes.string(string)
    } else if let vector = value as? MTIVector {
        return SupportedTypes.vector(vector)
    } else if let array = value as? [Any] {
        return SupportedTypes.list(array.map(containerize(value:)))
    } else if let map = value as? [String : Any] {
        return SupportedTypes.dictionary(map.mapValues(containerize(value:)))
    }
    fatalError("Unsupported data type")
}

fileprivate extension MTIVector {
    static func create<T>(bytes: UnsafeRawBufferPointer, creator: (UnsafePointer<T>, UInt) -> MTIVector) -> MTIVector {
        let typed = bytes.bindMemory(to: T.self)
        return creator(typed.baseAddress!, UInt(typed.count))
    }
}

public class MTDecodedTransition : MTTransition, Decodable {
    var _fragmentName: String
    public override var fragmentName: String {
        _fragmentName
    }

    var _samplers: [String : String]
    override var samplers: [String : String] {
        _samplers
    }

    var _parameters: [String : Any]
    override var parameters: [String : Any] {
        _parameters
    }

    required public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        _fragmentName = try values.decode(String.self, forKey: .fragmentName)
        _samplers = try values.decode([String : String].self, forKey: .samplers)
        _parameters = try values.decode([String : SupportedTypes].self, forKey: .parameters).mapValues { $0.erased() }
    }
}
