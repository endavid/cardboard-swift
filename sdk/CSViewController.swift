
import Foundation
import GLKit
import OpenGLES

protocol CSStereoRendererDelegate
{
    func setupRendererWithView(_ view:GLKView)
    func shutdownRendererWithView(_ view:GLKView)
    
    func rendererDidChangeSize(_ size:CGSize)
    
    func prepareNewFrameWithHeadViewMatrix(_ headViewMatrix:GLKMatrix4)
    func drawEyeWithEye(_ eye:EyeMatrix)
    func finishFrameWithViewportRect(_ viewport:CGRect)
}

class EyeMatrix
{
    var eye:Eye = Eye(type: EyeType.monocular)
    var eyeType:EyeType = EyeType.monocular
    
    init()
    {
        
    }
    
    init(eye:Eye)
    {
        self.eye = eye
        
        eyeType = eye.eyeType
    }
    
    func eyeViewMatrix() -> GLKMatrix4
    {
        return eye.eyeView
    }
    
    func perspectiveMatrixWithZNear(_ zNear:Float, zFar:Float) -> GLKMatrix4
    {
        return eye.calculatePerspective(zNear,zFar)
    }
}

class CSViewController : GLKViewController
{
    var rendererDelegate:CSStereoRendererDelegate?
    
    var distortionRenderer:DistortionRenderer = DistortionRenderer()
    
    var headTracker:HeadTracker = HeadTracker()
    var headTransform:HeadTransform = HeadTransform()
    
    var monocularEye:Eye = Eye(type: EyeType.monocular)
    var leftEye:Eye = Eye(type: EyeType.left)
    var rightEye:Eye = Eye(type: EyeType.right)
    
    var leftEyeMatrix: EyeMatrix = EyeMatrix()

    var rightEyeMatrix: EyeMatrix = EyeMatrix()
    
    var vrModeEnabled: Bool = true

    var distortionCorrectionEnabled: Bool = true
    
    var vignetteEnabled: Bool = false
    var chromaticAberrationCorrectionEnabled: Bool = false
    var restoreGLStateEnabled: Bool = false
    var neckModelEnabled: Bool = false
    
    var glContext:EAGLContext?
    
    var projectionChanged:Bool = true
        
    var headMountedDisplay:HeadMountedDisplay = HeadMountedDisplay(screen: UIScreen.main)
    
    var glLock:NSRecursiveLock = NSRecursiveLock()
    
