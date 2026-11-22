// Tonantzintla KDE Plasma 6 layout: Serpantinum-refined floating top Aperture bar + centered bottom dock.
var topBar = new Panel();
topBar.location = 'top';
topBar.height = 38;
topBar.floating = true;
topBar.hiding = 'none';
topBar.alignment = 'center';
topBar.lengthMode = 'fill';

var launcher = topBar.addWidget('org.kde.plasma.kickoff');
launcher.currentConfigGroup = ['General'];
launcher.writeConfig('icon', 'tonantzintla-mark');
launcher.writeConfig('showActionButtonCaptions', false);

topBar.addWidget('org.tonantzintla.workspaces');
topBar.addWidget('org.tonantzintla.media');
topBar.addWidget('org.kde.plasma.panelspacer');
topBar.addWidget('org.tonantzintla.clock');
topBar.addWidget('org.kde.plasma.panelspacer');
var tray = topBar.addWidget('org.kde.plasma.systemtray');
tray.currentConfigGroup = ['General'];
tray.writeConfig('hiddenItems', 'org.kde.plasma.volume,org.kde.plasma.mediacontroller,org.kde.plasma.battery');
topBar.addWidget('org.tonantzintla.status');

var dock = new Panel();
dock.location = 'bottom';
dock.height = 54;
dock.floating = true;
dock.hiding = 'dodgewindows';
dock.alignment = 'center';
dock.lengthMode = 'fit';

var tasks = dock.addWidget('org.kde.plasma.icontasks');
tasks.currentConfigGroup = ['General'];
tasks.writeConfig('groupingStrategy', 1);
tasks.writeConfig('indicateAudioStreams', true);
tasks.writeConfig('maxStripes', 1);

var desktopsArray = desktopsForActivity(currentActivity());
for (var i = 0; i < desktopsArray.length; i++) {
    desktopsArray[i].wallpaperPlugin = 'org.kde.image';
}
