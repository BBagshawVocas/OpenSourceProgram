/* 
 This program plots sensor data from a VOCAS Shield mounted to an Arduino, 
 and allows the user to save "smell signatures" that are associated with user- 
 chosen images in the main program directory, which can be recognized with the "guess" button
 
 Plotting method, GraphClass, and MockupSerial accredited to Sebastian Nilsson, https://github.com/sebnil/RealtimePlotter/tree/master/BasicRealtimePlotter 
 Detection Method accredited to Adam Emberton, Vocas Tech
 GUI and main code accredited to Brody Bagshaw, Vocas Tech
 */

/*

 SETUP:
 
 First find serialPortName (line 82) and change the value from "COM14" to whatever com port 
 your arduino, xbee, or receiver sending serial data to this program is connected to.
 
 
 Change Smell Representative Images:
 
 Press "Ctrl+K" to open this sketch folder. You can replace any images named "image#.jpg" (meaning "image1.jpg," for example)
 with images of your choosing, but for it to play nicely with the program, ALL USER IMAGES MUST BE 640x480.
 
 
 To use, hit the play button or press "Ctrl+R" (try "Ctrl+Shift+R" for present mode)
 once running, you have the option to press a button labeled "guess," or a button labeled "stop."
 
 
 Guess Button:
 
 Pressing this button causes the program to cross-reference the current sensor readings with the 
 saved "smell signatures" using a simple algorithm, and shows the image associated with that 
 saved smell.
 
 
 Stop Button:
 
 Pressing this button causes, well, the program to stop.
 
 
 How to Save New Smell Signature:
 
 In the program's vanilla form, it can save up to 10 user defined smell/image associated pairs.
 To save a new smell, expose the sensor to whatever you would like to save. Once the sensor readings
 have seemed to level out, you can press the numeric keys on you keyboard, keys 0-9, to save up to 10
 smells. For example, pressing the "2" key when exposing the sensor to coffee grounds will save the current
 sensor readings as the #2 smell. The #2 smell has an image associated with it that can be changed in the main 
 directory of the program. After saving #2 by pressing numeric key "2" while exposing the sensors to the coffee
 grounds, you can expose the sensors again to the coffee grounds and press the "guess" button and it will display
 the image associated with smell #2, as well as print the "distance" from the smell being guessed in the console.
 */

// import libraries
import java.awt.Frame;
import java.awt.BorderLayout;
import controlP5.*; // http://www.sojamo.de/libraries/controlP5/
import processing.serial.*;
import java.io.BufferedWriter;
import java.io.FileWriter;


PrintWriter output;
color bgc=color(44, 62, 80);
color btncolor=color(34, 167, 240);
color hover=color(25, 181, 254);// Background color
int[] serialInArray = new int[6];    // Where we'll put what we receive
int serialCount = 0;                 // A count of how many bytes we receive
Serial myPort;                       // The serial port
int count = 0;
int sensor1 = 0;
int sensor2 = 0;
int sensor3 = 0;
int sensor4 = 0;
int oldsensor1 = 0;
int oldsensor2 = 0;
int oldsensor3 = 0;
int oldsensor4 = 0;

/* SETTINGS BEGIN */

// Serial port to connect to
String serialPortName = "COM14";  //enter com port used

// If you want to debug the plotter without using a real serial port set this to true
boolean mockupSerial = false;

/* SETTINGS END */

Serial serialPort; // Serial port object

// interface stuff
ControlP5 cp5;
ControlP5 btns;

// Settings for the plotter are saved in this file
JSONObject plotterConfigJSON;

// plots
Graph LineGraph = new Graph(100, 550, 750, 150, color(20, 20, 200));
float[][] lineGraphValues = new float[6][100];
float[] lineGraphSampleNumbers = new float[100];
color[] graphColors = new color[6];

// helper for saving the executing path
String topSketchPath = "";
PImage img1;
int Sample_Number = 1;
String[] Samplelist={""};
int Sample_index = 0;
Boolean stop = false;
String filename = "Samples.txt";  //this will create a file in the folder named Samples.txt and use that file 