    var distortionRendererReady:Bool = false
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?)
    {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        
        setup()
    }
 
    required init?(coder aDecoder: NSCoder)
    {
        super.init(coder: aDecoder)
        
        setup()
    }
    
    func setup()
    {
        UIApplication.shared.isIdleTimerDisabled = true
        
        headTracker.startTracking(UIApplication.shared.statusBarOrientation)
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.glContext = EAGLContext(api: .openGLES2)
        
        if self.glContext == nil
        {
            print("Failed to create ES context")
        }
        
        let view = self.view as! GLKView
        view.context = self.glContext!
        view.drawableDepthFormat = .format24
        
        rendererDelegate?.setupRendererWithView(view)
        
        GLCheckForError()
    }
    
    override func glkView(_ view: GLKView, drawIn rect: CGRect)
    {
        if self.isPaused || !headTracker.isReady()
        {
            return
        }
        
        if !distortionRendererReady && distortionCorrectionEnabled
        {
            return
        }
        
        GLCheckForError()
        
        let lockAcquired = glLock.try()
        
        if !lockAcquired
        {
            return
        }
        
        if distortionCorrectionEnabled
        {
            distortionRenderer.beforeDrawFrame()
            
            drawFrameWithHeadTransform(headTransform, leftEye, rightEye)
            
            view.bindDrawable()
            
            distortionRenderer.afterDrawFrame()
        }
        else
        {
            self.drawFrameWithHeadTransform(headTransform, leftEye, rightEye)
        }
        
        self.finishFrameWithViewPort(monocularEye.viewport)
        
        GLCheckForError()
        
        glLock.unlock()
    }
    
    func update()
    {
        if self.isPaused || !headTracker.isReady()
        {
            return
        }
        
        self.calculateFrameParametersWithHeadTransform(headTransform, leftEye, rightEye, monocularEye)
    }
  
    func drawFrameWithHeadTransform(_ headTransform:HeadTransform,
                                    _ leftEye:Eye, _ rightEye:Eye)
    {        
        rendererDelegate!.prepareNewFrameWithHeadViewMatrix(headTransform.headView)
        
        GLCheckForError()
        
        glEnable(GLenum(GL_SCISSOR_TEST))
        
        leftEye.viewport.setGLViewport()
        leftEye.viewport.setGLScissor()
        
        leftEyeMatrix.eye = leftEye
        self.rendererDelegate!.drawEyeWithEye(leftEyeMatrix)
        
        rightEye.viewport.setGLViewport()
        rightEye.viewport.setGLScissor()
        
        rightEyeMatrix.eye = rightEye
        
        self.rendererDelegate!.drawEyeWithEye(rightEyeMatrix)
    }
        
    func calculateFrameParametersWithHeadTransform(_ headTransform:HeadTransform,
                                                   _ leftEye:Eye, _ rightEye:Eye,
                                                   _ monocularEye:Eye)
    {
        let deviceParams = headMountedDisplay.cardboardParams
        let halfInterLensDistance = deviceParams.interLensDistance * 0.5
        
        self.headTransform.headView = headTracker.getLastHeadView()
        
        let leftEyeTranslate = GLKMatrix4MakeTranslation(halfInterLensDistance, 0, 0)
        let rightEyeTranslate = GLKMatrix4MakeTranslation(-halfInterLensDistance, 0, 0)
        
        self.leftEye.eyeView = GLKMatrix4Multiply( leftEyeTranslate, headTransform.headView)
        self.rightEye.eyeView = GLKMatrix4Multiply( rightEyeTranslate, headTransform.headView)
        
        if projectionChanged
        {
            let screenParams = headMountedDisplay.screenParams
            
            monocularEye.viewport.setViewport(0, 0, screenParams.width(), screenParams.height())
            
            // todo: monocular mode
            
            if distortionCorrectionEnabled
            {
                self.updateEyeFovs()
                
                distortionRenderer.fovDidChange(headMountedDisplay, leftEye.fov, rightEye.fov, virtualEyeToScreenDistance())
                
                distortionRendererReady = true
            }
            else
            {
                updateUndistortedFOVAndViewport()
            }
            
            leftEye.projectionChanged = true
            rightEye.projectionChanged = true
            monocularEye.projectionChanged = true
            
            projectionChanged = false
        }
        
        if distortionCorrectionEnabled && distortionRenderer.viewportsChanged
        {
            distortionRenderer.updateViewports(&leftEye.viewport, &rightEye.viewport)
        }
    }
    
    func finishFrameWithViewPort(_ viewport:Viewport)
    {
        viewport.setGLViewport()
        viewport.setGLScissor()
        
        rendererDelegate!.finishFrameWithViewportRect(viewport.toCGRect())
    }
    
    func updateEyeFovs()
    {
        let deviceParams = headMountedDisplay.cardboardParams
        let screenParams = headMountedDisplay.screenParams
        
        let distortion = deviceParams.distortion
        
        let eyeToScreenDistance = self.virtualEyeToScreenDistance() // same
        let interLensDistance = deviceParams.interLensDistance //same
        let maxLeftEyeFOV = deviceParams.maximumLeftEyeFOV //same
        
        let outerDistance:Float = (screenParams.widthInMeters() - interLensDistance ) / 2.0
        let innerDistance:Float = interLensDistance / 2.0
        let bottomDistance:Float = deviceParams.verticalDistanceToLensCenter - screenParams.borderSizeMeters
        let topDistance:Float = screenParams.heightInMeters() + screenParams.borderSizeMeters - deviceParams.verticalDistanceToLensCenter
        
        let outerAngle = GLKMathRadiansToDegrees(atanf(distortion.distort(outerDistance / eyeToScreenDistance)))
        let innerAngle = GLKMathRadiansToDegrees(atanf(distortion.distort(innerDistance / eyeToScreenDistance)))
        let bottomAngle = GLKMathRadiansToDegrees(atanf(distortion.distort(bottomDistance / eyeToScreenDistance)))
        let topAngle = GLKMathRadiansToDegrees(atanf(distortion.distort(topDistance / eyeToScreenDistance)))
        
        leftEye.fov.left = min(outerAngle, maxLeftEyeFOV.left)
        leftEye.fov.right = min(innerAngle, maxLeftEyeFOV.right)
        leftEye.fov.bottom = min(bottomAngle, maxLeftEyeFOV.bottom)
        leftEye.fov.top = min(topAngle, maxLeftEyeFOV.top)
        
        rightEye.fov.left = leftEye.fov.right
        rightEye.fov.right = leftEye.fov.left
        rightEye.fov.bottom = leftEye.fov.bottom
        rightEye.fov.top = leftEye.fov.top
    }
    
    func updateUndistortedFOVAndViewport()
    {
        let deviceParams = headMountedDisplay.cardboardParams
        let screenParams = headMountedDisplay.screenParams
        
        let halfInterLensDistance:Float = deviceParams.interLensDistance * 0.5
        let eyeToScreenDistance:Float = self.virtualEyeToScreenDistance()

        let left = screenParams.widthInMeters()
        let right = halfInterLensDistance
        let bottom = deviceParams.verticalDistanceToLensCenter - screenParams.borderSizeMeters
        let top = screenParams.borderSizeMeters + screenParams.heightInMeters() - deviceParams.verticalDistanceToLensCenter
        
        leftEye.fov.left = GLKMathRadiansToDegrees(atan2f(left, eyeToScreenDistance))
        leftEye.fov.right = GLKMathRadiansToDegrees(atan2f(right, eyeToScreenDistance))
        leftEye.fov.bottom = GLKMathRadiansToDegrees(atan2f(bottom, eyeToScreenDistance))
        leftEye.fov.top = GLKMathRadiansToDegrees(atan2f(top, eyeToScreenDistance))
        
        rightEye.fov.left = GLKMathRadiansToDegrees(atan2f(right, eyeToScreenDistance))
        rightEye.fov.right = GLKMathRadiansToDegrees(atan2f(left, eyeToScreenDistance))
        rightEye.fov.bottom = GLKMathRadiansToDegrees(atan2f(bottom, eyeToScreenDistance))
        rightEye.fov.top = GLKMathRadiansToDegrees(atan2f(top, eyeToScreenDistance))
        
        let halfViewport = screenParams.width() / 2
        
        leftEye.viewport.setViewport(0, 0, halfViewport, screenParams.height())
        rightEye.viewport.setViewport(halfViewport, 0, halfViewport, screenParams.height())
    }
    
    func virtualEyeToScreenDistance() -> Float
    {
        return headMountedDisplay.cardboardParams.screenToLensDistance
    }

    func getFrameParameters(_ layer: Float, zNear: Float, zFar: Float)
    {
    }
    
}
