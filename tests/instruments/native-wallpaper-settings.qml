import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import "../../src/quickshell"
import "../../src/quickshell/services"
import "../../src/quickshell/modules/ephemeris/widgets/desktop"
Window {
 id:root; width:320; height:420; visible:true
 property bool prepared:false
 property int stage:0; property int failures:0
 function check(ok,message){if(!ok){failures++;console.error("NATIVE UI FAIL",message);}}
 function find(item,name){if(item.Accessible && item.Accessible.name===name)return item;for(const child of item.children||[]){const found=find(child,name);if(found)return found;}return null;}
 function named(item,name){if(item.objectName===name)return item;for(const child of item.children||[]){const found=named(child,name);if(found)return found;}return null;}
 function press(name){const item=find(loader.item,name);check(!!item,"accessible "+name);if(item){item.forceActiveFocus();events.keyClick(Qt.Key_Space,Qt.NoModifier,-1);}return item;}
 TestEvent{id:events}
 FileView{id:disk;path:Settings.configPath}
 Component.onCompleted:{Environment.libraryRequested=true;Environment.wallpaperRestored=true;Environment.localWallpapers=[{name:"Fixture",path:"",preview:"",kind:"image",source:"Tonantzintla"}];prepared=true;}
 Item{id:scene;anchors.fill:parent
  Rectangle{anchors.fill:parent;color:Theme.void_}
  Loader{id:loader;anchors.fill:parent;active:root.prepared&&Settings.persistenceReady;sourceComponent:WallpaperWidget{}}
 }
 Timer{interval:600;running:true;repeat:true;onTriggered:{
  if(!loader.item)return;
  if(stage===0){
   check(Settings.wallpaperRenderer==="external","portable default stays external");
   loader.item.optionsOpen=true;press("Renderer: Native stills");check(Settings.wallpaperRenderer==="native","native key choice updates real Settings");
   stage++;
  }else if(stage===1){
   const effect=press("none wallpaper transition");check(Settings.wallpaperTransition==="none","native reveal choice has real preference consumer");
   Settings.wallpaperOutputs="B";Environment.persistNativeAssignment(["A"],"/first.png","image");Environment.persistNativeAssignment(["B"],"/second.png","image");
   const scroll=named(loader.item,"wallpaperOptionsScroll");check(scroll && scroll.contentY>0,"keyboard focus scrolls short options to reveal controls");
   if(effect && scroll){const p=effect.mapToItem(scroll,0,0);check(p.y>=-1 && p.y+effect.height<=scroll.height+1,"focused transition is inside short viewport");}
   stage++;
  }else if(stage===2){
   disk.reload();disk.waitForJob();const saved=JSON.parse(disk.text());
   check(saved.wallpaperRenderer==="native" && saved.nativeWallpaperAssignments.A.source==="/first.png" && saved.nativeWallpaperAssignments.B.source==="/second.png","renderer and bounded per-output source intent persist");
   check(saved.wallpaperOutputs==="B","output preference persists unchanged");
   scene.grabToImage(function(result){result.saveToFile(Quickshell.env("NATIVE_UI_SCREENSHOT"));});
   stage++;
  }else if(stage===3){
   press("Renderer: External");stage++;
  }else{
   check(Settings.wallpaperRenderer==="external","keyboard returns to external renderer");
   console.log("NATIVE UI COMPLETE",failures);Qt.quit();
  }
 }}
}
