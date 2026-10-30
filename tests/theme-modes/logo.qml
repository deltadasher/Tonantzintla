import QtQuick
import QtQuick.Window
import Quickshell
import "."
import "components"
import "modules/aperture/islands"
Window {
 id:window;width:520;height:280;visible:true;flags:Qt.Tool|Qt.WindowDoesNotAcceptFocus
 property int step:0
 property int failures:0
 function check(ok,label){if(!ok){failures++;console.error("LOGO FAIL",label);}}
 function checkMarks(item){
  let count=0;
  if(item.horizonColor!==undefined){check(String(item.horizonColor)==="#000000","black center under "+Settings.themeMode);count++;}
  for(const child of item.children || [])count+=checkMarks(child);
  return count;
 }
 Rectangle {id:scene;width:520;height:280;color:Theme.void_
  Text{x:20;y:15;text:"Exact color · "+Settings.themeMode;color:Theme.moon;font.pixelSize:20}
  WabiSabiBlackHole{id:logo;x:150;y:45;width:220;height:155}
  LauncherIsland{x:30;y:220;reveal:1}
  DockIsland{x:360;y:220;reveal:1}
 }
 Timer{interval:250;running:true;repeat:true;onTriggered:{
  if(!Settings.persistenceReady)return;
  if(window.step===0){Settings.motion=false;Settings.themeMode="light";Settings.adaptivePalette=false;Settings.spectralColors={accent:"#ffffff"};}
  else if(window.step===1){window.check(window.checkMarks(scene)>=3,"actual bar and dock marks instantiated");scene.grabToImage(r=>r.saveToFile(Quickshell.env("LOGO_CAPTURE")+"-light.png"));}
  else if(window.step===2){Settings.themeMode="dark";Settings.spectralColors={accent:"#564697"};}
  else if(window.step===3){window.check(window.checkMarks(scene)>=3,"marks preserved in dark mode");scene.grabToImage(r=>r.saveToFile(Quickshell.env("LOGO_CAPTURE")+"-dark.png"));}
  else if(window.step===4){console.log("LOGO COMPLETE",window.failures,"failures");Qt.exit(window.failures?1:0);stop();}
  window.step++;
 }}
 Timer{interval:5000;running:true;onTriggered:Qt.exit(2)}
}
