//import ch.bildspur.postfx.builder.*;
//import ch.bildspur.postfx.pass.*;
//import ch.bildspur.postfx.*;
import processing.video.*;
import java.awt.image.BufferedImage;

PGraphics canvas[] = new PGraphics[2];
// The three shaders that are needed
PShader dither;
PShader outShader;
PShader inShader;

// Information for shared images
PImage backgroundImage;

//PostFX fx;
Movie myMovie;

AnimatedGifEncoder encoder = new AnimatedGifEncoder();
final static int EncoderFrameCaptureInterval = 200;
final static int DisplayFrameRate = 30;
final static int EncoderFrameRateModifier = 100;    // delay between frames in GIF file
final static int EncoderMaxFrames = 90;
int EncoderFrameCount = 0;
int iStartDisplayFrameCount = 0;
int iTotalTime = 0;
boolean EncoderFinished = false;
boolean EncoderStarted = false;

final int finalWidth = 128, finalHeight = 64;

void setup() {
  // Initialize the canvases
  size(384, 256, P2D);
  colorMode(RGB, 1.0);
  //backgroundImage = loadImage("test2.jpg");
  //backgroundImage.resize(finalWidth, finalHeight);
 // fx = new PostFX(this);
 
  canvas[0] = createGraphics(finalWidth, finalHeight, P3D);
  canvas[1] = createGraphics(finalWidth, finalHeight, P3D);
  
  // Initialize the shaders
  initMyDither();        // default to main dither effect
  initInShader();
  initOutShader();

  frameRate(DisplayFrameRate);
  
  myMovie = new Movie(this, "X:\\Documents\\Processing\\DitherShader\\mymovie.avi");
  myMovie.loop();
    
  encoder.setRepeat(0);
  encoder.setDelay(EncoderFrameRateModifier);
  encoder.setQuality(1);
}

// Called every time a new frame is available to read
void movieEvent(Movie m) {
  m.read();
}

// A few quick key commands
void keyPressed() {
  switch(key) {
    case 's':
      if (!EncoderStarted) {
        EncoderFrameCount = 0;
        iStartDisplayFrameCount = frameCount;
        iTotalTime = 0;
        encoder.start("X:\\Documents\\Processing\\DitherShader\\out.gif");
        EncoderStarted = true;
      }
      break;
    case '1': initAtkinson(); break;  // Use the Atkinson shader
    case '2': initMyDither(); break;  // Use the smoother shader
    case '3': initDirDither(); break; // Use the directional shader
  }
}

boolean iCurCanvas = false;
void SwapCanvas(PGraphics curCanvas, PGraphics lastCanvas)
{ 
  lastCanvas = canvas[iCurCanvas == false ? 0 : 1];
  curCanvas = canvas[iCurCanvas == false ? 1 : 0];
  
  iCurCanvas = !iCurCanvas;
}