void setup() {
  background(bgc);  //background color
  surface.setTitle("VOCAS Dog");
  size(1024, 768);
  smooth();

  // set line graph colors

  graphColors[0] = color(131, 255, 20);
  graphColors[1] = color(232, 158, 12);
  graphColors[2] = color(255, 0, 0);
  graphColors[3] = color(62, 12, 232);
  graphColors[4] = color(13, 255, 243);
  graphColors[5] = color(200, 46, 232);

  // settings save file
  //  topSketchPath = sketchPath();
  plotterConfigJSON = loadJSONObject(topSketchPath+"/plotter_config.json");

  // gui

  cp5 = new ControlP5(this);
  cp5.setColorBackground( color(34, 49, 63) );
  btns = new ControlP5(this);
  btns.setColorBackground( btncolor ); 
  btns.setColorForeground( hover );
  btns.addButton("Guess")
    //Set X Y position
    .setPosition(40, 20)
    //Set size X Y
    .setSize(300, 50)
    //Set predefined button value (int)
    .setValue(0)
    //set activation method: RELEASE or PRESS
    .activateBy(ControlP5.RELEASE);
  ;
  btns.addButton("Stop")
    //Set X Y position
    .setPosition(40, 80)
    //Set size X Y
    .setSize(300, 50)
    //Set predefined button value (int)
    .setValue(1)
    .setColorForeground(color(242, 38, 19))
    .setColorBackground(color(207, 0, 15))
    .setColorActive(color(217, 30, 24))
    //set activation method: RELEASE or PRESS
    .activateBy(ControlP5.RELEASE)
    ;

  // init charts
  setChartSettings();
  // build x axis values for the line graph
  for (int i=0; i<lineGraphValues.length; i++) {
    for (int k=0; k<lineGraphValues[0].length; k++) {
      lineGraphValues[i][k] = 0;
      if (i==0)
        lineGraphSampleNumbers[k] = k;
    }
  }
  // start serial communication
  if (!mockupSerial) {
    serialPort = new Serial(this, serialPortName, 19200);  //it is CRITICAL that the baud rate for your arduino code and processing code be the same, our default is 115200
  } else {
    serialPort = null;
  }

  // build the gui
  int x = 0;
  int y = 725;
  cp5.addTextfield("Max").setPosition(x+15, y).setText(getPlotterConfigString("Max")).setColorCaptionLabel(0).setWidth(40).setAutoClear(false);
  cp5.addTextfield("Min").setPosition(x+65, y).setText(getPlotterConfigString("Min")).setColorCaptionLabel(0).setWidth(40).setAutoClear(false);

  int txt=250;
  cp5.addTextlabel("label").setText("Visibility").setPosition(x=915, y=500).setColor(txt);
  cp5.addTextlabel("Scaling").setText("Scaling").setPosition(x=970, y=500).setColor(txt);
  cp5.addTextfield("Scalar 1").setPosition(x=970, y=y+20).setText(getPlotterConfigString("Scalar 1")).setColorLabel(txt).setWidth(40).setAutoClear(false);
  cp5.addTextfield("Scalar 2").setPosition(x, y=y+40).setText(getPlotterConfigString("Scalar 2")).setColorLabel(txt).setWidth(40).setAutoClear(false);
  cp5.addTextfield("Scalar 3").setPosition(x, y=y+40).setText(getPlotterConfigString("Scalar 3")).setColorLabel(txt).setWidth(40).setAutoClear(false);
  cp5.addTextfield("Scalar 4").setPosition(x, y=y+40).setText(getPlotterConfigString("Scalar 4")).setColorLabel(txt).setWidth(40).setAutoClear(false);
  cp5.addTextfield("Scalar 5").setPosition(x, y=y+40).setText(getPlotterConfigString("Scalar 5")).setColorLabel(txt).setWidth(40).setAutoClear(false);
  cp5.addTextfield("Scalar 6").setPosition(x, y=y+40).setText(getPlotterConfigString("Scalar 6")).setColorLabel(txt).setWidth(40).setAutoClear(false);
  cp5.addToggle("Sensor 1").setPosition(x=915, y=520).setValue(int(getPlotterConfigString("Sensor 1"))).setColorLabel(txt).setMode(ControlP5.SWITCH).setColorActive(graphColors[0]);
  cp5.addToggle("Sensor 2").setPosition(x, y=y+40).setValue(int(getPlotterConfigString("Sensor 2"))).setColorLabel(txt).setMode(ControlP5.SWITCH).setColorActive(graphColors[1]);
  cp5.addToggle("Sensor 3").setPosition(x, y=y+40).setValue(int(getPlotterConfigString("Sensor 3"))).setColorLabel(txt).setMode(ControlP5.SWITCH).setColorActive(graphColors[2]);
  cp5.addToggle("Sensor 4").setPosition(x, y=y+40).setValue(int(getPlotterConfigString("Sensor 4"))).setColorLabel(txt).setMode(ControlP5.SWITCH).setColorActive(graphColors[3]);
  cp5.addToggle("Sensor 5").setPosition(x, y=y+40).setValue(int(getPlotterConfigString("Sensor 5"))).setColorLabel(txt).setMode(ControlP5.SWITCH).setColorActive(graphColors[4]);
  cp5.addToggle("Sensor 6").setPosition(x, y=y+40).setValue(int(getPlotterConfigString("Sensor 6"))).setColorLabel(txt).setMode(ControlP5.SWITCH).setColorActive(graphColors[5]);
}

