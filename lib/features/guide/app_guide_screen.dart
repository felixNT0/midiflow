import 'package:flutter/material.dart';

/// In-app guide that explains how each screen works and how the entire app works.
class AppGuideScreen extends StatelessWidget {
  const AppGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('App Guide')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _GuideSection(
            title: 'How MIDIFlow Works',
            icon: Icons.info_outline,
            content: '''
MIDIFlow is a remote MIDI controller app that lets you control music software
(FL Studio, Logic Pro, Kontakt, etc.) from your phone or tablet.

## Basic Workflow:
1. **Desktop**: Open MIDIFlow on your computer (Mac/Windows/Linux)
2. **Connect**: Pair your phone via Wi-Fi or Bluetooth
3. **Control**: Use the Play screen to control your music software
4. **Setup**: Configure FL Studio/Kontakt to receive MIDI from MIDIFlow

## Connection Methods:
- **Wi-Fi Bridge**: Phone connects to computer via TCP (port 8765)
- **Bluetooth LE**: Phone connects via BLE MIDI (no Wi-Fi needed)
- **USB MIDI**: Direct connection via USB cable

## What You Can Control:
- Layer volumes and on/off toggles (for Kontakt instruments)
- Continuous pads (assignable CC controls)
- Pad volume (master volume for pads)
- Drum pads (momentary triggers)
- Performance knobs (continuous CC controls)
- XY pad (2D control surface)
- Transport controls (play, stop, record)
- Mixer controls (channel volumes, pans)
- Effects controls (send levels, returns)
''',
          ),
          const SizedBox(height: 16),
          _GuideSection(
            title: 'Play Screen',
            icon: Icons.play_circle_outline,
            content: '''
The Play screen is your main control surface for live performance.

## Bank Tabs (Top):
- **Instrument**: Layer volumes, pads, pad volume
- **Transport**: Play, pause, stop, record buttons
- **Mixer**: Channel volumes and pans (FL Studio channels 9-16)
- **Channel Rack**: Channel rack controls (FL Studio channels 1-8)
- **Drums**: Drum pad triggers
- **Effects**: Send levels and returns
- **Performance**: Performance knobs and XY pad

## Layer Volumes Section:
- **8 vertical faders** for Kontakt instrument layers
- **On/off toggles** below each fader
- **Long-press** to rename layers
- Sends CC20-27 (volumes) and CC28-35 (toggles)

## Continuous Pads Section:
- **12 assignable pads** (CC36-47)
- Tap to trigger assigned parameters
- Each pad can be assigned to any Kontakt control

## Pad Volume Section:
- **Horizontal fader** for master pad volume
- Sends CC48
- Drag left-right to adjust

## Channel Selector:
- **Dropdown** to select which FL Studio channel/part to control
- Affects all controls on the current bank

## Connection Status:
- **Green dot** = Connected
- **Red dot** = Disconnected
- Tap to reconnect if needed
''',
          ),
          const SizedBox(height: 16),
          _GuideSection(
            title: 'Settings Screen',
            icon: Icons.settings,
            content: '''
The Settings screen contains all configuration options.

## Appearance:
- **Theme mode**: System, Light, or Dark
- Automatically adapts to your device settings

## Connection:
- **Desktop Bridge**: Wi-Fi bridge server (desktop only)
- **Connect to computer**: Wi-Fi client connection (mobile)
- **BLE Bridge**: Bluetooth LE bridge (desktop only)

## MIDI Activity Monitor:
- **Real-time MIDI messages** showing what's being sent/received
- Color-coded by message type (notes, CC, program change, etc.)
- Helps debug connection issues

## Sequence Recorder:
- **Record control movements** for playback
- Save sequences for quick recall
- Useful for complex performance routines

## Assign Controls:
- **Edit MIDI mappings** for each control
- Change channel, controller number, min/max values
- Send test CC messages
- Kontakt Learn guidance

## Profiles:
- **Save/load control layouts** for different songs/venues
- Quick switching between setups
- Profiles persist across app restarts

## Control Labels:
- **Rename controls** for better organization
- Labels persist across sessions

## Setup Guides:
- **FL Studio setup**: Step-by-step instructions
- **Logic Pro setup**: Alternative DAW configuration
- **Kontakt setup**: Learn assignments for instruments
''',
          ),
          const SizedBox(height: 16),
          _GuideSection(
            title: 'Assign Screen',
            icon: Icons.tune,
            content: '''
The Assign screen lets you customize MIDI mappings for each control.

## Control Picker:
- **Dropdown** to select which control to edit
- Shows all controls in the current bank

## Control Editor:
- **Label**: Rename the control
- **Channel**: MIDI channel (1-16)
- **CC Controller**: Controller number (0-127)
- **Min/Max Value**: Value range for the control
- **Inverted**: Reverse the control direction

## XY Pad (if applicable):
- **X axis**: Separate CC mapping
- **Y axis**: Separate CC mapping

## Test CC:
- **Send test message** to verify the mapping works
- Useful for Kontakt Learn setup

## Kontakt Learn:
- Step-by-step instructions for assigning controls
- Shows current mapping details
- Warns if no device is connected

## Bank Management:
- **Add bank**: Create new control pages
- **Rename bank**: Long-press bank name
- **Delete bank**: Remove unused banks
- **Templates**: Start from mixer, transport, or instrument layouts
''',
          ),
          const SizedBox(height: 16),
          _GuideSection(
            title: 'Profiles Screen',
            icon: Icons.folder_copy_outlined,
            content: '''
The Profiles screen manages saved control layouts.

## Save Profile:
- **Save current layout** with a custom name
- Captures all control positions and mappings
- Useful for different songs or venues

## Load Profile:
- **Tap a profile** to load it
- Restores all control positions and mappings
- Quick switching between setups

## Delete Profile:
- **Long-press** or tap delete icon
- Remove profiles you no longer need

## Profile Info:
- Shows bank count and control count
- Creation date
- Active profile indicator

## Use Cases:
- **Song 1**: Worship set 1 configuration
- **Song 2**: Worship set 2 configuration
- **Practice**: Practice session layout
- **Venue A**: Church sanctuary setup
- **Venue B**: Different church setup
''',
          ),
          const SizedBox(height: 16),
          _GuideSection(
            title: 'Desktop Bridge (Wi-Fi)',
            icon: Icons.cable,
            content: '''
The Desktop Bridge allows phone/tablet to connect to your computer via Wi-Fi.

## Setup:
1. **Open MIDIFlow on desktop** → Settings → Desktop Bridge
2. **Note the IP address and token** shown on screen
3. **Keep the app open** — bridge runs in background
4. **On phone**: Settings → Connect to computer
5. **Enter IP, port (8765), and token**
6. **Tap Connect**

## Connection Status:
- **Green**: Bridge running and clients connected
- **Red**: Bridge stopped or error

## Pairing:
- **Token**: Secure pairing code (shown on desktop)
- **IP Address**: Computer's local network address
- **Port**: 8765 (default)

## Troubleshooting:
- **Can't connect**: Check both devices on same Wi-Fi
- **IP changed**: Church Wi-Fi may assign different IP
- **Firewall**: Allow MIDIFlow through firewall
- **Restart**: Restart app if connection fails

## DAW Setup:
- **FL Studio**: Install device_midiflow.py script
- **Logic Pro**: Enable "MIDIFlow Bridge" as MIDI input
- **Kontakt**: Set plugin MIDI input port to 10
''',
          ),
          const SizedBox(height: 16),
          _GuideSection(
            title: 'BLE Bridge (Bluetooth)',
            icon: Icons.bluetooth,
            content: '''
The BLE Bridge allows phone/tablet to connect via Bluetooth LE.

## Setup:
1. **Open MIDIFlow on desktop** → Settings → Desktop Bridge
2. **Click "Start BLE bridge"**
3. **Enable Bluetooth** on phone
4. **Scan for "MIDIFlow Bridge"**
5. **Connect via Bluetooth**

## Advantages:
- **No Wi-Fi required** — just Bluetooth
- **Lower latency** — direct Bluetooth connection
- **More reliable** — no network issues

## Limitations:
- **Range**: ~10 meters (30 feet)
- **Compatibility**: Requires BLE MIDI support
- **Setup**: More complex than Wi-Fi

## Troubleshooting:
- **Not found**: Check Bluetooth is enabled on both devices
- **Connection fails**: Try restarting Bluetooth
- **Interference**: Move closer to computer

## When to Use:
- **No Wi-Fi available** — Bluetooth only
- **Network issues** — Wi-Fi problems
- **Lower latency needed** — Bluetooth is faster
- **Backup connection** — Alternative to Wi-Fi
''',
          ),
          const SizedBox(height: 16),
          _GuideSection(
            title: 'Sequence Recorder',
            icon: Icons.fiber_manual_record,
            content: '''
The Sequence Recorder captures control movements for playback.

## Recording:
1. **Go to Settings** → Sequence Recorder
2. **Tap "Record"** — moves are captured automatically
3. **Move controls** — faders, knobs, buttons, XY pad
4. **Tap "Stop"** — sequence is saved

## Playback:
1. **Select sequence** from dropdown
2. **Tap to play** — movements replay with timing
3. **Tap "Stop"** — halt playback

## What Gets Recorded:
- **Fader movements** — layer volumes, channel volumes, pad volume
- **Knob turns** — performance knobs, effects parameters
- **Button toggles** — layer on/off, pads, transport
- **XY pad positions** — both X and Y axes

## Use Cases:
- **Complex routines** — Multi-step control sequences
- **Live performance** — Trigger sequences during songs
- **Practice** — Rehearse control movements
- **Automation** — Repeat complex setups

## Tips:
- **Keep it simple** — Short sequences work best
- **Test first** — Verify playback before live use
- **Name clearly** — Use descriptive sequence names
''',
          ),
          const SizedBox(height: 16),
          _GuideSection(
            title: 'Troubleshooting',
            icon: Icons.help_outline,
            content: '''
Common issues and solutions:

## Can't Connect:
- **Check Wi-Fi**: Both devices on same network
- **Check IP**: Verify IP address is correct
- **Restart app**: Force close and reopen
- **Check firewall**: Allow MIDIFlow through firewall

## Controls Don't Work:
- **Check FL Studio**: Controller type = "MIDIFlow"
- **Check Kontakt**: Plugin MIDI input port = 10
- **Check connection**: Verify "Connected" status
- **Re-learn**: Redo Kontakt Learn assignments

## MIDI Activity Empty:
- **Check connection**: Verify device is connected
- **Move controls**: Activity only shows when controls move
- **Check bridge**: Ensure bridge is running

## App Crashes:
- **Restart app**: Force close and reopen
- **Check battery**: Low battery can cause issues
- **Update app**: Install latest version
- **Clear cache**: Reinstall if needed

## BLE Not Working:
- **Check Bluetooth**: Enabled on both devices
- **Restart Bluetooth**: Toggle Bluetooth off/on
- **Move closer**: Reduce distance to computer
- **Check compatibility**: Device must support BLE MIDI
''',
          ),
        ],
      ),
    );
  }
}

class _GuideSection extends StatelessWidget {
  const _GuideSection({
    required this.title,
    required this.icon,
    required this.content,
  });

  final String title;
  final IconData icon;
  final String content;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        leading: Icon(icon),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SelectableText(
              content,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