// draw everything
void draw() {
  PGraphics curCanvas = canvas[0],
            lastCanvas = canvas[1];
  
  int CurDisplayFrameRate = 0;
  
  //clear buffer for redraw
  background(0); 
  
  curCanvas.beginDraw();

  //curCanvas.image(backgroundImage, (frameCount)%finalWidth, 0);
  //curCanvas.image(backgroundImage, (frameCount)%finalWidth-finalWidth, 0);
  
  curCanvas.image(myMovie, 0, 0, finalWidth, finalHeight);
  
  //image(cube, 0, 0);
  curCanvas.endDraw();
  
  SwapCanvas(curCanvas, lastCanvas);
  
  curCanvas.beginDraw();
  curCanvas.image(lastCanvas, 0, 0);
  inShader.set("textureIn", curCanvas);
    
  // Do the shader work needed to filter the frame:
  // 1. Run the input shader to initialize as the frames as needed
  curCanvas.filter(inShader);
  curCanvas.endDraw();
  
  SwapCanvas(curCanvas, lastCanvas);
  // 2. Repeatedly apply the dithering shader to perform the error diffusion.  
  //    There are 9 phases where px and py run over a 3x3 grid.
  //    The choice of t running up to 36 is a bit arbitrary.  There is a bit
  //    of a trade-off here.  The fewer the faster, and also more importantly 
  //    the less that the shimmering spreads.  The more iterations, the more
  //    accurately it can represent shades very close to black and white.
  //
  // In a real implementation, this should be done with a pingpong shading
  // technique rendering back and forth between a pair of buffers.  This version
  // in fact moves the image from the CPU memory to GPU memory, applies the shader
  // and the copies it back.  Repeating that 36 times per frame.  This slows it down
  // a fair bit!
  for (int t = 0; t < 36; t++) {
    
    curCanvas.beginDraw();
    curCanvas.image(lastCanvas, 0, 0);
    dither.set("px", t%3);
    dither.set("py", (t/3)%3);
    dither.set("textureIn", curCanvas);
    curCanvas.filter(dither);
    curCanvas.endDraw();
    
    SwapCanvas(curCanvas, lastCanvas);
  }
  
  curCanvas.beginDraw();
  curCanvas.image(lastCanvas, 0, 0);
  // 3. Get rid of the temporary data used by the dithering shader.
  outShader.set("textureIn", curCanvas);
  curCanvas.filter(outShader);
  curCanvas.endDraw();
  
  image(curCanvas, (width>>1) -(finalWidth>>1), (height>>1) - (finalHeight>>1));
  
  if (EncoderStarted)
  {
    CurDisplayFrameRate = Math.round( Math.max(Math.min(frameRate, DisplayFrameRate), 0.16f) );
    
    if (!EncoderFinished && (frameCount - iStartDisplayFrameCount) > (EncoderFrameCaptureInterval / CurDisplayFrameRate))
    {
      if ( (((frameCount - iStartDisplayFrameCount) * 1000) / CurDisplayFrameRate) % EncoderFrameCaptureInterval == 0 )
      {
        if (++EncoderFrameCount < EncoderMaxFrames)
        {
          encoder.addFrame((BufferedImage)curCanvas.getNative()); 
        }
        else
        {
          encoder.finish();
          EncoderFinished = true;
        }
      }
    }
  }
  // write the framerate to the image
  fill(1);
  textSize(20);
  text(frameRate, 10, 25);
  
  if (EncoderStarted)
  {
    if (EncoderFinished)
    {
      String result = String.format("Encoded (%d) [%d s]", EncoderFrameCount, iTotalTime);
      text(result, 5, height - 5);
    }
    else
    {
      iTotalTime = (frameCount - iStartDisplayFrameCount) / CurDisplayFrameRate;
      String result = String.format("Encoding... (%d - %d) [%d ms :: %d s]", EncoderFrameCount, EncoderMaxFrames, EncoderFrameCaptureInterval,iTotalTime);
      text(result, 5, height - 5);
    }
  }
  else
  {
    String result = String.format("Pending (%d)", EncoderMaxFrames);
    text(result, 5, height - 5);
  }
}

/**********************************************************
 * This loads the version of the shader needed to imitate *
 * that Atkinson style.  This version is somewhat         *
 * optimized so it runs a tiny bit faster.  The kernal    *
 * array is the one that is used. A bit of anatomy:       *
 *   Red: input image                                     *
 * Green: diffused error (up to sign)                     *
 *  Blue: sign of diffused error and the output           *
 *
 * In general, to imitate any of the classical error      *
 * diffusion dithering methods.  You can set the kernel   *
 * to match the diffusion matrix, and then mirror it so   *
 * that it is symmetrical.
 **********************************************************/

