# name=MIDIFlow
# version 2026.1
# supportedDevices=MIDIFlow Bridge
# MIDIFlow remote surface for FL Studio.
#
# Channel map (MIDI channel -> action):
#   1-8   : CC7/CC10 -> Channel Rack volume/pan for channels 1-8.
#           All other CCs -> forwarded to plugin MIDI port 10
#           (set the instrument plugin's MIDI input port to 10 so
#           Kontakt / VSTs receive them as real MIDI input).
#   9-16  : CC7/CC10 -> Mixer track volume/pan for tracks 1-8.
#   16    : CC14 -> Master volume, CC30/31/32 -> Play-Pause/Stop/Record.

import channels
import device
import mixer
import transport

CC_PLAY = 30
CC_STOP = 31
CC_RECORD = 32
CC_MASTER_VOL = 14

# Plugin MIDI input port that instrument CCs are forwarded to. Set the
# target plugin's "MIDI input port" (plugin wrapper detailed settings)
# to this value so it receives them as channel MIDI.
PLUGIN_MIDI_PORT = 10


def _forward_to_plugin(event):
    try:
        msg = (
            event.status
            + (event.data1 << 8)
            + (event.data2 << 16)
            + (PLUGIN_MIDI_PORT << 24)
        )
        device.forwardMIDICC(msg, 2)
    except Exception:
        pass


def OnInit():
    pass


def OnControlChange(event):
    channel = event.status & 0x0F
    cc = event.data1
    value = event.data2

    if channel == 15:
        if cc == CC_PLAY:
            event.handled = True
            if value > 0:
                try:
                    if transport.isPlaying():
                        transport.stop()
                    else:
                        transport.start()
                except Exception:
                    pass
            return
        if cc == CC_STOP:
            event.handled = True
            if value > 0:
                try:
                    transport.stop()
                except Exception:
                    pass
            return
        if cc == CC_RECORD:
            event.handled = True
            if value > 0:
                try:
                    transport.record()
                except Exception:
                    pass
            return
        if cc == CC_MASTER_VOL:
            try:
                mixer.setTrackVolume(0, value / 127.0)
            except Exception:
                pass
            event.handled = True
            return

    if channel <= 7:
        if cc == 7 or cc == 10:
            try:
                if cc == 7:
                    channels.setChannelVolume(channel, value / 127.0)
                else:
                    pan = (value / 127.0) * 2.0 - 1.0
                    channels.setChannelPan(channel, pan)
            except Exception:
                pass
            event.handled = True
        else:
            # Instrument performance CCs (layer faders, knobs, buttons):
            # forward into the plugin's MIDI input so VSTs like Kontakt
            # receive them for their own MIDI Learn / Quick Controls.
            _forward_to_plugin(event)
            event.handled = True
        return

    track = channel - 7
    if 1 <= track <= 8:
        if cc == 7:
            try:
                mixer.setTrackVolume(track, value / 127.0)
            except Exception:
                pass
            event.handled = True
            return
        if cc == 10:
            try:
                pan = (value / 127.0) * 2.0 - 1.0
                mixer.setTrackPan(track, pan)
            except Exception:
                pass
            event.handled = True
            return