void keyPressed() {  // press a number to store a sample
  switch (key)
  {
  case '0':
    Sample_Number = 0;
    break;
  case '1':
    Sample_Number = 1;
    break;
  case '2':
    Sample_Number = 2;
    break;
  case '3':
    Sample_Number = 3;
    break;
  case '4':
    Sample_Number = 4;
    break;
  case '5':
    Sample_Number = 5;
    break;
  case '6':
    Sample_Number = 6;
    break;
  case '7':
    Sample_Number = 7;
    break;
  case '8':
    Sample_Number = 8;
    break;  
  case '9':
    Sample_Number = 9;
    break;
  default:
    Sample_Number = 0;
  } 
  if (Sample_Number != 10) {
    try {
      output = new PrintWriter(new BufferedWriter(new FileWriter(sketchPath() + "/" + filename, true)));
      output.println(sensor1 + "\t" + sensor2 + "\t" + sensor3 + "\t" + sensor4 + "\t" + Sample_Number);
      output.close();
    } 
    catch (IOException e) {
      println("It Broke");
      e.printStackTrace();
    }
  }
} 

byte[] inBuffer = new byte[100]; // holds serial message
int i = 0; // loop variable

void draw() {
  if (mockupSerial || serialPort.available() > 0) {
    String myString = "";
    if (!mockupSerial) {
      try {
        serialPort.readBytesUntil('\r', inBuffer);
      }
      catch (Exception e) {
      }
      myString = new String(inBuffer);
    } else {
      myString = mockupSerialFunction();
    }
    String[] nums = split(myString, ' ');
    if (int(nums).length > 3) {
      oldsensor1 = sensor1 = int(nums[0]);
      oldsensor2 = sensor2 = int(nums[1]);
      oldsensor3 = sensor3 = int(nums[2]);
      oldsensor4 = sensor4 = int(nums[3]);
    } else {
      oldsensor1 = sensor1 = 0;
      oldsensor2 = sensor2 = 0;
      oldsensor3 = sensor3 = 0;
      oldsensor4 = sensor4 = 0;
    }
    for (i=0; i<int(nums).length; i++) {  //if the plot goes beyond 255, it draws terrible lines all over the window, so this stops that from happening
      if (int(nums[i])*float(getPlotterConfigString("Scalar "+(i+1))) > int(getPlotterConfigString("Max"))) {
        nums[i] = str(int(getPlotterConfigString("Max"))/int(getPlotterConfigString("Scalar "+(i+1))));
      }
    }
    int numberOfInvisibleLineGraphs = 0;
    for (i=0; i<6; i++) {
      if (int(getPlotterConfigString("Sensor "+(i+1))) == 0) {
        numberOfInvisibleLineGraphs++;
      }
    }

    for (i=0; i<nums.length; i++) {

      // update line graphdelay
      try {
        if (i<lineGraphValues.length) {
          for (int k=0; k<lineGraphValues[i].length-1; k++) {
            lineGraphValues[i][k] = lineGraphValues[i][k+1];
          }

          lineGraphValues[i][lineGraphValues[i].length-1] = float(nums[i])*float(getPlotterConfigString("Scalar "+(i+1)));
        }
      }
      catch (Exception e) {
      }
    }
  }

  // draw the line graphs
  LineGraph.DrawAxis();
  for (int i=0; i<lineGraphValues.length; i++) {
    LineGraph.GraphColor = graphColors[i];

    if (int(getPlotterConfigString("Sensor "+(i+1))) == 1)
      LineGraph.LineGraph(lineGraphSampleNumbers, lineGraphValues[i]);
  }
}

// called each time the chart settings are changed by the user 
void setChartSettings() {
  LineGraph.xLabel="";
  LineGraph.yLabel="";
  LineGraph.Title="";  
  LineGraph.xDiv=20;  
  LineGraph.xMax=0; 
  LineGraph.xMin=-100;  
  LineGraph.yMax=int(getPlotterConfigString("Max")); 
  LineGraph.yMin=int(getPlotterConfigString("Min"));
}

