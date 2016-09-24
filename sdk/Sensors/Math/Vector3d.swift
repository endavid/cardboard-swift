
import Foundation

class Vector3d
{
    var x:Double = 0.0
    var y:Double = 0.0
    var z:Double = 0.0
    
    init()
    {
        zero()
    }
    
    init(_ vector:Vector3d)
    {
        set(vector.x, vector.y, vector.z)
    }
    
    init(_ vx:Double, _ vy:Double, _ vz:Double)
    {
        set(vx, vy, vz)
    }
    
    func zero()
    {
        set(0.0, 0.0, 0.0)
    }
    
    func set(_ v:Vector3d)
    {
        set(v.x, v.y, v.z)
    }
    
    func set(_ x:Double, _ y:Double, _ z:Double)
    {
        self.x = x
        self.y = y
        self.z = z
    }
    
    func setComponent(_ i:Int, value:Double)
    {
        if i == 0
        {
            x = value
        }
        
        else if i == 1
        {
            y = value
        }
        
        else
        {
            z = value
        }
    }
    
    func normalize()
    {
        let d = length()
        
        if ( d != 0.0 )
        {
            scale(1.0/d)
        }
    }
    
    func length() -> Double
    {
        return sqrt(x * x + y * y + z * z)
    }
    
    func scale(_ s:Double)
    {
        x *= s
        y *= s
        z *= s
    }

    static func largestAbsComponent(_ v:Vector3d) -> Int
    {
        let xAbs = fabs(v.x)
        let yAbs = fabs(v.y)
        let zAbs = fabs(v.z)
        
        if xAbs > yAbs
        {
            if xAbs > zAbs
            {
                return 0
            }
            
            return 2
        }
        
        if yAbs > zAbs
        {
            return 1
        }
        
        return 2
    }
    
    static func cross(_ a:Vector3d, _ b:Vector3d, result:inout Vector3d)
    {
        result.set(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)
    }
    
    static func dot(_ a:Vector3d, _ b:Vector3d) -> Double
    {
        return (a.x * b.x) + (a.y * b.y) + (a.z * b.z)
    }
    
    static func ortho(_ v:Vector3d, result:inout Vector3d)
    {
        var k:Int = largestAbsComponent(v) - 1
        
        if k < 0
        {
            k = 2
        }
        
        result.zero()
        result.setComponent(k, value: 1.0)
        
        cross(v, result, result: &result)
        
        result.normalize()
    }
    
    static func sub(_ a:Vector3d, _ b:Vector3d, result:inout Vector3d)
    {
        result.set(a.x - b.x, a.y - b.y, a.z - b.z)
    }
}