void initAtkinson() {
  String[] vertSource = {
    "#version 410", 

    "uniform mat4 transform;", 

    "in vec4 vertex;", 
    "in vec2 texCoord;", 

    "out vec2 vertTexCoord;", 

    "void main() {", 
      "vertTexCoord = vec2(texCoord.x, 1.0 - texCoord.y);", 
      "gl_Position = transform * vertex;", 
    "}"
  };
  String[] fragSource = {
    "#version 410", 

    "const float kernel[25] = float[](0.0/12, 0.0/12, 1.0/12, 0.0/12, 0.0/12,", 
                                     "0.0/12, 1.0/12, 1.0/12, 1.0/12, 0.0/12,", 
                                     "1.0/12, 1.0/12, 0.0/12, 1.0/12, 1.0/12,", 
                                     "0.0/12, 1.0/12, 1.0/12, 1.0/12, 0.0/12,", 
                                     "0.0/12, 0.0/12, 1.0/12, 0.0/12, 0.0/12);", 

    "uniform sampler2D textureIn;", 
    "uniform vec2 texOffset;", 

    "uniform int px;", 
    "uniform int py;", 

    "in vec2 vertTexCoord;", 
    "in vec4 gl_FragCoord;", 

    "out vec4 fragColor;", 

    "float err(float i, float j) {", 
      "vec4 temp = texture(textureIn, vertTexCoord + vec2(i*texOffset.x, j*texOffset.y));", 
      "return temp.y*(1.0-temp.z) - temp.y*temp.z;", 
    "}", 

    "void main() {", 
      "vec4 cur = texture(textureIn, vertTexCoord);", 
      "float sum = cur.x + (2*err(-1.5,0) + 2*err(1.5,0) + 2*err(0,-1.5) + 2*err(0,1.5) + err(-1,-1) + err(1,-1) + err(-1,1) + err(1,1))/12;", 
      "int fx = int(gl_FragCoord.x);", 
      "int fy = int(gl_FragCoord.y);", 
      "vec4 new = ((sum > 0.5))?vec4(cur.x,1.0-sum,1.0,1.0):vec4(cur.x,sum-0.0,0.0,1.0);", 
      "fragColor = ((fx % 3 == px)&&(fy % 3 == py))?new:cur;", 
    "}", 
  };
  dither = new PShader(this, vertSource, fragSource);
}

/**********************************************************
 * The more general version of the shader that actually   *
 * uses the kernel matrix.  In this case the kernel is a  *
 * Gaussian blur with standard deviation of 1 pixel.  In  *
 * general, the tighter the diffusion in a direction the  *
 * finer the texture.                                     *
 **********************************************************/

