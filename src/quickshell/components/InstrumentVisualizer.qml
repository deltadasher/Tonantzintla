import QtQuick
import ".."

// No timer, analyser or subscription here. Hosts acquire the existing Spectrum
// service once and pass its values; sleeping faces do not repaint on samples.
Item {
    id: root
    property var levels: []
    property bool active: false
    property string variant: "ring"
    implicitWidth: 280
    implicitHeight: 180
    onLevelsChanged: if (active && visible) drawing.requestPaint()
    onActiveChanged: drawing.requestPaint()
    onVisibleChanged: if (visible) drawing.requestPaint()
    onVariantChanged: drawing.requestPaint()
    onWidthChanged: drawing.requestPaint()
    onHeightChanged: drawing.requestPaint()
    Connections { target: Theme; function onAccentChanged() { drawing.requestPaint(); } }
    function level(index) {
        const v=Number(levels[index] || 0);
        return isFinite(v) ? Math.max(0,Math.min(1,v)) : 0;
    }
    Canvas {
        id: drawing
        width: Math.min(root.width,384)
        height: Math.min(root.height,384)
        transform: Scale { xScale: root.width / Math.max(1,drawing.width); yScale: root.height / Math.max(1,drawing.height) }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
        const ctx=getContext("2d"); ctx.reset();
        const count=Math.min(64,root.levels.length || 28);
        ctx.strokeStyle=Theme.accent; ctx.fillStyle=Theme.accent; ctx.lineWidth=2;
        if(root.variant==="bars") {
            const step=width/count, bar=Math.max(1,step*.58);
            for(let i=0;i<count;i++) {
                const h=Math.max(2,(root.active?root.level(i):0)*height*.88);
                ctx.fillRect(i*step+(step-bar)/2,(height-h)/2,bar,h);
            }
        } else {
            const cx=width/2,cy=height/2, r=Math.min(width,height)*.32, amplitude=Math.min(width,height)*.13;
            // A closed, continuous path with interpolation avoids disconnected
            // radial bars and stays bounded by the instrument rectangle.
            ctx.beginPath();
            for(let j=0;j<=count*4;j++) {
                const f=(j%(count*4))/4, i=Math.floor(f), mix=f-i;
                const magnitude=root.active?root.level(i)*(1-mix)+root.level((i+1)%count)*mix:0;
                const a=j/(count*4)*Math.PI*2-Math.PI/2, radius=r+magnitude*amplitude;
                const x=cx+Math.cos(a)*radius,y=cy+Math.sin(a)*radius;
                if(j===0) ctx.moveTo(x,y); else ctx.lineTo(x,y);
            }
            ctx.closePath(); ctx.stroke();
            ctx.strokeStyle=Theme.line; ctx.lineWidth=1;
            ctx.beginPath(); ctx.arc(cx,cy,r*.80,0,Math.PI*2); ctx.stroke();
        }
    }
}
}
