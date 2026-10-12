#ifdef GL_ES
// Set default precision to medium
precision mediump int;
precision mediump float;
#endif

uniform samplerCube cubeMap;

void main()
{
  gl_Position = ftransform();
}
