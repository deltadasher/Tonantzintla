.pragma library

// Original, deterministic vector illustrations. Each path uses a 1000-unit artboard.
function approvedAccent(id) {
    const colors = { "ruby": "#D11E40", "seashell": "#EE927F", "fire": "#C44F28", "wabi-sabi": "#E9B872", "sun": "#EAC64B", "leaf": "#467B50", "ice-cube": "#83DAD9", "water-droplet": "#438FCA", "ringed-planet": "#9874CD", "night-sky": "#493961", "snowflake": "#FFFFFF", "moon": "#C8CDD3", "cloud": "#515861", "ink": "#000000" };
    return colors[id] || colors["wabi-sabi"];
}
function background(id, light) {
    const lightColors = { ruby: "#F5EBED", seashell: "#FAEEE7", fire: "#F6EDE5", "wabi-sabi": "#F4EFE5", sun: "#F6F0DB", leaf: "#EAF0E7", "ice-cube": "#E9F4F3", "water-droplet": "#E9F0F6", "ringed-planet": "#F0ECF6", "night-sky": "#EDEAF2", snowflake: "#E7EEF2", moon: "#EEF0F2", cloud: "#E9ECEF", ink: "#F0EEE9" };
    const darkColors = { ruby: "#25151D", seashell: "#211F29", fire: "#231A18", "wabi-sabi": "#16191C", sun: "#22251E", leaf: "#0E1B15", "ice-cube": "#142A32", "water-droplet": "#132533", "ringed-planet": "#211C32", "night-sky": "#1C1929", snowflake: "#202B38", moon: "#1D2430", cloud: "#202A33", ink: "#272727" };
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
// All visible geometry, including stroke extents, stays within 80..920.
// The consumer fits the complete square; none of these scenes relies on clipping.
function markPlacement(id) {
    const marks = {
        ruby: [355,355,310], seashell: [332,361,310], fire: [345,326,310],
        "wabi-sabi": [190,180,620], sun: [395,225,210], leaf: [438,226,300],
        "ice-cube": [355,320,290], "water-droplet": [389,275,220],
        "ringed-planet": [190,190,620], "night-sky": [538,215,220],
        snowflake: [530,225,215], moon: [418,213,245], cloud: [290,222,420],
        ink: [392,445,215]
    };
    const m = marks[id] || marks["wabi-sabi"];
    return {x:m[0], y:m[1], size:m[2]};
}
function paint(c, id, accent, bg, fg, light) {
    const a = color(accent), paper = color(bg);
    const pale = mix(a,paper,.84), mid = mix(a,paper,.57), deep = mix(a,paper,.28);
    const line = mix(a,fg,.22);
    c.lineCap = "round"; c.lineJoin = "round";
    function path(commands, fill, stroke, width) {
        c.beginPath();
        for (let j=0;j<commands.length;j++) {
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
    function poly(points,fill,stroke,width) {
        const p=points.map(function(v,i){return [i?"L":"M",v[0],v[1]];});
        p.push(["Z"]);path(p,fill,stroke,width);
    }
    function ellipse(x,y,rx,ry,fill,stroke,width) {
        const k=.5522847498;
        path([["M",x+rx,y],["C",x+rx,y+k*ry,x+k*rx,y+ry,x,y+ry],
              ["C",x-k*rx,y+ry,x-rx,y+k*ry,x-rx,y],
              ["C",x-rx,y-k*ry,x-k*rx,y-ry,x,y-ry],
              ["C",x+k*rx,y-ry,x+rx,y-k*ry,x+rx,y],["Z"]],fill,stroke,width);
    }
    function stroke(commands,col,width) {path(commands,null,col,width||2);}
    if (id === "ruby") {
        // A single cut gemstone. Every facet shares its edges with its neighbour.
        // No pedestal or pasted silhouette: the crown and pavilion define the ruby.
        const bright=mix(a,fg,.26), shade=mix(a,paper,.34);
        poly([[350,320],[650,320],[765,450],[500,775],[235,450]],a);
        poly([[350,320],[650,320],[602,392],[398,392]],bright);
        poly([[350,320],[398,392],[235,450]],mid);
        poly([[650,320],[765,450],[602,392]],shade);
        poly([[235,450],[398,392],[390,450]],bright);
        poly([[398,392],[602,392],[610,450],[390,450]],mix(a,fg,.10));
        poly([[602,392],[765,450],[610,450]],a);
        poly([[235,450],[390,450],[500,775]],shade);
        poly([[390,450],[610,450],[500,775]],a);
        poly([[610,450],[765,450],[500,775]],mix(a,paper,.55));
    } else if (id === "seashell") {
        // A complete scallop fan. All ribs converge at the hinge; the scalloped
        // rim and the ribs describe the same surface rather than an added badge.
        path([["M",440,659],["C",399,628,348,585,309,529],
              ["C",282,491,270,454,284,430],["C",292,410,316,409,328,422],
              ["C",311,386,330,356,355,363],["C",366,367,375,380,378,390],
              ["C",368,338,397,312,421,328],["C",436,338,442,358,445,374],
              ["C",438,315,463,292,485,311],["C",495,322,498,342,500,360],
              ["C",502,342,505,322,515,311],["C",537,290,562,315,555,374],
              ["C",558,358,564,338,579,328],["C",603,312,632,338,622,390],
              ["C",625,380,634,367,645,363],["C",670,356,689,386,672,422],
              ["C",684,409,708,410,716,430],["C",730,454,718,491,691,529],
              ["C",652,585,601,628,560,659],["L",570,684],
              ["Q",500,715,430,684],["Z"]],a);
        const ribs=[[304,450,354,557,461,645],[349,392,385,541,476,650],
                    [408,351,435,505,489,652],[474,335,480,494,497,653],
                    [526,335,520,494,503,653],[592,351,565,505,511,652],
                    [651,392,615,541,524,650],[696,450,646,557,539,645]];
        for(let i=0;i<ribs.length;i++) {
            const r=ribs[i];stroke([["M",r[0],r[1]],["Q",r[2],r[3],r[4],r[5]]],mix(a,paper,.47),4);
        }
        path([["M",440,659],["Q",500,678,560,659],["L",570,684],
              ["Q",500,715,430,684],["Z"]],deep);
    } else if (id === "fire") {
        // The approved flame is the only flame. Its base touches real firewood.
        ellipse(500,715,275,66,pale);
        poly([[343,595],[367,568],[660,645],[647,671]],deep);
        poly([[344,649],[357,674],[661,600],[650,573]],line);
        stroke([["M",377,594],["L",606,650]],mid,2);
        stroke([["M",396,645],["L",619,590]],mid,2);
        // Flat, slightly irregular stones make a complete ring beneath the logs.
        const stones=[[288,685,34,19],[340,719,42,20],[422,742,43,21],
                      [518,750,44,21],[613,739,42,20],[695,711,37,20],[722,671,28,18]];
        for(let i=0;i<stones.length;i++) {
            const s=stones[i];ellipse(s[0],s[1],s[2],s[3],mid);
        }
    } else if (id === "sun") {
        const sunlight=light?mix(a,fg,.28):a;
        ellipse(500,330,62,62,sunlight);
        for(let i=0;i<8;i++) {
            const angle=i*Math.PI/4;
            stroke([["M",500+80*Math.cos(angle),330+80*Math.sin(angle)],
                    ["L",500+105*Math.cos(angle),330+105*Math.sin(angle)]],sunlight,9);
        }
        // Two overlapping hills share one closed ground silhouette. Broad slopes
        // establish a landscape without decorative contour or speed lines.
        path([["M",188,690],["C",254,659,299,493,405,476],
              ["C",508,459,571,597,663,620],["Q",765,642,812,690],
              ["C",729,762,634,785,500,785],["C",366,785,271,762,188,690],["Z"]],pale);
        path([["M",188,690],["C",300,706,354,670,426,617],
              ["C",567,511,683,534,812,690],["C",729,762,634,785,500,785],
              ["C",366,785,271,762,188,690],["Z"]],mid);
    } else if (id === "leaf") {
        // A complete botanical sprig, intentionally without the standalone leaf emblem.
        ellipse(500,800,207,24,pale);
        // Tapered foliage grows from one continuous stem; every vein meets a branch.
        stroke([["M",500,695],["C",488,606,460,524,485,465]],deep,5);
        path([["M",485,465],["C",470,407,496,346,584,317],
              ["C",605,393,559,457,485,465],["Z"]],deep);
        stroke([["M",485,465],["Q",541,411,569,343]],mid,2);
        path([["M",479,584],["C",398,582,354,536,345,477],
              ["C",423,483,475,523,479,584],["Z"]],mid);
        stroke([["M",477,582],["Q",423,542,369,501]],deep,2);
        path([["M",493,641],["C",559,636,612,589,625,539],
              ["C",548,542,499,577,493,641],["Z"]],pale);
        stroke([["M",497,638],["Q",545,597,598,559]],mid,2);
        // A low unglazed pot grounds the plant, separate from its organic silhouette.
        path([["M",397,689],["L",420,782],["Q",500,812,580,782],
              ["L",603,689],["Z"]],mid);
        path([["M",500,707],["L",500,798],["Q",550,797,580,782],
              ["L",603,689],["Z"]],pale);
        ellipse(500,687,108,24,deep);
        ellipse(500,683,108,20,mid);
        stroke([["M",402,686],["Q",500,719,598,686]],line,2);
    } else if (id === "ice-cube") {
        // One rounded isometric ice cube: three faces meet at (500,500), with
        // one shared vertical edge and aligned bevels. No shelf, chips or platform.
        const iceTop=mix(a,fg,.23), iceLeft=mix(a,paper,.23), iceRight=mix(a,paper,.48);
        path([["M",486,252],["Q",500,244,514,252],["L",727,375],
              ["Q",741,383,741,399],["L",741,644],["Q",741,660,727,668],
              ["L",514,791],["Q",500,799,486,791],["L",273,668],
              ["Q",259,660,259,644],["L",259,399],["Q",259,383,273,375],["Z"]],iceLeft);
        path([["M",486,252],["Q",500,244,514,252],["L",727,375],
              ["Q",741,383,727,391],["L",500,522],["L",273,391],
              ["Q",259,383,273,375],["Z"]],iceTop);
        path([["M",500,522],["L",741,383],["L",741,644],["Q",741,660,727,668],
              ["L",514,791],["Q",500,799,500,783],["Z"]],iceRight);
        // Narrow internal bevels show thickness and stay attached to their faces.
        path([["M",283,410],["L",480,524],["L",480,760],["L",460,748],
              ["L",460,537],["L",283,435],["Z"]],mix(iceLeft,fg,.16));
        path([["M",521,534],["L",718,420],["L",718,638],["L",700,649],
              ["L",700,453],["L",521,556],["Z"]],mix(iceRight,a,.28));
    } else if (id === "water-droplet") {
        // A falling drop above one quiet pool; three ripples communicate the landing.
        ellipse(500,679,300,102,pale);
        ellipse(500,669,226,65,null,mid,2);
        ellipse(500,658,142,35,null,deep,2);
        ellipse(500,653,61,13,null,mid,2);
        // Reeds are rooted at the rear right edge, well clear of the drop.
        stroke([["M",737,653],["Q",727,538,751,463]],deep,3);
        stroke([["M",757,657],["Q",783,570,781,529]],mid,3);
        path([["M",736,578],["Q",679,553,688,495],["Q",734,509,736,578],["Z"]],mid);
        path([["M",764,602],["Q",807,578,813,537],["Q",772,548,764,602],["Z"]],deep);
    } else if (id === "ringed-planet") {
        // The original planet already contains its orbital band. No extra orbit,
        // satellites or marks compete with that single complete subject.
    } else if (id === "night-sky") {
        const nightMoon=light?a:mix(a,fg,.57);
        path([["M",695,239],["C",629,210,548,253,548,323],
              ["C",548,397,626,438,695,405],["C",640,403,603,370,603,323],
              ["C",603,280,641,245,695,239],["Z"]],nightMoon);
        const ridgeFace=light?mid:mix(a,fg,.28);
        const ridgeShade=light?deep:mix(a,fg,.10);
        const snowcap=light?pale:mix(a,fg,.52);
        // Asymmetric alpine ridges, with broken shadow faces rather than the
        // perfect vertical centre seams that made the earlier mountains pyramids.
        path([["M",205,750],["L",302,603],["L",345,570],["L",399,450],
              ["L",450,534],["L",474,548],["L",582,738],
              ["Q",397,799,205,750],["Z"]],ridgeFace);
        poly([[399,450],[442,565],[426,625],[502,763],[582,738],
              [474,548],[450,534]],ridgeShade);
        poly([[359,540],[399,450],[450,534],[423,516],[409,543],[387,520]],snowcap);
        path([["M",455,757],["L",560,648],["L",594,600],["L",641,528],
              ["L",692,597],["L",713,606],["L",801,741],
              ["Q",654,796,455,757],["Z"]],ridgeFace);
        poly([[641,528],[658,610],[626,655],[701,768],[801,741],[713,606],[692,597]],ridgeShade);
        poly([[603,586],[641,528],[686,590],[659,575],[638,596],[624,576]],snowcap);
    } else if (id === "snowflake") {
        // One six-branched crystal uses the scene palette in both display modes.
        const frost=light?mix(fg,paper,.20):color("#FFFFFF");
        for(let i=0;i<6;i++) {
            const angle=-Math.PI/2+i*Math.PI/3;
            const dx=Math.cos(angle),dy=Math.sin(angle),px=-dy,py=dx;
            stroke([["M",640,330],["L",640+dx*93,330+dy*93]],frost,5);
            stroke([["M",640+dx*67+px*18,330+dy*67+py*18],
                    ["L",640+dx*50,330+dy*50],
                    ["L",640+dx*67-px*18,330+dy*67-py*18]],frost,5);
        }
        // One falling snow crystal, two separated firs, and a closed snowbank.
        const snowGround=light?mix(fg,paper,.90):pale;
        const snowFace=light?mix(fg,paper,.68):mid;
        const snowShade=light?mix(fg,paper,.48):deep;
        ellipse(500,754,306,63,snowGround);
        function fir(x,y,s) {
            poly([[x,y],[x-74*s,y+115*s],[x-45*s,y+109*s],
                  [x-101*s,y+195*s],[x-62*s,y+188*s],[x-124*s,y+271*s],
                  [x+124*s,y+271*s],[x+62*s,y+188*s],[x+101*s,y+195*s],
                  [x+45*s,y+109*s],[x+74*s,y+115*s]],snowFace);
            poly([[x,y],[x,y+271*s],[x+124*s,y+271*s],
                  [x+62*s,y+188*s],[x+101*s,y+195*s],[x+45*s,y+109*s],
                  [x+74*s,y+115*s]],snowShade);
            stroke([["M",x,y+272*s],["L",x,y+307*s]],snowShade,5*s);
        }
        fir(388,402,1);fir(667,536,.65);
        path([["M",247,768],["Q",345,724,458,758],["Q",617,718,754,761],
              ["C",669,814,359,823,247,768],["Z"]],snowFace);
    } else if (id === "moon") {
        const moonlight=light?mix(a,fg,.45):a;
        path([["M",602,240],["C",527,205,450,258,450,330],
              ["C",450,407,527,455,602,420],["C",548,416,513,379,513,330],
              ["C",513,281,548,244,602,240],["Z"]],moonlight);
        const lakeFill=light?mix(fg,paper,.88):pale;
        const reflection=light?mix(fg,paper,.66):mid;
        const reflectionBright=light?mix(fg,paper,.48):deep;
        // A quiet irregular shoreline. Moonlight is a handful of broken water
        // bands with uneven ends, not a ladder or an outline around a plate.
        path([["M",200,665],["C",245,619,360,645,419,613],
              ["C",485,575,580,611,665,624],["C",732,637,789,613,813,658],
              ["C",841,705,734,751,629,755],["C",516,803,388,774,294,744],
              ["C",231,728,174,705,200,665],["Z"]],lakeFill);
        path([["M",489,634],["Q",532,625,575,634],["L",562,641],["L",501,640],["Z"]],reflection);
        path([["M",464,665],["Q",503,658,528,664],["L",518,671],["Q",487,675,464,665],["Z"]],reflectionBright);
        path([["M",548,666],["Q",578,663,598,670],["L",580,677],["L",548,674],["Z"]],reflection);
        path([["M",440,705],["Q",483,693,532,702],["L",519,710],["Q",477,706,440,705],["Z"]],reflection);
        path([["M",552,713],["L",606,706],["L",627,713],["L",609,719],["Z"]],reflectionBright);
    } else if (id === "cloud") {
        // One connected cumulus mass, built from overlapping rounded volumes.
        // Its shaded underside follows its own silhouette: no pasted weather
        // glyph, detached speed lines, rain marks or unrelated puddle.
        const cloudBody=light?mix(a,paper,.27):mix(fg,paper,.20);
        const cloudShade=light?mix(a,paper,.10):mix(fg,paper,.42);
        const cloudLight=light?mix(a,paper,.44):mix(fg,paper,.08);
        path([["M",260,640],["C",198,640,179,602,195,558],
              ["C",207,524,231,508,266,508],["C",258,459,294,418,340,422],
              ["C",348,337,417,285,486,303],["C",545,316,575,357,580,396],
              ["C",632,359,708,378,731,427],["C",748,447,756,472,754,496],
              ["C",810,491,853,529,849,573],["C",846,624,797,651,738,653],
              ["C",603,664,412,666,260,640],["Z"]],cloudBody);
        path([["M",207,599],["C",273,639,340,592,399,610],
              ["C",460,631,501,592,554,601],["C",611,618,626,558,681,575],
              ["C",744,596,785,548,849,573],["C",846,624,797,651,738,653],
              ["C",603,664,412,666,260,640],["Q",221,633,207,599],["Z"]],cloudShade);
        path([["M",352,420],["C",365,349,420,309,477,323],
              ["C",516,333,543,361,552,392],["C",513,366,469,372,439,402],
              ["C",418,424,379,432,352,420],["Z"]],cloudLight);
    } else if (id === "ink") {
        // A single impact splatter: connected irregular lobes and directional
        // tendrils. The few satellite drops continue those same impact directions.
        const ink=light?color("#171717"):mix(fg,paper,.12);
        path([["M",360,380],["C",350,350,365,326,394,338],
              ["C",426,353,419,315,432,286],["Q",443,260,452,303],
              ["L",447,350],["Q",449,379,478,361],["C",489,341,496,295,512,273],
              ["Q",528,246,527,278],["L",519,343],["Q",519,369,541,354],
              ["L",583,325],["Q",604,310,592,335],["L",569,373],
              ["C",550,400,592,404,617,387],["L",680,355],["Q",716,338,698,370],
              ["L",653,406],["C",628,428,649,448,675,436],["L",740,418],
              ["Q",765,412,747,429],["L",692,461],["C",671,477,684,499,706,500],
              ["L",755,501],["Q",790,509,751,521],["L",700,537],
              ["C",670,549,702,584,721,599],["Q",743,619,719,615],["L",675,600],
              ["C",643,583,644,615,651,640],["L",666,700],["Q",667,724,653,708],
              ["L",615,656],["C",591,622,571,645,575,679],["L",582,742],
              ["Q",580,771,566,748],["L",540,698],["C",526,670,509,683,500,711],
              ["L",476,759],["Q",462,779,465,756],["L",478,699],
              ["C",487,669,453,662,435,679],["L",398,717],["Q",375,736,390,711],
              ["L",419,664],["C",437,633,407,618,386,638],["L",343,662],
              ["Q",319,677,333,657],["L",377,607],["C",397,588,366,568,344,581],
              ["L",290,605],["Q",269,615,281,596],["L",321,561],
              ["C",346,540,317,518,293,524],["L",235,539],["Q",210,543,232,529],
              ["L",291,499],["C",313,484,291,462,266,465],["L",223,470],
              ["Q",198,470,222,460],["L",282,441],["C",309,431,303,409,281,398],
              ["L",236,374],["Q",221,364,239,367],["L",311,385],
              ["C",343,396,354,406,360,380],["Z"]],ink);
        ellipse(522,220,8,13,ink);ellipse(738,327,12,8,ink);
        ellipse(806,512,11,7,ink);ellipse(680,749,7,12,ink);
        ellipse(455,814,6,10,ink);ellipse(204,554,10,6,ink);
    } else {
        // The original Wabi-sabi mark is the complete subject; add no ornament.
    }
}
