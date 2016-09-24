
import GLKit
import OpenGLES

let UNIFORM_MODELVIEWPROJECTION_MATRIX = 0
let UNIFORM_NORMAL_MATRIX = 1
var uniforms = [GLint](repeating: 0, count: 2)

class GameViewController: CSViewController, CSStereoRendererDelegate
{
    var program: GLuint = 0
    
    var headViewMatrix:GLKMatrix4 = GLKMatrix4Identity
    var modelViewProjectionMatrix:GLKMatrix4 = GLKMatrix4Identity
    var normalMatrix: GLKMatrix3 = GLKMatrix3Identity
    
    var rotation: Float = 0.0
    
    var vertexArray: GLuint = 0
    var vertexBuffer: GLuint = 0
    
    var cubePositionLocation:GLint = 0
    var cubeNormalLocation:GLint = 0
    
    override func viewDidLoad()
    {
        rendererDelegate = self
        
        super.viewDidLoad()
    }
    
    func setupRendererWithView(_ view:GLKView)
    {
        EAGLContext.setCurrent(view.context)
        
        if (!self.loadShaders()) {
            return
        }
        
        glEnable(GLenum(GL_DEPTH_TEST))
        
        glGenVertexArraysOES(1, &vertexArray)
        glBindVertexArrayOES(vertexArray)
        
        cubePositionLocation = glGetAttribLocation(program, "position")
        cubeNormalLocation = glGetAttribLocation(program, "normal")
        
        glGenBuffers(1, &vertexBuffer)
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), vertexBuffer)
        glBufferData(GLenum(GL_ARRAY_BUFFER), GLsizeiptr(MemoryLayout<GLfloat>.size * gCubeVertexData.count), &gCubeVertexData, GLenum(GL_STATIC_DRAW))
        
        glEnableVertexAttribArray(GLuint(cubePositionLocation))
        withUnsafePointer(to: &cubePositionLocation, {
            glVertexAttribPointer(GLuint(cubePositionLocation), 3, GLenum(GL_FLOAT), GLboolean(GL_FALSE), 24, UnsafeRawPointer($0))
        })
        glEnableVertexAttribArray(GLuint(cubeNormalLocation))
        withUnsafePointer(to: &cubeNormalLocation, {
            glVertexAttribPointer(GLuint(cubeNormalLocation), 3, GLenum(GL_FLOAT), GLboolean(GL_FALSE), 24, UnsafeRawPointer($0).advanced(by: 12))
        })
        glBindVertexArrayOES(0)
    }
    
    func prepareNewFrameWithHeadViewMatrix(_ headViewMatrix:GLKMatrix4)
    {
        self.headViewMatrix = headViewMatrix
        
        rotation += Float(self.timeSinceLastUpdate * 0.5)
    }
    
    func drawEyeWithEye(_ eye:EyeMatrix)
    {
        glClearColor(0.5, 0.5, 0.5, 1.0)
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT) | GLbitfield(GL_DEPTH_BUFFER_BIT))

        // todo: We currently don't account for each eye being in a slightly different position
        
        var baseModelViewMatrix = GLKMatrix4MakeTranslation(0.0, 0.0, -6.0)
        baseModelViewMatrix = GLKMatrix4Rotate(baseModelViewMatrix, rotation, 0.0, 1.0, 0.0)
        
        var modelViewMatrix = GLKMatrix4MakeTranslation(0.0, 0.0, 4.5)
        modelViewMatrix = GLKMatrix4Rotate(modelViewMatrix, rotation, 1.0, 1.0, 1.0)
        modelViewMatrix = GLKMatrix4Multiply(baseModelViewMatrix, modelViewMatrix)
        
        modelViewMatrix = GLKMatrix4Multiply(headViewMatrix, modelViewMatrix)
        
        normalMatrix = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(modelViewMatrix), nil)
        
        let aspect = fabsf(Float(self.view.bounds.size.width / self.view.bounds.size.height))
        let projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(65.0), aspect, 0.1, 100.0)
        
        modelViewProjectionMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix)
        
        glUseProgram(program)
        glBindVertexArrayOES(vertexArray)

        // https://swift.org/migration-guide/se-0107-migrate.html
        withUnsafePointer(to: &modelViewProjectionMatrix, {
            glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX], 1, 0, UnsafeRawPointer($0).assumingMemoryBound(to: GLfloat.self))
        })
        
        withUnsafePointer(to: &normalMatrix, {
            glUniformMatrix3fv(uniforms[UNIFORM_NORMAL_MATRIX], 1, 0, UnsafeRawPointer($0).assumingMemoryBound(to: GLfloat.self))
        })
        
        glDrawArrays(GLenum(GL_TRIANGLES), 0, 36)
        
        glBindVertexArrayOES(0)
        glUseProgram(0)
    }
    
    func shutdownRendererWithView(_ view:GLKView)
    {
        // todo: Should handle this...
    }
    
    func rendererDidChangeSize(_ size:CGSize)
    {
        // todo: Should handle this...
    }
    
    func finishFrameWithViewportRect(_ viewport:CGRect)
    {
        // todo: Should handle this...
    }
    
    func loadShaders() -> Bool
    {
        var vertShader: GLuint = 0
        var fragShader: GLuint = 0
        var vertShaderPathname: String
        var fragShaderPathname: String
        
        program = glCreateProgram()
        
        vertShaderPathname = Bundle.main.path(forResource: "Shader", ofType: "vsh")!
        if GLCompileShaderFromFile(&vertShader, type: GLenum(GL_VERTEX_SHADER), file: vertShaderPathname) == false
        {
            print("Failed to compile vertex shader")
            return false
        }
        
        fragShaderPathname = Bundle.main.path(forResource: "Shader", ofType: "fsh")!
        if !GLCompileShaderFromFile(&fragShader, type: GLenum(GL_FRAGMENT_SHADER), file: fragShaderPathname)
        {
            print("Failed to compile fragment shader")
            return false
        }
        
        glAttachShader(program, vertShader)
        
        glAttachShader(program, fragShader)
        
        glBindAttribLocation(program, GLuint(GLKVertexAttrib.position.rawValue), "position")
        glBindAttribLocation(program, GLuint(GLKVertexAttrib.normal.rawValue), "normal")
        
        if !GLLinkProgram(program)
        {
            print("Failed to link program: \(program)")
            
            if vertShader != 0
            {
                glDeleteShader(vertShader)
                vertShader = 0
            }
            if fragShader != 0
            {
                glDeleteShader(fragShader)
                fragShader = 0
            }
            if program != 0
            {
                glDeleteProgram(program)
                program = 0
            }
            
            return false
        }
        
        uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX] = glGetUniformLocation(program, "modelViewProjectionMatrix")
        uniforms[UNIFORM_NORMAL_MATRIX] = glGetUniformLocation(program, "normalMatrix")

        return true
    }
    
    override func didReceiveMemoryWarning()
    {
        super.didReceiveMemoryWarning()
        
        if self.isViewLoaded && (self.view.window != nil)
        {
            self.view = nil
            
            self.tearDownGL()
            
            if EAGLContext.current() === self.glContext
            {
                EAGLContext.setCurrent(nil)
            }
            
            self.glContext = nil
        }
    }
    
    deinit
    {
        self.tearDownGL()
        
        if EAGLContext.current() === self.glContext
        {
            EAGLContext.setCurrent(nil)
        }
    }
    
    func tearDownGL()
    {
        EAGLContext.setCurrent(self.glContext)
        
        glDeleteBuffers(1, &vertexBuffer)
        glDeleteVertexArraysOES(1, &vertexArray)
        
        if program != 0 {
            glDeleteProgram(program)
            program = 0
        }
    }
}

