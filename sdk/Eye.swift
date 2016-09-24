
import GLKit

enum EyeType
{
    case monocular
    case left
    case right
}

class Eye
{
    var eyeType: EyeType = EyeType.monocular
    var eyeView: GLKMatrix4 = GLKMatrix4Identity
    
    var viewport:Viewport = Viewport()
    var fov:FieldOfView = FieldOfView(left: 0, right: 0, bottom: 0, top: 0)
    
    var lastZNear:Float = 0
    var lastZFar: Float = 0
    
    var projectionChanged: Bool = true
    
    var perspective:GLKMatrix4 = GLKMatrix4Identity
    
    init(type:EyeType)
    {
        eyeType = type
    }
    
    func calculatePerspective(_ near:Float, _ far:Float) -> GLKMatrix4
    {
        if !projectionChanged && lastZNear == near && lastZFar == far
        {
            return perspective
        }

        perspective = fov.toPerspectiveMatrix(zNear: lastZNear, zFar: lastZFar)
        
        lastZNear = near
        lastZFar = far
        
        projectionChanged = false
        
        return perspective
    }
}
