import QtQuick
import Quickshell
import "../../src/quickshell/components"
ShellRoot {
 id: test
 property int stage: 0
 property int acknowledgments: 0
 property var effects: ["fade", "grow", "wipe", "orbit"]
 NativeWallpaper {
  id: wall
  modelData: Quickshell.screens[0]
  preparedPath: Quickshell.env("WALL_GPU_A")
  preparedWidth: 960; preparedHeight: 540
  transitionPreview: Quickshell.env("WALL_GPU_PROXY_A")
  transitionWidth: 512; transitionHeight: 288
  motionEnabled: true; transitionDuration: 1200
  generation: 1
  onSourcePresented: {
   test.acknowledgments++;
   if(test.stage===0){ wall.contentItem.children[2].grabToImage(r=>r.saveToFile(Quickshell.env("WALL_GPU_OUTPUT")+"/initial.png"));next.start(); }
   else if(test.stage<4)next.start();
   else { console.log("NATIVE_GPU_COMPLETE",test.acknowledgments,wall.stableImage.implicitWidth,wall.stableImage.implicitHeight);finish.start(); }
  }
  onSourceFailed: (output,generation,message)=>{console.error("NATIVE_GPU_FAIL",message);Qt.exit(1)}
  onPhaseChanged: if(phase==="transition") capture.start()
 }
 Timer { id: next; interval:150; onTriggered:{
  wall.transitionName=test.effects[test.stage];test.stage++;
  const second=test.stage%2===1;
  wall.transitionPreview=Quickshell.env(second?"WALL_GPU_PROXY_B":"WALL_GPU_PROXY_A");
  wall.preparedPath=Quickshell.env(second?"WALL_GPU_B":"WALL_GPU_A");wall.generation++;
 }}
 Timer { id:capture;interval:600;onTriggered:{
  if(wall.shaderFailed || !wall.transitioning || wall.loadedImageCount!==2){console.error("NATIVE_GPU_FAIL transition",wall.shaderFailed,wall.phase);Qt.exit(2);}
  wall.contentItem.children[2].grabToImage(r=>r.saveToFile(Quickshell.env("WALL_GPU_OUTPUT")+"/"+wall.transitionName+".png"));
 }}
 Timer { id:finish;interval:150;onTriggered:{ if(wall.loadedImageCount!==1){console.error("NATIVE_GPU_FAIL retained proxy");Qt.exit(3)}Qt.quit(); }}
 Timer { interval:12000;running:true;onTriggered:{console.error("NATIVE_GPU_FAIL timeout",wall.phase);Qt.exit(4)} }
}