void initMyDither() {
  String[] vertSource = {
    "#version 410", 

    "uniform mat4 transform;", 

    "in vec4 vertex;", 
    "in vec2 texCoord;", 

    "out vec2 vertTexCoord;", 

    "void main() {", 
      "vertTexCoord = vec2(texCoord.x, 1.0 - texCoord.y);", 
      "gl_Position = transform * vertex;", 
    "}"
  };
  String[] fragSource = {
    "#version 410", 

    "const float kernel[25] = float[]( 1.0/232,  4.0/232,  7.0/232,  4.0/232,  1.0/232,", 
                                     " 4.0/232, 16.0/232, 26.0/232, 16.0/232,  4.0/232,", 
                                     " 7.0/232, 26.0/232,  0.0/232, 26.0/232,  7.0/232,", 
                                     " 4.0/232, 16.0/232, 26.0/232, 16.0/232,  4.0/232,", 
                                     " 1.0/232,  4.0/232,  7.0/232,  4.0/232,  1.0/232);", 

    "uniform sampler2D textureIn;", 
    "uniform vec2 texOffset;", 

    "uniform int px;", 
    "uniform int py;", 

    "in vec2 vertTexCoord;", 
    "in vec4 gl_FragCoord;", 

    "out vec4 fragColor;", 

    "float err(int i, int j) {", 
      "vec4 temp = texture(textureIn, vertTexCoord + vec2(i*texOffset.x, j*texOffset.y));", 
      "return temp.y*(1.0-temp.z) - temp.y*temp.z;", 
    "}", 

    "void main() {", 
      "vec4 cur = texture(textureIn, vertTexCoord);", 
      "float sum = cur.x + kernel[ 0]*err(-2,-2) + kernel[ 1]*err(-1,-2) + kernel[ 2]*err( 0,-2) + kernel[ 3]*err( 1,-2) + kernel[ 4]*err( 2,-2) +", 
                          "kernel[ 5]*err(-2,-1) + kernel[ 6]*err(-1,-1) + kernel[ 7]*err( 0,-1) + kernel[ 8]*err( 1,-1) + kernel[ 9]*err( 2,-1) +", 
                          "kernel[10]*err(-2, 0) + kernel[11]*err(-1, 0) + kernel[12]*err( 0, 0) + kernel[13]*err( 1, 0) + kernel[14]*err( 2, 0) +", 
                          "kernel[15]*err(-2, 1) + kernel[16]*err(-1, 1) + kernel[17]*err( 0, 1) + kernel[18]*err( 1, 1) + kernel[19]*err( 2, 1) +", 
                          "kernel[20]*err(-2, 2) + kernel[21]*err(-1, 2) + kernel[22]*err( 0, 2) + kernel[23]*err( 1, 2) + kernel[24]*err( 2, 2);", 
      "int fx = int(gl_FragCoord.x);", 
      "int fy = int(gl_FragCoord.y);", 
      "vec4 new = ((sum > 0.5))?vec4(cur.x,1.0-sum,1.0,1.0):vec4(cur.x,sum-0.0,0.0,1.0);", 
      "fragColor = ((fx % 3 == px)&&(fy % 3 == py))?new:cur;", 
    "}", 
  };
  dither = new PShader(this, vertSource, fragSource);
}

/**********************************************************
 * The exact same shader as above, but with a wider blur  *
 * in the vertical axis leading to the hatching style.    *
 **********************************************************/

void initDirDither() {
  String[] vertSource = {
    "#version 410", 

    "uniform mat4 transform;", 

    "in vec4 vertex;", 
    "in vec2 texCoord;", 

    "out vec2 vertTexCoord;", 

    "void main() {", 
    "vertTexCoord = vec2(texCoord.x, 1.0 - texCoord.y);", 
    "gl_Position = transform * vertex;", 
    "}"
  };
  String[] fragSource = {
    "#version 410", 

    "const float kernel[25] = float[]( 1.0/74,  4.0/74,  6.0/74,  4.0/74,  1.0/74,", 
                                     " 1.0/74,  4.0/74,  6.0/74,  4.0/74,  1.0/74,", 
                                     " 1.0/74,  4.0/74,  0.0/74,  4.0/74,  1.0/74,", 
                                     " 1.0/74,  4.0/74,  6.0/74,  4.0/74,  1.0/74,", 
                                     " 1.0/74,  4.0/74,  6.0/74,  4.0/74,  1.0/74);", 

    "uniform sampler2D textureIn;", 
    "uniform vec2 texOffset;", 

    "uniform int px;", 
    "uniform int py;", 

    "in vec2 vertTexCoord;", 
    "in vec4 gl_FragCoord;", 

    "out vec4 fragColor;", 

    "float err(int i, int j) {", 
    "vec4 temp = texture(textureIn, vertTexCoord + vec2(i*texOffset.x, j*texOffset.y));", 
    "return temp.y*(1.0-temp.z) - temp.y*temp.z;", 
    "}", 

    "void main() {", 
      "vec4 cur = texture(textureIn, vertTexCoord);", 
      "float sum = cur.x + kernel[ 0]*err(-2,-2) + kernel[ 1]*err(-1,-2) + kernel[ 2]*err( 0,-2) + kernel[ 3]*err( 1,-2) + kernel[ 4]*err( 2,-2) +", 
                          "kernel[ 5]*err(-2,-1) + kernel[ 6]*err(-1,-1) + kernel[ 7]*err( 0,-1) + kernel[ 8]*err( 1,-1) + kernel[ 9]*err( 2,-1) +", 
                          "kernel[10]*err(-2, 0) + kernel[11]*err(-1, 0) + kernel[12]*err( 0, 0) + kernel[13]*err( 1, 0) + kernel[14]*err( 2, 0) +", 
                          "kernel[15]*err(-2, 1) + kernel[16]*err(-1, 1) + kernel[17]*err( 0, 1) + kernel[18]*err( 1, 1) + kernel[19]*err( 2, 1) +", 
                          "kernel[20]*err(-2, 2) + kernel[21]*err(-1, 2) + kernel[22]*err( 0, 2) + kernel[23]*err( 1, 2) + kernel[24]*err( 2, 2);", 
      "int fx = int(gl_FragCoord.x);", 
      "int fy = int(gl_FragCoord.y);", 
      "vec4 new = ((sum > 0.5))?vec4(cur.x,1.0-sum,1.0,1.0):vec4(cur.x,sum-0.0,0.0,1.0);", 
      "fragColor = ((fx % 3 == px)&&(fy % 3 == py))?new:cur;", 
    "}", 
  };
  dither = new PShader(this, vertSource, fragSource);
}