// handle gui actions
void controlEvent(ControlEvent theEvent) {
  if (theEvent.isAssignableFrom(Textfield.class) || theEvent.isAssignableFrom(Toggle.class) || theEvent.isAssignableFrom(Button.class)) {
    String parameter = theEvent.getName();
    String value = "";
    if (theEvent.isAssignableFrom(Textfield.class))
      value = theEvent.getStringValue();
    else if (theEvent.isAssignableFrom(Toggle.class) || theEvent.isAssignableFrom(Button.class))
      value = theEvent.getValue()+"";

    plotterConfigJSON.setString(parameter, value);
    saveJSONObject(plotterConfigJSON, topSketchPath+"/plotter_config.json");
  }
  setChartSettings();
  if (theEvent.isController()) {
    println(theEvent.getController().getName());
    if (theEvent.name() == "Stop") {
      count++;
      //println("count = "+count);
      if (count > 1) {
        exit();
      }
    } else if (theEvent.name() == "Guess") {
      int xloc = width-645;
      int yloc = 5;
      Samplelist = loadStrings(filename);
      float[] Distance = new float[Samplelist.length]; //create array the size of the sample list
      int index = 0;
      int Guess_index = 0;
      String[] Sample_Component =  split(Samplelist[index], '\t');
      for ( index = 0; index < Samplelist.length; index=index+1) { // check each sample
        Sample_Component = split(Samplelist[index], '\t');
        println("Sample Components");
        println(Sample_Component[0] + "\t" + Sample_Component[1] + "\t" + Sample_Component[2] + "\t" + Sample_Component[3] + "\t" + Sample_Component[4]);
        int sampleValue1 = int(Sample_Component[0]);
        int sampleValue2 = int(Sample_Component[1]);
        int sampleValue3 = int(Sample_Component[2]);
        int sampleValue4 = int(Sample_Component[3]);
        //Guessing Algorithim
        Distance[index] = sqrt(sq(sensor1-sampleValue1)+sq(sensor2-sampleValue2)+sq(sensor3-sampleValue3)+sq(sensor4-sampleValue4));
      }

      if (min(Distance) < 50) {
        for (int i=0; i < Distance.length; i++) { 
          if (Distance[i] == min(Distance)) {  // smallest distance value is the closest guess for the smell
            Guess_index = i;
          }
        } 
        //println(Samplelist[Guess_index]);  //
        Sample_Component = split(Samplelist[Guess_index], '\t');
        int RecogNumb = int(Sample_Component[4]);
        print("Smell Number: ");
        println(RecogNumb);
        switch (RecogNumb)            // load a picture of the sample guessed. 6 pictures are pre-loaded, more can be added
        {
        case 1:
          ImgClear(xloc, yloc, 640, 480);
          img1 = loadImage("image1.jpg");
          image(img1, xloc, yloc ); 
          break;
        case 2:
          ImgClear(xloc, yloc, 640, 480);
          img1 = loadImage("image2.jpg");
          image(img1, xloc, yloc );  
          break;
        case 3:
          ImgClear(xloc, yloc, 640, 480);
          img1 = loadImage("image3.jpg");
          image(img1, xloc, yloc );  
          break;
        case 4:
          ImgClear(xloc, yloc, 640, 480);
          img1 = loadImage("image4.jpg");
          image(img1, xloc, yloc );  
          break;
        case 5:
          ImgClear(xloc, yloc, 640, 480);
          img1 = loadImage("image5.jpg");
          image(img1, xloc, yloc ); 
          break;
        case 6:
          ImgClear(xloc, yloc, 640, 480);
          img1 = loadImage("image6.jpg");
          image(img1, xloc, yloc );  
          break;
        case 7:
          ImgClear(xloc, yloc, 640, 480);
          img1 = loadImage("image7.jpg");
          image(img1, xloc, yloc ); 
          break;
        case 8:
          ImgClear(xloc, yloc, 640, 480);
          img1 = loadImage("image8.jpg");
          image(img1, xloc, yloc );  
          break;
        case 9:
          ImgClear(xloc, yloc, 640, 480);
          img1 = loadImage("image9.jpg");
          image(img1, xloc, yloc ); 
          break; 
        case 0:
          ImgClear(xloc, yloc, 640, 480);
          img1 = loadImage("questionmark.png");
          image(img1, xloc, yloc ); 
          break;
        default:
          ImgClear(xloc, yloc, 640, 480);
          img1 = loadImage("questionmark.png");
          image(img1, xloc, yloc );
        }
      } else {
        ImgClear(xloc, yloc, 640, 480);
        img1 = loadImage("questionmark.png");
        image(img1, xloc, yloc );
      }
      print("Distance: ");
      println(min(Distance));
    }
  }
}

// get gui settings from settings file
String getPlotterConfigString(String id) {
  String r = "";
  try {
    r = plotterConfigJSON.getString(id);
  } 
  catch (Exception e) {
    r = "";
  }
  return r;
}

void ImgClear(int x, int y, int w, int l) {
  fill(bgc);
  noStroke();
  rect(x, y, w, l);
}