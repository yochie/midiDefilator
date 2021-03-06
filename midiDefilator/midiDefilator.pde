import themidibus.*;
import javax.sound.midi.MidiMessage; 
import java.util.Arrays;
import java.util.List;

//Midi config
//Look at console to see available midi inputs and set
//the index of your midi device here
//TODO:  use gui to select midi input device
final int midiDevice  = 0;

//ordering here dictates correspondence to pads according to the following:
// BOTTOM_RIGHT // BOTTOM_LEFT // TOP_LEFT // TOP_RIGHT
final Integer[] notes = {85, 82, 84, 80};

//midi controller specific
final int NUM_PADS = notes.length;
final int MAX_VELOCITY = 100;

//Scrolling settings
int MAX_JUMP;
int MIN_JUMP;
final float LERP_SPEED = 0.66;

//1 for right scrolling , -1 for left scrolling
final int direction = 1;

//image files settings
final int MAX_FILES = 128;
final String dataDir = "/data/";
final List<String> allowedExtensions = Arrays.asList("jpg", "png", "pdf");

//Only using one of the elements in each of these arraylists, but kept for future usage
ArrayList<Integer> destinations; //updated based on pressed velocities
ArrayList<Boolean> padWasPressed; //flags indicating a pad was pressed, also updated by callback
ArrayList<Integer> pressedVelocity; //updated by midi callback

MidiBus myBus;

int numFrames = 0;  // The number of frames in the animation
int currentFrame = 0;
PImage[] images;
int offset = 0;

PImage frame;

//Configure whether frame should be used
boolean withFrame = false;

void setup() {
  fullScreen(P2D);
  frameRate(30);
  println(width + " x " + height);

  if (withFrame) {
    frame = loadImage("frame.png");
  }

  //TODO: switch to single jump distance since we want images to always realign to center
  MAX_JUMP = width/10;
  MIN_JUMP = width/10;

  //setup midi
  MidiBus.list();
  myBus = new MidiBus(this, midiDevice, 1); 

  //initialize variables set by midi callback
  destinations = new ArrayList<Integer>();
  pressedVelocity = new ArrayList<Integer>();
  padWasPressed = new ArrayList<Boolean>();
  for ( int pad = 0; pad < NUM_PADS; pad++) {
    destinations.add(0);
    pressedVelocity.add(0);
    padWasPressed.add(false);
  }
  // FILES
  String path = sketchPath();
  String[] filenames = listFileNames(path + dataDir);
  if (filenames == null) {

    stop();
  }
  try {
    filenames = sort(filenames);
    println(filenames);
    //filter out files that dont have allowed extensions
    List<String> lowerCaseExtensions = new ArrayList<String>();
    //create list with only lower cases so that we ignore case when testing file extensions
    for (String ext : allowedExtensions) {
      lowerCaseExtensions.add(ext.toLowerCase());
    }
    List<String> filteredList = filterFilenames(Arrays.asList(filenames), lowerCaseExtensions);

    //numFiles is number of available files in folder. All of them might not be used.
    int numFiles = filteredList.size();
    if (numFiles > MAX_FILES) {
      filteredList.subList(MAX_FILES, numFiles).clear();
    }

    //create final filename list
    String[] filteredFilenames = new String[filteredList.size()];
    filteredList.toArray(filteredFilenames); 

    //numFrames is actual number of files loaded by app.
    numFrames = filteredFilenames.length;
    images = new PImage[numFrames];
    for (int i = 0; i < numFrames; i += 1) {
      images[i] = loadImage(path + dataDir + filteredFilenames[i]);
    }
  } 
  catch (Exception e) {
    println("No pictures found. Please ensure your files are in the configured dataDir folder and that their extensions are listed in allowedExtensions.");
    exit();
  }

  if (numFrames == 0) {
    println("No pictures found. Please ensure your files are in the configured dataDir folder and that their extensions are listed in allowedExtensions.");
    exit();
  }
} 

void draw() { 
  background(0);

  if (offset >= width || offset <= -width) {
    offset = 0;
    currentFrame = (currentFrame + 1) % numFrames;  // Use % to cycle through frames
    destinations.set(0, destinations.get(0) - (direction * width));
    //println(currentFrame);
  }
  offset = Math.round(lerp(offset, destinations.get(0), LERP_SPEED));
  image(images[currentFrame], offset, 0, width, height);
  image(images[(currentFrame+1) % numFrames], offset - (direction * width), 0, width, height);
  image(images[(currentFrame+2) % numFrames], offset - (direction * width * 2), 0, width, height);
  if (frame != null && frame.width != -1) {
    image(frame, 0, 0, width, height);
  }

  if (padWasPressed.get(0)) {
    padWasPressed.set(0, false);
    int constrainedVelocity = constrain(pressedVelocity.get(0), 0, MAX_VELOCITY);
    int mappedVelocity = Math.round(map(constrainedVelocity, 0, MAX_VELOCITY, MIN_JUMP, MAX_JUMP));

    //extend destination further
    destinations.set(0, destinations.get(0) + (direction * mappedVelocity));
  }
}

// This function returns all the files in a directory as an array of Strings  
String[] listFileNames(String dir) {
  File file = new File(dir);
  if (file.isDirectory()) {
    String names[] = file.list();
    return names;
  } else {
    // If it's not a directory
    return null;
  }
}

//Called by MidiBus library whenever a new midi message is received
void midiMessage(MidiMessage message) {

  byte messageType = message.getMessage()[0];
  int channel = -1;
  int note = -1;
  int vel = -1;
  //Parse messages
  if ((messageType & 0xF0) == 0x80 || (messageType & 0xF0) == 0x90) {
    channel = (int) (messageType & 0x0F);
    note = (int)(message.getMessage()[1] & 0xFF);
    vel = (int)(message.getMessage()[2] & 0xFF);
  } else {
    println("Unknown message, skipping");
    return;
  }
  println("note: " + note + " vel: "+ vel);

  int pad = noteToPad(note);
  if (pad >= 0 && (vel > 0)) {
    padWasPressed.set(pad, true);
    pressedVelocity.set(pad, vel);
  }
}

int noteToPad (int note) {
  return Arrays.asList(notes).indexOf(note);
}

private static String getFileExtension(String filename) {
  String extension = "";
  int i = filename.lastIndexOf('.');
  if (i > 0) {
    extension = filename.substring(i+1).toLowerCase();
  }   
  return extension;
}

private static List<String> filterFilenames(List<String> names, List<String> allowed) {

  List<String> result = new ArrayList<String>();
  for (String name : names) {
    if (allowed.contains(getFileExtension(name))) {
      result.add(name);
    }
  }
  return result;
}