var gCubeVertexData: [GLfloat] = [

    // position (x,y,z)      normal(x,y,z)
    
    10.5, -0.5, -0.5,        1.0, 0.0, 0.0,
    10.5, 0.5, -0.5,         1.0, 0.0, 0.0,
    10.5, -0.5, 0.5,         1.0, 0.0, 0.0,
    10.5, -0.5, 0.5,         1.0, 0.0, 0.0,
    10.5, 0.5, -0.5,         1.0, 0.0, 0.0,
    10.5, 0.5, 0.5,          1.0, 0.0, 0.0,
    
    10.5, 0.5, -0.5,         0.0, 1.0, 0.0,
    -10.5, 0.5, -0.5,        0.0, 1.0, 0.0,
    10.5, 0.5, 0.5,          0.0, 1.0, 0.0,
    10.5, 0.5, 0.5,          0.0, 1.0, 0.0,
    -10.5, 0.5, -0.5,        0.0, 1.0, 0.0,
    -10.5, 0.5, 0.5,         0.0, 1.0, 0.0,
    
    -0.5, 0.5, -0.5,        -1.0, 0.0, 0.0,
    -0.5, -0.5, -0.5,      -1.0, 0.0, 0.0,
    -0.5, 0.5, 0.5,         -1.0, 0.0, 0.0,
    -0.5, 0.5, 0.5,         -1.0, 0.0, 0.0,
    -0.5, -0.5, -0.5,      -1.0, 0.0, 0.0,
    -0.5, -0.5, 0.5,        -1.0, 0.0, 0.0,
    
    -0.5, -0.5, -0.5,      0.0, -1.0, 0.0,
    0.5, -0.5, -0.5,        0.0, -1.0, 0.0,
    -0.5, -0.5, 0.5,        0.0, -1.0, 0.0,
    -0.5, -0.5, 0.5,        0.0, -1.0, 0.0,
    0.5, -0.5, -0.5,        0.0, -1.0, 0.0,
    0.5, -0.5, 0.5,         0.0, -1.0, 0.0,
    
    0.5, 0.5, 0.5,          0.0, 0.0, 1.0,
    -0.5, 0.5, 0.5,         0.0, 0.0, 1.0,
    0.5, -0.5, 0.5,         0.0, 0.0, 1.0,
    0.5, -0.5, 0.5,         0.0, 0.0, 1.0,
    -0.5, 0.5, 0.5,         0.0, 0.0, 1.0,
    -0.5, -0.5, 0.5,        0.0, 0.0, 1.0,
    
    0.5, -0.5, -0.5,        0.0, 0.0, -1.0,
    -0.5, -0.5, -0.5,      0.0, 0.0, -1.0,
    0.5, 0.5, -0.5,         0.0, 0.0, -1.0,
    0.5, 0.5, -0.5,         0.0, 0.0, -1.0,
    -0.5, -0.5, -0.5,      0.0, 0.0, -1.0,
    -0.5, 0.5, -0.5,        0.0, 0.0, -1.0
]
