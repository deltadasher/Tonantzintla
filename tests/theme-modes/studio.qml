import QtQuick
import QtTest
import Quickshell
import "../../src/quickshell"
import "../../src/quickshell/components"
import "../../src/quickshell/modules/ephemeris/widgets/catalog"
Window {
 id: window; width:480; height:760; visible:true; color:Theme.void_
 property int step:0
 property int failures:0
 function check(value,label) { if(!value){failures++;console.error("STUDIO FAIL",label);} }
 function find(item,name) {
  if(item.Accessible && item.Accessible.name===name)return item;
  for(const child of item.children || []) {const found=find(child,name);if(found)return found;}
  return null;
 }
 function press(name) {const item=find(window.contentItem,name);check(!!item,name);if(item){item.forceActiveFocus();events.keyClick(Qt.Key_Space,Qt.NoModifier,-1);}}
 TestEvent {id:events}
 Flickable {anchors.fill:parent;contentHeight:studio.implicitHeight;clip:true
  ThemeStudio {id:studio;width:parent.width;visible:window.step<4 || window.step>5}
  BarAppearanceControls {id:barControls;width:parent.width;visible:window.step>=4 && window.step<=5}
  GuideWidget {id:guide;visible:false}
 }
 LiquidSurface {id:surface;visible:false;material:Settings.barMaterial;width:100;height:40}
 Timer {interval:150;running:true;repeat:true;onTriggered:{
  if(!Settings.persistenceReady)return;
  if(window.step===0){
   window.requestActivate();studio.preset("prism");
   window.check(Settings.barMaterial==="liquid" && Settings.panelMaterial==="liquid","preset applies both real materials");
   window.check(surface.material==="liquid" && !surface.usable,"hidden/software glass unloads safely");
   studio.page="colors";
  } else if(window.step===1){press("Appearance: Light");}
  else if(window.step===2){window.check(Theme.isLight,"keyboard applies light mode");press("Appearance: Automatic");Settings.spectralColors={accent:"#010101"};}
  else if(window.step===3){
   window.check(Theme.isLight && String(Theme.accent)==="#010101","dark custom accent retained");
   window.check(String(Theme.onAccent)==="#ffffff","selected labels readable on dark accents");
   window.check(find(studio,"Clock face: Matrix")===null,"bar controls removed from global theme studio");
   window.check(guide.tabs.length===2 && guide.tabs.indexOf("Lock")<0,"manual lock section removed");
  } else if(window.step===4){press("Aperture finish: Classic");press("Workspace indicators: Track");press("Clock face: Matrix");press("Corners: Square");press("Edges: Accent");}
  else if(window.step===5){
   window.check(Settings.barWorkspaceStyle==="track" && Settings.barClockFace==="matrix","bar visual controls commit");
   window.check(Settings.barCornerRadius===0 && Settings.barEdgeStyle==="accent","shape controls commit");
   window.check(studio.width<=480,"narrow layout bounds");
   studio.page="materials";
  } else if(window.step===6){press("Ephemeris finish: Frosted");}
  else if(window.step===7){window.check(Settings.barMaterial==="classic" && Settings.panelMaterial==="frosted","independent materials");}
  else if(window.step>9 && !Settings.saveTimer.running && !Settings.preferencesLoading){
   console.log("STUDIO COMPLETE",window.failures,"failures");Qt.quit();stop();
  }
  window.step++;
 }}
 Timer {interval:10000;running:true;onTriggered:Qt.exit(2)}
}
