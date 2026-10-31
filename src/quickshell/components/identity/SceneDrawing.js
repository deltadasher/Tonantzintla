.pragma library

// Original, deterministic vector illustrations. Each path uses a 1000-unit artboard.
function approvedAccent(id) {
    const colors = { "ruby": "#D11E40", "seashell": "#EE927F", "fire": "#C44F28", "wabi-sabi": "#E9B872", "sun": "#EAC64B", "leaf": "#467B50", "ice-cube": "#83DAD9", "water-droplet": "#438FCA", "ringed-planet": "#9874CD", "night-sky": "#493961", "snowflake": "#FFFFFF", "moon": "#C8CDD3", "cloud": "#515861", "ink": "#000000" };
    return colors[id] || colors["wabi-sabi"];
}
function background(id, light) {
    const lightColors = { ruby: "#F5EBED", seashell: "#FAEEE7", fire: "#F6EDE5", "wabi-sabi": "#F4EFE5", sun: "#F6F0DB", leaf: "#EAF0E7", "ice-cube": "#E9F4F3", "water-droplet": "#E9F0F6", "ringed-planet": "#F0ECF6", "night-sky": "#EDEAF2", snowflake: "#E7EEF2", moon: "#EEF0F2", cloud: "#E9ECEF", ink: "#F0EEE9" };
    const darkColors = { ruby: "#25151D", seashell: "#211F29", fire: "#231A18", "wabi-sabi": "#16191C", sun: "#22251E", leaf: "#14251E", "ice-cube": "#142A32", "water-droplet": "#132533", "ringed-planet": "#211C32", "night-sky": "#1C1929", snowflake: "#202B38", moon: "#1D2430", cloud: "#202A33", ink: "#272727" };
    return (light ? lightColors : darkColors)[id] || (light ? "#F4EFE5" : "#16191C");
}
function color(c) { return typeof c === "string" ? Qt.color(c) : c; }
function mix(a, b, weight) {
    a = color(a); b = color(b);
    return Qt.rgba(a.r * (1-weight) + b.r * weight, a.g * (1-weight) + b.g * weight, a.b * (1-weight) + b.b * weight, 1);
}
function luminance(c) {
    c = color(c);
    function channel(v) { return v <= .04045 ? v / 12.92 : Math.pow((v + .055) / 1.055, 2.4); }
    return .2126 * channel(c.r) + .7152 * channel(c.g) + .0722 * channel(c.b);
}
function contrast(a,b) { const x = luminance(a), y = luminance(b); return (Math.max(x,y)+.05)/(Math.min(x,y)+.05); }
function readableAccent(a, bg, fg) {
    for (let i = 0; i <= 20; i++) { const candidate = mix(a, fg, i/20); if (contrast(candidate,bg) >= 4.5) return candidate; }
    return fg;
}
function markPlacement(id) {
    const marks = {
        ruby: [436,345,205], seashell: [370,515,195], fire: [445,382,175],
        "wabi-sabi": [350,315,295], sun: [435,250,180], leaf: [520,300,150],
        "ice-cube": [495,375,185], "water-droplet": [460,320,170],
        "ringed-planet": [345,310,310], "night-sky": [525,280,160],
        snowflake: [440,285,195], moon: [400,240,220], cloud: [355,310,285], ink: [455,430,180]
    };
    const m = marks[id] || marks["wabi-sabi"];
    return {x:m[0], y:m[1], size:m[2]};
}
function paint(c, id, accent, bg, fg, light) {
    const a = color(accent), paper = color(bg);
    const pale = mix(a,paper,.84), mid = mix(a,paper,.56), deep = mix(a,paper,.25);
    const line = mix(a,fg,.30);
    c.lineCap = "round"; c.lineJoin = "round";
    function path(commands, fill, stroke, width) {
        c.beginPath();
        for(let j=0;j<commands.length;j++) {
            const p=commands[j];
            if(p[0]==="M") c.moveTo(p[1],p[2]);
            else if(p[0]==="L") c.lineTo(p[1],p[2]);
            else if(p[0]==="C") c.bezierCurveTo(p[1],p[2],p[3],p[4],p[5],p[6]);
            else if(p[0]==="Q") c.quadraticCurveTo(p[1],p[2],p[3],p[4]);
            else if(p[0]==="Z") c.closePath();
        }
        if(fill) {c.fillStyle=fill;c.fill();}
        if(stroke) {c.strokeStyle=stroke;c.lineWidth=width||2;c.stroke();}
    }
    function poly(points,fill,stroke,width) { const p=points.map(function(v,i){return [i?"L":"M",v[0],v[1]];});p.push(["Z"]);path(p,fill,stroke,width); }
    function ellipse(x,y,rx,ry,fill,stroke,width,rotation) {
        c.save();c.translate(x,y);c.rotate(rotation||0);c.scale(1,ry/rx);c.beginPath();c.arc(0,0,rx,0,Math.PI*2);
        if(fill){c.fillStyle=fill;c.fill();}if(stroke){c.strokeStyle=stroke;c.lineWidth=(width||2)*rx/ry;c.stroke();}c.restore();
    }
    function stroke(points,col,w) {path(points,null,col,w);}
    function star(x,y,r,col) {path([["M",x-r,y],["Q",x,y,x,y-r],["Q",x,y,x+r,y],["Q",x,y,x,y+r],["Q",x,y,x-r,y],["Z"]],col);}
    function strata(start,end,y,col) {
        stroke([["M",start,y],["C",start+120,y-45,end-160,y+45,end,y-10]],col,2);
    }
    function branch(x,y,scale,angle,winter) {
        c.save();c.translate(x,y);c.rotate(angle);c.scale(scale,scale);
        stroke([["M",0,0],["C",-10,-85,10,-180,0,-320]],deep,7);
        for(let i=0;i<5;i++) {
            const by=-65-i*47, side=i%2===0?1:-1;
            stroke([["M",0,by],["Q",side*35,by-22,side*75,by-63]],deep,3);
            if(!winter) {
                path([["M",side*15,by-15],["Q",side*95,by-17,side*90,by-86],["Q",side*30,by-86,side*15,by-15],["Z"]],i%2?mid:deep);
                stroke([["M",side*19,by-22],["Q",side*51,by-48,side*77,by-72]],pale,1.5);
            } else {
                stroke([["M",side*47,by-42],["L",side*51,by-73]],mid,2);
                stroke([["M",side*59,by-50],["L",side*89,by-50]],mid,2);
                ellipse(side*77,by-65,5,5,fg);
            }
        }
        c.restore();
    }

    if(id === "ruby") {
        // Interlocking mineral faces, with the approved ruby set above its seam.
        poly([[175,725],[325,555],[400,580],[488,460],[665,535],[808,465],[970,670],[1050,860],[260,880]],pale);
        poly([[280,745],[438,535],[580,610],[535,805]],mid);
        poly([[438,535],[493,710],[580,610]],deep);
        poly([[493,710],[535,805],[580,610],[725,710]],mix(a,paper,.42));
        poly([[580,610],[675,510],[725,710]],pale,line,1);
        poly([[725,710],[805,550],[920,735],[865,850]],mid);
        poly([[805,550],[820,750],[920,735]],deep);
        poly([[300,780],[375,750],[385,835],[315,850]],deep);
        stroke([["M",211,866],["L",435,841],["L",551,872],["L",764,845],["L",947,874]],line,2);
        star(375,350,13,mid); star(735,377,8,deep);
    } else if(id === "seashell") {
        // A scalloped shoreline in long tidal bands, shell resting on the sandbank.
        path([["M",80,760],["C",245,720,250,550,480,592],["C",730,638,720,385,1010,410],["L",1010,1000],["L",80,1000],["Z"]],pale);
        path([["M",220,875],["C",420,700,530,855,650,690],["C",780,510,850,560,1020,490],["L",1020,1000],["L",220,1000],["Z"]],mid);
        for(let i=0;i<4;i++) stroke([["M",180+i*35,750+i*54],["C",400,675+i*55,440,765+i*57,615,635+i*46],["C",790,500+i*55,845,500+i*65,1030,455+i*60]],i===0?deep:mix(a,paper,.74),i===0?3:2);
        for(let i=0;i<13;i++) ellipse(355+(i*67)%410,730+(i*39)%130,2+i%3,2+i%2,deep);
        ellipse(710,430,25,9,pale,null,0,-.35); ellipse(315,770,16,6,deep,null,0,.2);
    } else if(id === "fire") {
        // Broad masonry hearth and stacked firewood, rising flame-shaped negative spaces.
        path([["M",265,800],["L",265,455],["Q",270,240,535,230],["Q",800,240,805,455],["L",805,800],["Z"]],pale);
        path([["M",340,800],["L",340,465],["Q",340,315,535,306],["Q",730,315,730,465],["L",730,800],["Z"]],mid);
        path([["M",405,730],["C",345,625,475,575,470,505],["C",540,560,515,597,540,615],["C",565,560,620,540,625,490],["C",727,630,690,740,610,755],["Z"]],pale);
        poly([[335,760],[365,726],[690,803],[660,838]],deep);
        poly([[382,828],[365,790],[683,709],[700,748]],line);
        c.fillStyle=deep;c.fillRect(250,840,570,27);c.fillStyle=pale;c.fillRect(210,867,650,18);
        for(let i=0;i<8;i++) {const x=390+(i*67)%300,y=220+(i*53)%220;poly([[x,y-8],[x+3,y],[x,y+7],[x-3,y]],i%2?mid:deep);}
    } else if(id === "sun") {
        // Radiating solar light above overlapping terraced hills.
        for(let i=0;i<13;i++) {const t=Math.PI+(i/12)*Math.PI;stroke([["M",525+145*Math.cos(t),340+145*Math.sin(t)],["L",525+170*Math.cos(t),340+170*Math.sin(t)]],mid,2);}
        path([["M",110,740],["Q",350,350,585,605],["Q",800,380,1040,535],["L",1040,1000],["L",110,1000],["Z"]],pale);
        path([["M",180,880],["C",370,650,460,780,640,635],["C",800,520,880,645,1040,570],["L",1040,1000],["L",180,1000],["Z"]],mid);
        path([["M",330,1010],["Q",500,795,730,820],["Q",900,825,1030,710],["L",1030,1010],["Z"]],deep);
        for(let i=0;i<3;i++) stroke([["M",200+i*40,790+i*47],["Q",365,590+i*82,570,700+i*61],["Q",780,760+i*30,970,620+i*65]],mix(a,paper,.70),2);
    } else if(id === "leaf") {
        // A diagonal garden branch, seed pods, and a low patch of earth.
        ellipse(650,867,330,32,pale);
        branch(710,880,1.8,-.34,false);branch(570,875,1.03,.73,false);
        branch(805,890,.9,.25,false);
        stroke([["M",300,890],["Q",535,840,905,893]],mid,2);
        ellipse(400,830,13,6,deep,null,0,-.3);ellipse(350,868,8,4,mid);
    } else if(id === "ice-cube") {
        // Tall glacial prisms set into a fractured shelf.
        poly([[180,825],[310,735],[440,780],[630,694],[850,748],[1020,690],[1020,1000],[180,1000]],pale);
        const shards=[[305,780,95,275],[710,790,100,330],[840,815,74,220],[445,840,92,195]];
        for(let i=0;i<shards.length;i++) {const s=shards[i],x=s[0],y=s[1],w=s[2],h=s[3];poly([[x,y],[x-w/2,y-h+45],[x+w*.25,y-h],[x+w,y-h+40],[x+w*1.1,y-25]],i%2?mid:deep);poly([[x+w*.25,y-h],[x+w*.3,y-5],[x+w*1.1,y-25],[x+w,y-h+40]],pale);stroke([["M",x+w*.25,y-h+8],["L",x+w*.3,y-25]],a,2);}
        stroke([["M",210,880],["L",410,850],["L",525,900],["L",720,850],["L",955,875]],deep,2);
        stroke([["M",525,900],["L",570,990]],mid,2);
        star(745,350,9,pale);star(365,420,7,mid);
    } else if(id === "water-droplet") {
        // Concentric water reflections and asymmetric reeds define a small pool.
        for(let i=5;i>=0;i--) ellipse(550,665,80+i*60,18+i*23,i===5?pale:null,i%2?mid:deep,1.4);
        ellipse(550,665,45,9,mid);
        stroke([["M",825,790],["Q",775,545,835,370]],mid,3);
        stroke([["M",845,790],["Q",902,580,883,510]],deep,3);
        path([["M",820,508],["Q",746,450,785,375],["Q",833,421,820,508],["Z"]],mid);
        path([["M",861,630],["Q",935,542,930,474],["Q",864,504,861,630],["Z"]],deep);
        ellipse(285,760,22,5,mid,null,0,-.2);ellipse(715,820,30,6,pale,null,0,.1);
    } else if(id === "ringed-planet") {
        // Sweeping orbital paths are deliberately off-axis; planet mark is the body.
        ellipse(505,470,365,132,null,mid,1.5,-.48);
        ellipse(505,470,460,195,null,pale,1.2,-.48);
        ellipse(505,470,270,85,null,deep,1.4,-.48);
        ellipse(814,302,22,22,deep);ellipse(190,663,11,11,mid);
        ellipse(777,754,50,50,pale);ellipse(763,739,12,9,mid);
        star(310,238,8,deep);star(850,560,9,mid);star(455,770,6,deep);
    } else if(id === "night-sky") {
        // Linked constellations above a low jagged horizon, no circular logo pedestal.
        const stars=[[270,390],[345,320],[420,410],[440,530],[590,580],[740,455],[820,540]];
        stroke(stars.map(function(p,i){return [i?"L":"M",p[0],p[1]];}),mid,2);
        stroke([["M",345,320],["L",380,220],["L",470,185]],pale,2);
        for(let i=0;i<stars.length;i++) star(stars[i][0],stars[i][1],i%3===0?9:5,deep);
        for(let i=0;i<30;i++) ellipse(210+(i*137)%690,135+(i*97)%560,1.5+i%2,1.5+i%2,mid);
        poly([[100,960],[350,750],[430,815],[600,680],[780,835],[900,720],[1060,850],[1060,1050]],pale);
        poly([[330,1000],[600,800],[680,850],[900,740],[1030,865],[1030,1030]],mid);
    } else if(id === "snowflake") {
        // Frosted branches form an open canopy around the snowflake.
        branch(780,940,1.75,-.48,true);branch(450,930,1.28,.55,true);
        path([["M",170,960],["Q",390,865,620,930],["Q",850,880,1050,915],["L",1050,1040],["L",170,1040],["Z"]],pale);
        for(let i=0;i<27;i++) {const x=200+(i*113)%720,y=160+(i*89)%640;ellipse(x,y,1.5+i%3,1.5+i%3,i%3?mid:fg);}
    } else if(id === "moon") {
        // Lunar mare and cratered foreground under the original lunar mark.
        path([["M",120,840],["Q",310,585,560,645],["Q",800,680,1020,520],["L",1020,1040],["L",120,1040],["Z"]],pale);
        path([["M",260,1040],["Q",410,760,625,825],["Q",830,900,1040,715],["L",1040,1040],["Z"]],mid);
        ellipse(550,735,82,22,null,deep,2,-.12);ellipse(550,739,58,13,mid,null,0,-.12);
        ellipse(805,870,110,31,null,pale,2,-.15);ellipse(805,874,85,19,deep,null,0,-.15);
        ellipse(367,844,30,8,deep);ellipse(862,676,34,9,mid);
        star(300,320,6,mid);star(740,230,8,deep);star(790,470,5,mid);
    } else if(id === "cloud") {
        // Three overlapping weather fronts, scalloped tops and long rain strokes.
        path([["M",140,710],["Q",160,615,260,635],["C",250,545,390,510,435,605],["C",480,540,580,570,590,640],["Q",740,600,790,715],["Z"]],pale);
        path([["M",400,795],["C",390,710,480,675,535,710],["C",535,605,690,585,735,690],["C",810,615,930,685,920,738],["Q",1020,700,1060,795],["Z"]],mid);
        for(let i=0;i<8;i++) stroke([["M",365+i*72,825+(i%2)*22],["L",352+i*72,855+(i%2)*22]],mid,2);
        stroke([["M",245,520],["C",300,510,320,485,360,485]],pale,2);
        stroke([["M",740,475],["C",820,490,850,455,895,460]],mid,2);
    } else if(id === "ink") {
        // Sumi-like broad calligraphic strokes; light support keeps the black mark intact in dark mode.
        const ink = light ? mix(a,paper,.10) : mix(fg,paper,.38);
        path([["M",850,230],["C",500,170,330,380,480,530],["C",650,680,865,600,780,775],["C",735,865,545,855,410,795],["C",560,955,850,925,900,772],["C",960,570,645,540,575,450],["C",480,335,675,240,850,230],["Z"]],pale);
        path([["M",780,238],["C",570,220,365,395,500,540],["C",650,690,845,620,798,778],["C",870,665,774,607,660,567],["C",435,486,515,320,780,238],["Z"]],ink);
        for(let i=0;i<6;i++) stroke([["M",790+i*5,243+i*5],["C",560,255+i*6,448,393,520+i*4,499]],mid,1);
        for(let i=0;i<11;i++) ellipse(360+(i*91)%530,250+(i*97)%620,2+i%5,2+i%4,i%3?mid:ink);
    } else {
        // Quiet original accretion sketch; Wabi's original icon remains the hero.
        ellipse(500,470,340,100,null,pale,10,-.24);
        ellipse(500,470,390,120,null,mid,2,-.24);
        ellipse(500,470,310,82,null,deep,2,-.24);
        path([["M",170,545],["C",340,540,510,610,815,393]],null,mid,4);
        for(let i=0;i<16;i++) ellipse(180+(i*157)%690,190+(i*113)%610,1+i%2,1+i%2,mid);
    }
    // Only opposite-mode combinations with weak mark contrast need local support.
    // A feathered field preserves the exact SVG colors without adding a badge.
    if (contrast(a, paper) < 3) {
        const m = markPlacement(id), cx = m.x + m.size / 2, cy = m.y + m.size / 2;
        const supportTarget = luminance(a) > .40 ? Qt.color("#202B38") : Qt.color("#F3F1ED");
        let support = paper;
        for (let k = 1; k <= 20; k++) {
            support = mix(paper, supportTarget, k / 20);
            if (contrast(a, support) >= 3.2) break;
        }
        const haze = c.createRadialGradient(cx, cy, m.size * .28, cx, cy, m.size * .70);
        haze.addColorStop(0, support);
        haze.addColorStop(.15, support);
        haze.addColorStop(1, Qt.rgba(support.r, support.g, support.b, 0));
        c.beginPath();
        c.arc(cx, cy, m.size * .70, 0, Math.PI * 2);
        c.fillStyle = haze;
        c.fill();
    }

}
