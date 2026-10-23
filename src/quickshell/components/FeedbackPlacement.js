.pragma library

function finite(value, fallback) { return typeof value === "number" && isFinite(value) ? value : fallback; }
function clamp(value, low, high) { return Math.max(low,Math.min(high,value)); }
function step(value, delta) { return clamp(finite(value,.5)+finite(delta,0),0,1); }
function notificationWidth(value) { return clamp(finite(value,390),240,520); }
function preset(name) {
    const positions = {"top-left":[0,0],"top":[.5,0],"top-center":[.5,0],"top-right":[1,0],
        "left":[0,.5],"center":[.5,.5],"right":[1,.5],
        "bottom-left":[0,1],"bottom":[.5,1],"bottom-center":[.5,1],"bottom-right":[1,1]};
    const p=positions[name] || positions["bottom"];
    return {x:p[0],y:p[1]};
}
function place(outputWidth, outputHeight, width, height, clearance, x, y) {
    const ow=Math.max(1,finite(outputWidth,1920)),oh=Math.max(1,finite(outputHeight,1080));
    const c=clearance || {};
    // On exceptionally small outputs reserve at least half the output for content.
    const left=clamp(finite(c.left,0),0,(ow-1)/4),right=clamp(finite(c.right,0),0,(ow-1)/4);
    const top=clamp(finite(c.top,0),0,(oh-1)/4),bottom=clamp(finite(c.bottom,0),0,(oh-1)/4);
    const w=clamp(finite(width,330),1,ow-left-right),h=clamp(finite(height,74),1,oh-top-bottom);
    const travelX=Math.max(0,ow-left-right-w),travelY=Math.max(0,oh-top-bottom-h);
    return {x:left+clamp(finite(x,.5),0,1)*travelX,y:top+clamp(finite(y,.5),0,1)*travelY,
        width:w,height:h,left:left,top:top,travelX:travelX,travelY:travelY,outputWidth:ow,outputHeight:oh};
}
function normalized(x,y,rect) {
    return {x:rect.travelX>0 ? clamp((x-rect.left)/rect.travelX,0,1) : .5,
        y:rect.travelY>0 ? clamp((y-rect.top)/rect.travelY,0,1) : .5};
}
