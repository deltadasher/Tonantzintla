import QtQuick
import QtTest
import Quickshell
import "../../src/quickshell"
import "../../src/quickshell/services"
import "../../src/quickshell/modules/ephemeris/widgets/desktop"
Window {
 id:root;width:1100;height:Number(Quickshell.env("PALETTE_TEST_HEIGHT") || 850);visible:true;color:"#080910"
 property int step:0
 property int failures:0
 property int ticks:0
 property string prior:""
 property string wallpaper:""
 function check(value,message) {if(!value){failures++;console.error("PALETTE FAIL",message);}}
 function find(item,name) {
  if(name==="swatch" && typeof item.choose==="function" && item.modelData==="#cc8844")return item;
  if(item.objectName===name)return item;
  for(const child of item.children || []) {const found=find(child,name);if(found)return found;}
  return null;
 }
 TestEvent {id:events}
 Loader {id:picker;anchors.fill:parent;active:false;sourceComponent:WallpaperWidget {}}
 Timer {interval:100;running:true;repeat:true;onTriggered:{
  if(!Settings.persistenceReady)return;
  root.ticks++;
  if(root.step===0) {
   Settings.adaptivePalette=false;Settings.wallpaperPath=Quickshell.env("PALETTE_B");
   root.prior=String(Theme.accent);root.wallpaper=Settings.wallpaperPath;
   Environment.libraryRequested=true;
   Environment.localWallpapers=[{name:"Selected violet world",path:root.wallpaper,preview:root.wallpaper,kind:"image",source:"Tonantzintla"}];
   picker.active=true;root.step++;root.ticks=0;
  } else if(root.step===1 && root.ticks>10) {
   root.check(picker.status===Loader.Ready,"real picker loads");
   const swatch=root.find(picker.item,"swatch");
   root.check(!!swatch,"actual Matugen candidate colors are selectable");
   if(swatch) {root.requestActivate();swatch.forceActiveFocus();events.keyClick(Qt.Key_Return,Qt.NoModifier,-1);}
   root.step++;root.ticks=0;
  } else if(root.step===2 && root.ticks>8) {
   root.check(String(Theme.accent)===root.prior && Settings.paletteSeedColor==="","preview does not apply theme");
   root.check(Settings.wallpaperPath===root.wallpaper,"preview preserves wallpaper");
   const apply=root.find(picker.item,"applyThemeSeed");root.check(!!apply && apply.enabled,"Apply available after preview");
   if(apply) {apply.forceActiveFocus();events.keyClick(Qt.Key_Return,Qt.NoModifier,-1);}
   root.step++;root.ticks=0;
  } else if(root.step===3 && root.ticks>6 && !AdaptivePalette.busy) {
   root.check(Settings.paletteSeedColor==="#cc8844","Apply persists chosen seed");
   root.check(Settings.adaptivePalette && String(Theme.accent)==="#cc8844","Apply changes actual inherited Theme.accent");
   root.check(Settings.wallpaperPath===root.wallpaper,"Apply theme preserves wallpaper");
   AdaptivePalette.setSeed("#badbad");root.step++;root.ticks=0;
  } else if(root.step===4 && root.ticks>6 && !AdaptivePalette.busy) {
   root.check(AdaptivePalette.error.length>0,"failure visible");
   root.check(Settings.paletteSeedColor==="#cc8844" && String(Theme.accent)==="#cc8844","failed Apply preserves settings and last valid theme");
   const automatic=root.find(picker.item,"automaticThemeSeed");root.check(!!automatic && automatic.enabled,"Automatic available");
   if(automatic) {automatic.forceActiveFocus();events.keyClick(Qt.Key_Return,Qt.NoModifier,-1);}
   root.step++;root.ticks=0;
  } else if(root.step===5 && root.ticks>6 && !AdaptivePalette.busy) {
   root.check(Settings.paletteSeedColor==="" && String(Theme.accent)==="#445566","Automatic returns to wallpaper color generation");
   root.check(AdaptivePalette.error==="","successful apply clears prior failure");
   AdaptivePalette.setSeed("#112233");root.step=6;root.ticks=0;
  } else if(root.step===6 && AdaptivePalette.paletteProcess.running) {
   Settings.adaptivePalette=false;root.step=7;root.ticks=0;
  } else if(root.step===7 && root.ticks>10 && !AdaptivePalette.busy) {
   root.check(!Settings.adaptivePalette && Settings.paletteSeedColor==="","late generation cannot override newer settings");
   root.check(AdaptivePalette.appliedSeed==="","stale seed was not applied");
   Settings.adaptivePalette=true;root.step=8;root.ticks=0;
  } else if(root.step===8 && root.ticks>10 && !AdaptivePalette.busy) {
   root.check(String(Theme.accent)==="#445566","latest automatic preference recovers");
   const panel=root.find(picker.item,"themePreviewPanel");
   root.check(panel && panel.visible,"preview panel remains visible after applying");
   if(panel) {const pos=panel.mapToItem(root.contentItem,0,0);root.check(pos.y>=0 && pos.x>=0 && pos.x+panel.width<=root.width,"preview remains inside window");}
   stop();root.contentItem.grabToImage(function(result){root.check(result.saveToFile(Quickshell.env("PALETTE_SCREENSHOT")),"render saved");console.log("PALETTE COMPLETE",root.failures,"failures");Qt.quit();});
  }
 }}
 Timer {interval:12000;running:true;onTriggered:{console.error("PALETTE FAIL timeout",root.step,AdaptivePalette.error);Qt.quit();}}
}
