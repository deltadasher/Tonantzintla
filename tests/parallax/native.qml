import QtQuick
import QtQuick.Window
import Quickshell
import "."
import "services"
import "modules/ephemeris/widgets/desktop"
Window {
 id:window;width:1280;height:850;visible:true;flags:Qt.Tool|Qt.WindowDoesNotAcceptFocus
 property int step:0
 property int failures:0
 property var originals:[]
 function check(ok,label){if(!ok){failures++;console.error("PARALLAX FAIL",label);}}
 function hasText(item,text){if(item.text===text)return true;for(const child of item.children || [])if(hasText(child,text))return true;return false;}
 function paths(){let result=[];for(let i=1;i<=picker.item.satelliteCount;i++)result.push(picker.item.orbitEntry(i).path);return result;}
 Rectangle {anchors.fill:parent;color:"#15111f"}
 Loader {id:picker;anchors.fill:parent;active:false;sourceComponent:WallpaperWidget{}}
 Timer {interval:180;running:true;repeat:true;onTriggered:{
  if(!Settings.persistenceReady || (window.step===0 && Environment.libraryProcess.running))return;
  if(window.step===0){
   Settings.motion=false;Settings.adaptivePalette=false;Environment.libraryRequested=true;
   const list=JSON.parse(Quickshell.env("PARALLAX_ENTRIES"));window.originals=list;
   Settings.wallpaperPath=list[9].path;Settings.wallpaperKind="image";Environment.localWallpapers=list;
   picker.active=true;
  } else if(window.step===1){
   window.check(!!picker.item && picker.item.selectedEntry.path===Settings.wallpaperPath,"opens on current wallpaper rather than first library item");
   window.check(window.hasText(picker.item,"IN USE"),"center clearly labels the current wallpaper");
   window.check(picker.item.satelliteCount===7,"seven alternatives beside current wallpaper");
   if(picker.item.satelliteCount!==undefined){
    window.check(paths().indexOf(Settings.wallpaperPath)<0,"current wallpaper not duplicated in satellites");
    const initial=paths().join('|');let changed=false;
    for(let attempt=0;attempt<5;attempt++){picker.item.shuffleOrbit();changed=changed||paths().join('|')!==initial;}
    window.check(changed,"shuffle changes sampled alternatives");
    window.check(picker.item.selectedEntry.path===Settings.wallpaperPath,"shuffle keeps current wallpaper at center");
    picker.item.rotateTo(1);
    window.check(picker.item.selectedEntry.path!==Settings.wallpaperPath,"alternatives can be previewed");
    window.check(paths().indexOf(Settings.wallpaperPath)>=0,"current wallpaper remains visible while browsing");
    picker.item.query="no matching alternative";
   }
  } else if(window.step===2){
   window.check(picker.item.selectedEntry.path===Settings.wallpaperPath && picker.item.satelliteCount===0,"filter never hides current wallpaper or duplicates a singleton");
   picker.item.query="";Settings.wallpaperPath=Quickshell.env("PARALLAX_EXTERNAL");
  } else if(window.step===3){
   window.check(picker.item.selectedEntry.path===Settings.wallpaperPath,"unindexed current wallpaper is shown");
   window.check(picker.item.selectedEntry.preview===Settings.wallpaperPath,"unindexed still has usable preview");
   picker.item.rotateTo(1);picker.item.visible=false;
  } else if(window.step===4){picker.item.visible=true;}
  else if(window.step===5){
   window.check(picker.item.selectedEntry.path===Settings.wallpaperPath,"reopening returns to current wallpaper");
   Environment.localWallpapers=[{name:"Current wallpaper",path:Settings.wallpaperPath,preview:Settings.wallpaperPath,kind:"image",source:"Local"}];
  } else if(window.step===6){
   window.check(picker.item.satelliteCount===0,"one-entry library has no duplicate satellite");
   picker.item.shuffleOrbit();window.check(picker.item.selectedEntry.path===Settings.wallpaperPath,"singleton shuffle is safe");
   Environment.localWallpapers=window.originals;Settings.wallpaperPath=window.originals[9].path;
  } else if(window.step===7){
   picker.item.rotateTo(1);
   window.contentItem.grabToImage(function(result){result.saveToFile(Quickshell.env("PARALLAX_CAPTURE"));});
  }
  if(window.step===8){Settings.motion=true;picker.item.shuffleOrbit();}
  else if(window.step===9){
   if(picker.item.shuffleRunning)return;
   window.check(picker.item.selectedIsCurrent && picker.item.satelliteCount===7,"animated shuffle settles on current wallpaper with distinct alternatives");
   picker.item.shuffleOrbit();
  } else if(window.step===10){
   picker.item.query="cancel shuffle";
   window.check(!picker.item.shuffleRunning && picker.item.selectedIsCurrent,"filter changes safely cancel an in-flight shuffle");
   picker.item.query="";
   window.contentItem.grabToImage(function(result){result.saveToFile(Quickshell.env("PARALLAX_CAPTURE")+"-current.png");console.log("PARALLAX COMPLETE",window.failures,"failures");Qt.exit(window.failures?1:0);});stop();
  }
  window.step++;
 }}
 Timer{interval:10000;running:true;onTriggered:Qt.exit(2)}
}
