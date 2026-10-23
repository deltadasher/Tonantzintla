from gi.repository import Gio, GLib
from pathlib import Path
import os,signal
props={
 'org.mpris.MediaPlayer2':{'CanQuit':GLib.Variant('b',False),'CanRaise':GLib.Variant('b',False),'HasTrackList':GLib.Variant('b',False),'Identity':GLib.Variant('s','Preview fixture'),'DesktopEntry':GLib.Variant('s','fixture'),'SupportedUriSchemes':GLib.Variant('as',['file']),'SupportedMimeTypes':GLib.Variant('as',['audio/flac'])},
 'org.mpris.MediaPlayer2.Player':{'PlaybackStatus':GLib.Variant('s','Playing'),'LoopStatus':GLib.Variant('s','None'),'Rate':GLib.Variant('d',1.0),'Shuffle':GLib.Variant('b',False),'Metadata':GLib.Variant('a{sv}',{'mpris:trackid':GLib.Variant('o','/fixture/track'),'mpris:length':GLib.Variant('x',240000000),'xesam:title':GLib.Variant('s','Orbital light'),'xesam:album':GLib.Variant('s','Observatory sessions'),'xesam:artist':GLib.Variant('as',['Native preview']),'xesam:url':GLib.Variant('s',(Path(__file__).parent/'fixture.flac').as_uri())}),'Volume':GLib.Variant('d',.5),'Position':GLib.Variant('x',60000000),'MinimumRate':GLib.Variant('d',1.0),'MaximumRate':GLib.Variant('d',1.0),'CanGoNext':GLib.Variant('b',True),'CanGoPrevious':GLib.Variant('b',True),'CanPlay':GLib.Variant('b',True),'CanPause':GLib.Variant('b',True),'CanSeek':GLib.Variant('b',True),'CanControl':GLib.Variant('b',True)}}
xml='<node>'+''.join('<interface name="'+iface+'">'+''.join('<property name="'+name+'" type="'+v.get_type_string()+'" access="read"/>' for name,v in values.items())+'</interface>' for iface,values in props.items())+'</node>'
info=Gio.DBusNodeInfo.new_for_xml(xml);loop=GLib.MainLoop()
def acquired(bus,name):
 for iface in info.interfaces:
  bus.register_object('/org/mpris/MediaPlayer2',iface,None,lambda c,s,p,i,k:props[i][k],None)
Gio.bus_own_name(Gio.BusType.SESSION,'org.mpris.MediaPlayer2.tonantzintla_fixture',Gio.BusNameOwnerFlags.NONE,acquired,None,None)
signal.signal(signal.SIGTERM,lambda *_:loop.quit());loop.run()