/**********************************************************
 * Output shader.  Just takes the green channel as the    *
 * dithered output.                                       *
 **********************************************************/

void initOutShader() {
  String[] vertSource = {
    "#version 410", 

    "uniform mat4 transform;", 

    "in vec4 vertex;", 
    "in vec2 texCoord;", 

    "out vec2 vertTexCoord;", 

    "void main() {", 
      "vertTexCoord = vec2(texCoord.x, 1.0 - texCoord.y);", 
      "gl_Position = transform * vertex;", 
    "}"
  };
  String[] fragSource = {
    "#version 410", 

    "uniform sampler2D textureIn;", 
    "uniform vec2 texOffset;", 

    "in vec2 vertTexCoord;", 

    "out vec4 fragColor;", 

    "void main() {", 
      "vec4 cur = texture(textureIn, vertTexCoord);", 

      "fragColor = vec4(cur.z,cur.z,cur.z,1.0);", 
    "}", 
  };
  outShader = new PShader(this, vertSource, fragSource);
}

/**********************************************************
 * The shader to initialize.  Red channel contains the    *
 * input image.  Blue and Green are white noise.  The     *
 * same source of noise should be reused for each frame   *
 * if you want to have any coherence between frames.      *
 **********************************************************/

void initInShader() {
  String[] vertSource = {
    "#version 410", 

    "uniform mat4 transform;", 

    "in vec4 vertex;", 
    "in vec2 texCoord;", 

    "out vec2 vertTexCoord;", 

    "void main() {", 
      "vertTexCoord = vec2(texCoord.x, 1.0 - texCoord.y);", 
      "gl_Position = transform * vertex;", 
    "}"
  };
  String[] fragSource = {
    "#version 410", 

    "uniform sampler2D textureIn;", 
    "uniform sampler2D noise;", 
    "uniform vec2 texOffset;", 

    "in vec2 vertTexCoord;", 

    "out vec4 fragColor;", 

    "void main() {", 
      "vec4 cur = texture(textureIn, vertTexCoord);", 
      "vec4 noi = texture(noise, vertTexCoord);", 
  
      "fragColor = vec4(cur.x,noi.y,noi.z,1.0);", 
    "}", 
  };
  inShader = new PShader(this, vertSource, fragSource);

  PImage noise = new PImage(width, height);
  noise.loadPixels();
  for (int i = 0; i < width; i++) {
    for (int j = 0; j < height; j++) {
      noise.pixels[i+width*j] = color(0.0, random(1.0), random(1.0));
    }
  }
  noise.updatePixels();

  inShader.set("noise", noise);
}