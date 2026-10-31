import QtQuick
import Quickshell
import "."
import "services"
import "components/ThemeMode.js" as ModeHelper
Window {
 id:root; width:300;height:100;visible:true;color:Theme.mantle
 property int step:0
 property int failures:0
 property int ticks:0
 function check(value,message) { if(!value) { failures++;console.error("MODE FAIL",message); } }
 WallpaperPalettePreview { id:preview; source:Quickshell.env("MODE_IMAGE"); active:false }
 Timer {interval:50;running:true;repeat:true;onTriggered:{
  root.ticks++;
  if(root.step===0) {
   root.check(!Theme.isLight && String(Theme.moon)==="#eee9dc","auto defaults preserve dark tokens");
   AdaptivePalette.setSeed("#010101");root.step++;root.ticks=0;
  } else if(root.step===1 && !AdaptivePalette.busy) {
   root.check(Settings.paletteSeedColor==="#010101" && Theme.adaptive && Theme.isLight,"dark seed commits contrasting light theme");
   root.check(String(Theme.accent)==="#010101","chosen dark theme color remains exact without an override");
   AdaptivePalette.setSeed("#ffffff");
   root.check(Theme.isLight,"new seed mode waits for successful generation");root.step++;root.ticks=0;
  } else if(root.step===2 && !AdaptivePalette.busy) {
   root.check(Settings.paletteSeedColor==="#ffffff" && !Theme.isLight && Theme.adaptive,"bright seed commits contrasting dark theme");
   root.check(String(Theme.accent)==="#ffffff","chosen white theme color remains exact without an override");
   root.check(Theme.mantle.r<0.5 && Theme.moon.r>0.7,"dark surfaces keep white accents visible");
   AdaptivePalette.setSeed("#badbad");root.step++;root.ticks=0;
  } else if(root.step===3 && !AdaptivePalette.busy) {
   root.check(Settings.paletteSeedColor==="#ffffff" && !Theme.isLight && AdaptivePalette.appliedSeed==="#ffffff","failed generation preserves applied selection");
   root.check(AdaptivePalette.error.length>0,"generation failure visible");
   AdaptivePalette.setSeed("#112233");root.step++;root.ticks=0;
  } else if(root.step===4 && AdaptivePalette.paletteProcess.running) {
   Settings.themeMode="light";
   root.check(Theme.isLight && !Theme.adaptive && String(Theme.moon)==="#23232e","mode changes immediately use matching fallback");
   root.step++;root.ticks=0;
  } else if(root.step===5 && root.ticks>8 && !AdaptivePalette.busy) {
   root.check(Settings.paletteSeedColor==="#ffffff" && AdaptivePalette.appliedSeed!=="#112233","late old-mode generation cannot commit its seed");
   root.check(Theme.isLight,"explicit mode overrides seed");
   Settings.themeMode="auto"; preview.active=true;preview.seed="";root.step++;root.ticks=0;
  } else if(root.step===6 && preview.status==="ready") {
   root.check(preview.mode==="dark" && preview.jobMode==="dark" && preview.previewSeed==="#ffffff","preview resolves bright seed to dark");
   preview.seed="#112233";root.step++;root.ticks=0;
  } else if(root.step===7 && preview.worker.running) {
   preview.seed="#010101";Settings.themeMode="light";root.step++;root.ticks=0;
  } else if(root.step===8 && preview.status==="ready") {
   root.check(preview.previewSeed==="#010101" && preview.jobMode==="light","canceled preview cannot replace new seed or mode");
   root.check(Settings.paletteSeedColor==="#ffffff","preview never commits seed");
   preview.active=false;Settings.themeMode="auto";
   Settings.spectralColors=({accent:"#010101"});
   root.check(Theme.isLight && String(Theme.accent)==="#010101","exact dark accent drives auto and remains exact");
   root.step=80;root.ticks=0;
  } else if(root.step===80 && root.ticks>1) {
   root.check(String(Theme.onAccent)==="#ffffff","near-black accent uses white selected text " + String(Theme.accent) + " vs " + String(Theme.onAccent) + " direct " + ModeHelper.foreground(String(Theme.accent)) + " constant " + ModeHelper.foreground("#010101"));
   Settings.spectralColors=({accent:"#ffffff"});
   root.check(!Theme.isLight && String(Theme.accent)==="#ffffff","exact bright accent drives auto and remains exact");
   root.step=81;root.ticks=0;
  } else if(root.step===81 && root.ticks>1) {
   root.check(String(Theme.onAccent)==="#000000","white accent uses black selected text");
   root.step=9;root.ticks=0;
  } else if(root.step===9 && !AdaptivePalette.busy && root.ticks>8) {
   AdaptivePalette.setSeed("#112233");root.step++;root.ticks=0;
  } else if(root.step===10 && AdaptivePalette.paletteProcess.running) {
   Settings.spectralColors=({accent:"#010101"});root.step++;root.ticks=0;
  } else if(root.step===11 && root.ticks>8 && !AdaptivePalette.busy) {
   root.check(Settings.paletteSeedColor==="#ffffff" && AdaptivePalette.appliedSeed!=="#112233","late accent-precedence job cannot commit stale seed");
   root.check(Theme.isLight,"latest exact accent retains automatic light mode");
   Settings.themeMode="dark";
   Settings.motion=true;Settings.themeMode="light";
   root.check(Theme.isLight,"mode updates before animated colors");
   root.check(Theme.mantle.r<0.5,"transition starts from previous dark surface");
   root.step++;root.ticks=0;
  } else if(root.step===12 && root.ticks>12 && !AdaptivePalette.busy) {
   root.check(String(Theme.accent)==="#010101","separate exact override still takes precedence over the chosen theme color");
   root.check(Theme.mantle.r>0.7 && Theme.moon.r<0.4,"color transition reaches light surface and dark text");
   Settings.motion=false;Settings.themeMode="dark";
   root.check(Theme.mantle.r<0.5,"reduced motion returns immediately to dark surface");
   Settings.motion=true;Settings.spectralColors=({accent:"#ffffff"});
   root.step++;root.ticks=0;
  } else if(root.step===13) {
   root.check(String(Theme.onAccent)===ModeHelper.foreground(String(Theme.accent)),"selected foreground follows displayed animated accent");
   if(root.ticks>6) {
    root.check(String(Theme.accent)==="#ffffff","animated exact accent reaches requested value");
    stop();console.log("MODE COMPLETE",root.failures,"failures");Qt.quit();
   }
  }
 }}
 Timer {interval:10000;running:true;onTriggered:{console.error("MODE FAIL timeout",root.step,AdaptivePalette.error,preview.status,preview.error);Qt.quit();}}
}
