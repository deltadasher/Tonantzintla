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
        "ringed-planet": [265,245,470], "night-sky": [538,215,220],
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
    function star(x,y,r,col) {
        path([["M",x-r,y],["Q",x,y,x,y-r],["Q",x,y,x+r,y],
              ["Q",x,y,x,y+r],["Q",x,y,x-r,y],["Z"]],col);
    }
    // A solid sky aperture supports immutable pale/dark marks in the opposite
    // mode. It sits behind the entire vignette, never conceals a cut edge.
    if (["sun", "snowflake", "moon", "night-sky", "cloud"].indexOf(id) !== -1 && contrast(a,paper) < 2.7) {
        const target = luminance(a) > .40 ? color("#30414A") : color("#CCD2C8");
        let sky = paper;
        for (let n=1;n<=20;n++) {
            sky=mix(paper,target,n/20);
            if(contrast(a,sky)>=3.1) break;
        }
        // Moon's lake is shallower than the other landscape bases: keep the
        // lower sky edge behind it instead of leaving a stray crescent below.
        ellipse(500,480,323,id === "moon" ? 283 : 303,sky);
    }

    if (id === "ruby") {
        // One cut specimen rests on a continuous, three-faced mineral plinth.
        ellipse(500,748,285,34,pale);
        poly([[242,647],[397,576],[649,585],[775,652],[603,716],[385,707]],pale);
        poly([[242,647],[385,707],[603,716],[603,765],[385,752],[255,697]],mid);
        poly([[603,716],[775,652],[763,701],[603,765]],deep);
        stroke([["M",258,649],["L",390,698],["L",598,706],["L",758,652]],line,2);
        ellipse(506,601,100,13,mid);
        // Two small crystals share the same face directions and sit on the slab.
        poly([[656,559],[680,526],[714,551],[709,610],[680,623],[652,602]],mid);
        poly([[680,526],[680,623],[709,610],[714,551]],deep);
        stroke([["M",656,559],["L",680,573],["L",714,551]],pale,2);
        poly([[307,631],[326,599],[352,616],[348,653],[327,662],[305,649]],mid);
        stroke([["M",326,601],["L",327,660]],deep,2);
    } else if (id === "seashell") {
        // A complete tidal sandbank; the shell meets the upper bank at its foot.
        path([["M",208,635],["C",241,578,347,563,454,587],
              ["C",581,611,652,545,741,592],["C",821,634,805,716,727,747],
              ["C",627,790,450,776,343,753],["C",246,731,178,691,208,635],["Z"]],pale);
        path([["M",236,693],["C",355,666,433,711,543,669],
              ["C",650,627,710,620,777,644],["C",809,691,771,729,727,747],
              ["C",627,790,450,776,343,753],["Q",275,736,236,693],["Z"]],mid);
        stroke([["M",263,673],["C",366,655,425,692,538,650],
                ["C",642,610,699,610,750,623]],deep,2);
        stroke([["M",317,718],["C",400,741,492,744,560,719]],pale,2);
        stroke([["M",593,706],["Q",675,667,739,678]],pale,2);
        ellipse(325,630,13,5,deep); ellipse(691,614,9,4,mid);
        ellipse(627,742,5,3,deep);
    } else if (id === "fire") {
        // The approved flame is the only flame. Its base touches real firewood.
        ellipse(500,715,275,66,pale);
        ellipse(500,690,211,42,mid);
        poly([[343,595],[367,568],[660,645],[647,671]],deep);
        poly([[344,649],[357,674],[661,600],[650,573]],line);
        stroke([["M",377,594],["L",606,650]],mid,2);
        stroke([["M",396,645],["L",619,590]],mid,2);
        // Flat, slightly irregular stones make a complete ring beneath the logs.
        const stones=[[288,685,34,19],[340,719,42,20],[422,742,43,21],
                      [518,750,44,21],[613,739,42,20],[695,711,37,20],[722,671,28,18]];
        for(let i=0;i<stones.length;i++) {
            const s=stones[i];ellipse(s[0],s[1],s[2],s[3],i%2?pale:mid);
            stroke([["M",s[0]-s[2]*.55,s[1]-4],["Q",s[0],s[1]-12,s[0]+s[2]*.55,s[1]-5]],deep,1.5);
        }
        stroke([["M",478,233],["Q",461,210,478,185]],mid,2);
        stroke([["M",542,242],["Q",556,219,543,201]],mid,2);
    } else if (id === "sun") {
        // Low rolling fields end in a single rounded landform, with no canvas edge.
        path([["M",200,669],["C",277,612,304,453,433,484],
              ["C",521,506,535,598,616,558],["C",705,509,753,581,801,654],
              ["C",849,734,695,790,517,794],["C",346,800,167,743,200,669],["Z"]],pale);
        path([["M",206,685],["C",334,604,396,575,515,635],
              ["C",634,696,729,605,798,650],["C",850,729,699,789,517,794],
              ["C",345,800,191,745,206,685],["Z"]],mid);
        path([["M",293,744],["C",418,657,554,743,706,708],
              ["Q",756,697,792,687],["C",765,750,648,789,517,794],
              ["Q",383,798,293,744],["Z"]],deep);
        stroke([["M",269,690],["C",354,640,419,626,486,650]],pale,2);
        stroke([["M",397,751],["C",485,716,570,761,680,730]],pale,2);
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
        // A single cube sits on a low floating ice shelf, with explicit top/side faces.
        ellipse(500,741,300,48,pale);
        stroke([["M",238,749],["Q",500,823,771,747]],mid,2);
        poly([[244,635],[364,570],[609,557],[758,622],[659,691],[402,712]],pale);
        poly([[244,635],[402,712],[659,691],[659,734],[405,754],[264,687]],mid);
        poly([[659,691],[758,622],[743,675],[659,734]],deep);
        stroke([["M",266,636],["L",408,698],["L",647,680],["L",736,624]],line,2);
        stroke([["M",644,580],["L",587,613],["L",617,641]],mid,2);
        ellipse(500,585,93,14,mid);
        // A smaller grounded shard repeats the shelf's perspective, not the cube.
        poly([[655,626],[685,600],[716,616],[691,640]],mid);
        poly([[655,626],[691,640],[691,659],[659,646]],deep);
        poly([[691,640],[716,616],[714,638],[691,659]],pale);
    } else if (id === "water-droplet") {
        // A falling drop above one quiet pool; three ripples communicate the landing.
        ellipse(500,679,300,102,pale);
        ellipse(500,669,226,65,null,mid,2);
        ellipse(500,658,142,35,null,deep,2);
        ellipse(500,653,61,13,null,mid,2);
        stroke([["M",500,523],["L",500,554]],mid,2);
        // Reeds are rooted at the rear right edge, well clear of the drop.
        stroke([["M",737,653],["Q",727,538,751,463]],deep,3);
        stroke([["M",757,657],["Q",783,570,781,529]],mid,3);
        path([["M",736,578],["Q",679,553,688,495],["Q",734,509,736,578],["Z"]],mid);
        path([["M",764,602],["Q",807,578,813,537],["Q",772,548,764,602],["Z"]],deep);
        stroke([["M",334,747],["Q",460,783,584,760]],mid,2);
    } else if (id === "ringed-planet") {
        // The mark supplies the planet and its only rings. One open satellite track
        // establishes scale without surrounding it in more ring-shaped decoration.
        stroke([["M",215,529],["C",205,683,424,783,653,702],
                ["Q",760,664,801,578]],mid,2);
        ellipse(733,660,30,30,deep);
        path([["M",733,630],["C",754,638,758,668,740,689],
              ["C",766,683,771,647,746,633],["Z"]],mid);
        ellipse(258,300,17,17,mid);
        star(708,268,6,mid);
    } else if (id === "night-sky") {
        // A complete alpine silhouette beneath the original moon-and-star mark.
        ellipse(500,754,315,43,pale);
        poly([[219,730],[399,450],[582,738]],mid);
        poly([[399,450],[399,740],[582,738]],deep);
        poly([[353,522],[399,450],[448,526],[410,510],[388,531]],pale);
        poly([[455,748],[641,528],[798,735]],mid);
        poly([[641,528],[641,754],[798,735]],deep);
        poly([[603,573],[641,528],[674,572],[648,562],[633,583]],pale);
        path([["M",206,742],["Q",338,725,458,759],["Q",622,722,805,740],
              ["C",759,798,304,820,206,742],["Z"]],pale);
        star(300,347,7,deep);star(405,265,4,mid);star(467,379,4,mid);
    } else if (id === "snowflake") {
        // One falling snow crystal, two separated firs, and a closed snowbank.
        ellipse(500,754,306,63,pale);
        function fir(x,y,s) {
            poly([[x,y],[x-74*s,y+115*s],[x-45*s,y+109*s],
                  [x-101*s,y+195*s],[x-62*s,y+188*s],[x-124*s,y+271*s],
                  [x+124*s,y+271*s],[x+62*s,y+188*s],[x+101*s,y+195*s],
                  [x+45*s,y+109*s],[x+74*s,y+115*s]],mid);
            poly([[x,y],[x,y+271*s],[x+124*s,y+271*s],
                  [x+62*s,y+188*s],[x+101*s,y+195*s],[x+45*s,y+109*s],
                  [x+74*s,y+115*s]],deep);
            stroke([["M",x,y+272*s],["L",x,y+307*s]],deep,5*s);
            stroke([["M",x-67*s,y+117*s],["Q",x,y+139*s,x+67*s,y+117*s]],pale,3);
            stroke([["M",x-91*s,y+196*s],["Q",x,y+221*s,x+91*s,y+196*s]],pale,3);
        }
        fir(388,402,1);fir(667,536,.65);
        path([["M",247,768],["Q",345,724,458,758],["Q",617,718,754,761],
              ["C",669,814,359,823,247,768],["Z"]],mid);
        stroke([["M",290,767],["Q",381,741,453,770]],pale,2);
        ellipse(283,376,3,3,mid);ellipse(490,530,3,3,mid);ellipse(740,479,3,3,mid);
    } else if (id === "moon") {
        // Moonlight on a small lake: bounded shore, horizontal reflections, no
        // invented second moon or unrelated foreground crater landscape.
        ellipse(500,676,306,103,pale);
        path([["M",216,651],["C",280,624,307,575,339,578],
              ["Q",387,589,409,643],["Q",303,670,216,651],["Z"]],mid);
        path([["M",659,649],["Q",684,590,711,606],["Q",738,615,774,655],
              ["Q",718,666,659,649],["Z"]],mid);
        stroke([["M",475,616],["L",543,616]],deep,3);
        stroke([["M",455,640],["L",570,640]],mid,3);
        stroke([["M",471,666],["L",557,666]],deep,3);
        stroke([["M",423,698],["L",590,698]],mid,3);
        stroke([["M",443,731],["L",569,731]],deep,3);
        stroke([["M",310,748],["Q",500,807,699,746]],mid,2);
        star(307,340,5,mid);star(738,419,4,mid);
    } else if (id === "cloud") {
        // The approved cloud carries a short rain shower into a complete puddle.
        ellipse(500,734,255,57,pale);
        ellipse(500,727,170,29,null,mid,2);
        const rain=[[352,535],[442,554],[538,534],[630,545],[386,621],[486,640],[585,617]];
        for(let i=0;i<rain.length;i++) {
            stroke([["M",rain[i][0],rain[i][1]],["L",rain[i][0]-14,rain[i][1]+35]],i%2?mid:deep,3);
        }
        stroke([["M",212,466],["C",254,466,262,443,297,444]],mid,2);
        stroke([["M",716,418],["C",745,420,766,406,790,406]],mid,2);
        ellipse(379,713,33,7,null,mid,2);ellipse(606,739,27,6,null,mid,2);
    } else if (id === "ink") {
        // An ink bottle makes the original drop-and-nib the label's sole subject.
        // The natural pale paper label keeps the approved black visible in both modes.
        const glass=light?mid:mix(fg,paper,.74);
        const edge=light?deep:mix(fg,paper,.46);
        const label=light?paper:color("#D8D8D0");
        ellipse(500,790,231,29,pale);
        path([["M",433,387],["L",433,425],["C",433,444,361,452,361,495],
              ["L",361,735],["Q",361,778,404,778],["L",596,778],
              ["Q",639,778,639,735],["L",639,495],["C",639,452,567,444,567,425],
              ["L",567,387],["Z"]],glass,edge,2);
        path([["M",388,512],["L",612,512],["L",612,700],["Q",500,724,388,700],["Z"]],label);
        // The mark extends above the label; raise its backing to encompass the tip.
        path([["M",388,465],["Q",500,447,612,465],["L",612,535],["L",388,535],["Z"]],label);
        path([["M",424,341],["Q",500,327,576,341],["L",576,390],
              ["Q",500,408,424,390],["Z"]],edge);
        ellipse(500,341,76,15,glass,edge,2);
        stroke([["M",385,494],["L",385,715]],pale,3);
        stroke([["M",449,357],["L",449,382]],glass,2);
        stroke([["M",471,360],["L",471,386]],glass,2);
        stroke([["M",493,361],["L",493,388]],glass,2);
        stroke([["M",515,361],["L",515,388]],glass,2);
        stroke([["M",537,360],["L",537,386]],glass,2);
        stroke([["M",559,357],["L",559,382]],glass,2);
    } else {
        // The existing Wabi-sabi mark is the whole black-hole silhouette.
        // Two separated inward streamlines suggest accretion without adding rings.
        stroke([["M",182,605],["C",243,610,292,584,333,557]],mid,3);
        stroke([["M",204,629],["C",250,630,287,616,313,602]],pale,2);
        stroke([["M",678,349],["C",730,322,779,316,818,329]],mid,3);
        stroke([["M",702,323],["C",743,304,777,300,800,303]],pale,2);
    }
}
