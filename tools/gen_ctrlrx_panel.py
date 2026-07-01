#!/usr/bin/env python3
"""Generate CtrlrX .panel from mono_synth.params.yaml."""

from __future__ import annotations

import argparse
import html
import uuid
from pathlib import Path

try:
    import yaml
except ImportError as exc:  # pragma: no cover
    raise SystemExit("PyYAML required: pip install pyyaml") from exc

ROOT = Path(__file__).resolve().parents[1]


def uid() -> str:
    return uuid.uuid4().hex


def slider_modulator(name: str, cc: int, x: int, y: int, label: str, max_val: int = 127) -> str:
    mod_uid = uid()
    comp_uid = uid()
    layer_uid = uid()
    return f"""
  <modulator modulatorVstExported="0" modulatorMax="{max_val}" modulatorIsStatic="0"
             modulatorGlobalVariable="-1" modulatorMuteOnStart="0" modulatorMute="0"
             modulatorExcludeFromSnapshot="0" modulatorValueExpression="modulatorValue"
             modulatorValueExpressionReverse="midiValue" modulatorControllerExpression="value"
             modulatorLinkedToPanelProperty="-- None" modulatorLinkedToModulatorProperty="-- None"
             modulatorLinkedToModulator="-- None" modulatorLinkedToModulatorSource="1"
             modulatorLinkedToComponent="-- None" modulatorBaseValue="0"
             modulatorCustomIndex="0" modulatorCustomName="" modulatorCustomIndexGroup="0"
             modulatorCustomNameGroup="" modulatorVstNameFormat="%n"
             luaModulatorValueChange="-- None" name="{html.escape(name, quote=True)}"
             modulatorMin="0" modulatorValue="0">
    <midi midiMessageType="0" midiMessageChannelOverride="0" midiMessageChannel="1"
          midiMessageCtrlrNumber="{cc}" midiMessageCtrlrValue="0" midiMessageMultiList=""
          midiMessageSysExFormula=""/>
    <componentProperties>
      <component componentName="{html.escape(label, quote=True)}" componentVisible="1"
                 componentAlwaysOnTop="0" componentSnapSize="8" componentIsActive="1"
                 componentBackgroundColour="0x00000000" componentLabelText="{html.escape(label, quote=True)}"
                 componentLabelPlacement="2" componentLabelColour="0xffffffff"
                 componentLabelFont="&lt;Sans-Serif&gt;;12;0;0;0;0;1;0"
                 componentLabelJustification="centred" componentLabelHeight="18"
                 componentLabelWidth="96" componentLabelOffsetX="0" componentLabelOffsetY="0"
                 componentHandleMouseEvents="1" componentHandleKeyboardEvents="0"
                 componentLuaMouseDown="-- None" componentLuaMouseUp="-- None"
                 componentLuaMouseDrag="-- None" componentLuaMouseDoubleClick="-- None"
                 uiSliderStyle="RotaryVerticalDrag" uiSliderMin="0" uiSliderMax="{max_val}"
                 uiSliderInterval="1" uiSliderDoubleClickEnabled="1" uiSliderDoubleClickValue="0"
                 uiSliderValuePosition="4" uiSliderValueHeight="12" uiSliderValueWidth="48"
                 uiSliderTrackCornerSize="5" uiSliderThumbCornerSize="3" uiSliderThumbWidth="0"
                 uiSliderThumbHeight="0" uiSliderThumbFlatOnLeft="0" uiSliderThumbFlatOnRight="0"
                 uiSliderThumbFlatOnTop="0" uiSliderThumbFlatOnBottom="0"
                 uiSliderValueTextColour="0xff000000" uiSliderValueBgColour="0xffffffff"
                 uiSliderRotaryOutlineColour="0xff4488ff" uiSliderRotaryFillColour="0xff4488ff"
                 uiSliderThumbColour="0xffff8800" uiSliderValueHighlightColour="0xff4488ff"
                 uiSliderValueOutlineColour="0xffffffff" uiSliderTrackColour="0xff202020"
                 uiSliderIncDecButtonColour="0xff4488ff" uiSliderIncDecTextColour="0xffffffff"
                 uiSliderValueFont="&lt;Sans-Serif&gt;;11;0;0;0;0;1;0"
                 uiSliderValueTextJustification="centred" uiSliderVelocitySensitivity="1"
                 uiSliderVelocityThreshold="1" uiSliderVelocityOffset="0" uiSliderVelocityMode="0"
                 uiSliderVelocityModeKeyTrigger="1" uiSliderSpringMode="0" uiSliderSpringValue="0"
                 uiSliderMouseWheelInterval="1" uiSliderPopupBubble="0"
                 componentLayerUid="{layer_uid}"
                 componentRectangle="{x} {y} 72 88" uiType="uiSlider"/>
    </componentProperties>
  </modulator>"""


def cutoff14_modulator(x: int, y: int) -> str:
    """14-bit cutoff via Lua (CC74 + CC106)."""
    mod_uid = uid()
    layer_uid = uid()
    lua = (
        "function(mod, value)\\n"
        "  local v = math.floor(value * 16383 + 0.5)\\n"
        "  local msb = math.floor(v / 128)\\n"
        "  local lsb = v % 128\\n"
        "  panel:sendMidiMessageNow(CtrlrMidiMessage({0xB0, 74, msb}))\\n"
        "  panel:sendMidiMessageNow(CtrlrMidiMessage({0xB0, 106, lsb}))\\n"
        "end"
    )
    return f"""
  <modulator modulatorVstExported="0" modulatorMax="16383" modulatorIsStatic="0"
             modulatorGlobalVariable="-1" modulatorMuteOnStart="0" modulatorMute="0"
             modulatorExcludeFromSnapshot="0" modulatorValueExpression="modulatorValue"
             modulatorValueExpressionReverse="midiValue" modulatorControllerExpression="value"
             modulatorLinkedToPanelProperty="-- None" modulatorLinkedToModulatorProperty="-- None"
             modulatorLinkedToModulator="-- None" modulatorLinkedToModulatorSource="1"
             modulatorLinkedToComponent="-- None" modulatorBaseValue="8192"
             modulatorCustomIndex="0" modulatorCustomName="" modulatorCustomIndexGroup="0"
             modulatorCustomNameGroup="" modulatorVstNameFormat="%n"
             luaModulatorValueChange="{html.escape(lua, quote=True)}"
             name="filter_cutoff" modulatorMin="0" modulatorValue="8192">
    <midi midiMessageType="0" midiMessageChannelOverride="0" midiMessageChannel="1"
          midiMessageCtrlrNumber="74" midiMessageCtrlrValue="0" midiMessageMultiList=""
          midiMessageSysExFormula=""/>
    <componentProperties>
      <component componentName="Filter Cutoff" componentVisible="1"
                 componentAlwaysOnTop="0" componentSnapSize="8" componentIsActive="1"
                 componentBackgroundColour="0x00000000" componentLabelText="Filter Cutoff"
                 componentLabelPlacement="2" componentLabelColour="0xffffffff"
                 componentLabelFont="&lt;Sans-Serif&gt;;12;0;0;0;0;1;0"
                 componentLabelJustification="centred" componentLabelHeight="18"
                 componentLabelWidth="96" componentLabelOffsetX="0" componentLabelOffsetY="0"
                 componentHandleMouseEvents="1" componentHandleKeyboardEvents="0"
                 componentLuaMouseDown="-- None" componentLuaMouseUp="-- None"
                 componentLuaMouseDrag="-- None" componentLuaMouseDoubleClick="-- None"
                 uiSliderStyle="RotaryVerticalDrag" uiSliderMin="0" uiSliderMax="16383"
                 uiSliderInterval="1" uiSliderDoubleClickEnabled="1" uiSliderDoubleClickValue="8192"
                 uiSliderValuePosition="4" uiSliderValueHeight="12" uiSliderValueWidth="56"
                 uiSliderTrackCornerSize="5" uiSliderThumbCornerSize="3" uiSliderThumbWidth="0"
                 uiSliderThumbHeight="0" uiSliderThumbFlatOnLeft="0" uiSliderThumbFlatOnRight="0"
                 uiSliderThumbFlatOnTop="0" uiSliderThumbFlatOnBottom="0"
                 uiSliderValueTextColour="0xff000000" uiSliderValueBgColour="0xffffffff"
                 uiSliderRotaryOutlineColour="0xff44cc88" uiSliderRotaryFillColour="0xff44cc88"
                 uiSliderThumbColour="0xffff8800" uiSliderValueHighlightColour="0xff44cc88"
                 uiSliderValueOutlineColour="0xffffffff" uiSliderTrackColour="0xff202020"
                 uiSliderIncDecButtonColour="0xff44cc88" uiSliderIncDecTextColour="0xffffffff"
                 uiSliderValueFont="&lt;Sans-Serif&gt;;11;0;0;0;0;1;0"
                 uiSliderValueTextJustification="centred" uiSliderVelocitySensitivity="1"
                 uiSliderVelocityThreshold="1" uiSliderVelocityOffset="0" uiSliderVelocityMode="0"
                 uiSliderVelocityModeKeyTrigger="1" uiSliderSpringMode="0" uiSliderSpringValue="0"
                 uiSliderMouseWheelInterval="1" uiSliderPopupBubble="0"
                 componentLayerUid="{layer_uid}"
                 componentRectangle="{x} {y} 72 88" uiType="uiSlider"/>
    </componentProperties>
  </modulator>"""


def choice_modulator(name: str, cc: int, x: int, y: int, label: str, choices: list[str]) -> str:
    layer_uid = uid()
    return f"""
  <modulator modulatorVstExported="0" modulatorMax="{max(len(choices) - 1, 0)}"
             modulatorIsStatic="0" modulatorGlobalVariable="-1" modulatorMuteOnStart="0"
             modulatorMute="0" modulatorExcludeFromSnapshot="0"
             modulatorValueExpression="modulatorValue"
             modulatorValueExpressionReverse="midiValue"
             modulatorControllerExpression="value"
             modulatorLinkedToPanelProperty="-- None"
             modulatorLinkedToModulatorProperty="-- None"
             modulatorLinkedToModulator="-- None" modulatorLinkedToModulatorSource="1"
             modulatorLinkedToComponent="-- None" modulatorBaseValue="0"
             modulatorCustomIndex="0" modulatorCustomName="" modulatorCustomIndexGroup="0"
             modulatorCustomNameGroup="" modulatorVstNameFormat="%n"
             luaModulatorValueChange="-- None" name="{html.escape(name, quote=True)}"
             modulatorMin="0" modulatorValue="0">
    <midi midiMessageType="0" midiMessageChannelOverride="0" midiMessageChannel="1"
          midiMessageCtrlrNumber="{cc}" midiMessageCtrlrValue="0" midiMessageMultiList=""
          midiMessageSysExFormula=""/>
    <componentProperties>
      <component componentName="{html.escape(label, quote=True)}" componentVisible="1"
                 componentAlwaysOnTop="0" componentSnapSize="8" componentIsActive="1"
                 componentBackgroundColour="0x00000000" componentLabelText="{html.escape(label, quote=True)}"
                 componentLabelPlacement="2" componentLabelColour="0xffffffff"
                 componentLabelFont="&lt;Sans-Serif&gt;;12;0;0;0;0;1;0"
                 componentLabelJustification="centred" componentLabelHeight="18"
                 componentLabelWidth="96" componentLabelOffsetX="0" componentLabelOffsetY="0"
                 componentHandleMouseEvents="1" componentHandleKeyboardEvents="0"
                 componentLuaMouseDown="-- None" componentLuaMouseUp="-- None"
                 componentLuaMouseDrag="-- None" componentLuaMouseDoubleClick="-- None"
                 uiSliderStyle="LinearHorizontal" uiSliderMin="0" uiSliderMax="{max(len(choices) - 1, 0)}"
                 uiSliderInterval="1" uiSliderDoubleClickEnabled="1" uiSliderDoubleClickValue="0"
                 uiSliderValuePosition="4" uiSliderValueHeight="12" uiSliderValueWidth="72"
                 uiSliderTrackCornerSize="5" uiSliderThumbCornerSize="3" uiSliderThumbWidth="0"
                 uiSliderThumbHeight="0" uiSliderThumbFlatOnLeft="0" uiSliderThumbFlatOnRight="0"
                 uiSliderThumbFlatOnTop="0" uiSliderThumbFlatOnBottom="0"
                 uiSliderValueTextColour="0xff000000" uiSliderValueBgColour="0xffffffff"
                 uiSliderRotaryOutlineColour="0xff888888" uiSliderRotaryFillColour="0xff888888"
                 uiSliderThumbColour="0xffcccccc" uiSliderValueHighlightColour="0xff888888"
                 uiSliderValueOutlineColour="0xffffffff" uiSliderTrackColour="0xff303030"
                 uiSliderIncDecButtonColour="0xff888888" uiSliderIncDecTextColour="0xffffffff"
                 uiSliderValueFont="&lt;Sans-Serif&gt;;11;0;0;0;0;1;0"
                 uiSliderValueTextJustification="centred" uiSliderVelocitySensitivity="1"
                 uiSliderVelocityThreshold="1" uiSliderVelocityOffset="0" uiSliderVelocityMode="0"
                 uiSliderVelocityModeKeyTrigger="1" uiSliderSpringMode="0" uiSliderSpringValue="0"
                 uiSliderMouseWheelInterval="1" uiSliderPopupBubble="0"
                 componentLayerUid="{layer_uid}"
                 componentRectangle="{x} {y} 120 40" uiType="uiSlider"/>
    </componentProperties>
  </modulator>"""


def generate_panel(data: dict) -> str:
    title = data.get("title", data.get("id", "Synth"))
    mod_blocks: list[str] = []
    x, y = 16, 16
    col = 0
    for param in data["params"]:
        pid = param["id"]
        label = param["name"]
        ptype = param["type"]
        if ptype == "cc14_log":
            mod_blocks.append(cutoff14_modulator(x, y))
        elif ptype == "choice":
            mod_blocks.append(choice_modulator(pid, int(param["cc"]), x, y, label, param["choices"]))
        else:
            mod_blocks.append(slider_modulator(pid, int(param["cc"]), x, y, label))
        col += 1
        x += 88
        if col >= 6:
            col = 0
            x = 16
            y += 100

    panel_uid = uid()
    return f"""<?xml version="1.0" encoding="UTF-8"?>
<panel name="{html.escape(title, quote=True)}" panelShowDialogs="0"
       panelMessageTime="5000" panelAuthorName="VitaSound" panelAuthorEmail=""
       panelAuthorUrl="" panelAuthorDesc="Generated from params.yaml"
       panelVersionMajor="1" panelVersionMinor="0" panelVersionName="auto"
       panelVendor="VitaSound" panelDevice="{html.escape(title, quote=True)}"
       panelMidiSnapshotAfterLoad="0" panelMidiSnapshotAfterProgramChange="0"
       panelMidiSnapshotDelay="10" panelMidiSnapshotShowProgress="0"
       panelMidiInputChannelDevice="1" panelMidiInputDevice="-- None"
       panelMidiControllerChannelDevice="1" panelMidiControllerDevice="-- None"
       panelMidiOutputChannelDevice="1" panelMidiOutputDevice="-- None"
       panelMidiInputFromHost="0" panelMidiInputChannelHost="1"
       panelMidiOutputToHost="1" panelMidiOutputChannelHost="1"
       panelMidiThruH2H="0" panelMidiThruH2HChannelize="0"
       panelMidiThruH2D="0" panelMidiThruH2DChannelize="0"
       panelMidiThruD2D="0" panelMidiThruD2DChannelize="0"
       panelMidiThruD2H="0" panelMidiThruD2HChannelize="0"
       panelMidiRealtimeIgnore="1" panelMidiInputThreadPriority="7"
       panelMidiProgram="0" panelMidiBankLsb="0" panelMidiBankMsb="0"
       panelMidiSendProgramChangeOnLoad="0" panelMidiProgramCalloutOnprogramChange="0"
       panelMidiMatchCacheSize="32" panelMidiGlobalDelay="0" panelMidiPauseOut="0"
       panelMidiPauseIn="0" panelOSCEnabled="0" panelOSCPort="-1" panelOSCProtocol="0"
       luaPanelMidiChannelChanged="-- None" luaPanelMidiReceived="-- None"
       luaPanelMidiMultiReceived="-- None" luaPanelLoaded="-- None"
       luaPanelBeforeLoad="-- None" luaPanelSaved="-- None"
       luaPanelResourcesLoaded="-- None" luaPanelProgramChanged="-- None"
       luaPanelGlobalChanged="-- None" luaPanelMessageHandler="-- None"
       luaPanelModulatorValueChanged="-- None" luaPanelSaveState="-- None"
       luaPanelRestoreState="-- None" luaPanelMidiSnapshotPost="-- None"
       luaPanelMidiSnapshotPre="-- None" luaAudioProcessBlock="-- None"
       luaPanelOSCReceived="-- None"
       panelUID="{panel_uid}" panelInstanceUID="{uid()[:4]}"
       panelInstanceManufacturerID="Vtsn" panelModulatorListColumns="-- None"
       panelModulatorListCsvDelimiter="," panelModulatorListXmlRoot="ctrlrModulatorList"
       panelModulatorListXmlModulator="ctrlrModulator" panelModulatorListSortOption="1"
       panelGlobalVariables="64:-1:-1:-1:-1:-1:-1:-1:-1:-1:-1:-1:-1:-1:-1:-1:-1:-1:-1:-1:-1:-1:-1:-1:-1:-1:-1:-1:-1:-1:-1:-1:-1:-1:-1:-1:-1:-1:-1:-1:-1:-1:-1:-1:-1:-1:-1:-1:-1:-1:-1:-1:-1:-1:-1:-1:-1:-1:-1:-1:-1:-1:-1:-1"
       panelResources="-- None" panelPropertyDisplayIDs="0"
       ctrlrUseEditorWrapper="0" panelIndex="1">
  <midiLibrary uuid="{uid()}" luaTransInfo="-- None"
               midiLibraryParameterIndexProperty="modulatorCustomIndex"
               midiLibraryMidiProgramChangeControl="0"
               midiLibrarySendSnapAfterPChg="0"
               midiLibraryDefaultBankName="Bank" midiLibraryDefaultProgramName="Program"
               midiLibraryDefaultSnapshotName="Snapshot" midiLibraryCustomRequests="">
    <midiLibrarySnapshots name="Snapshots"/>
    <midiLibraryFirmware name="Firmware"/>
    <midiLibraryEditBuffer name="Edit buffer"/>
    <midiLibraryTransactions name="Transactions"/>
  </midiLibrary>
  <luaManager>
    <luaManagerMethods>
      <luaMethodGroup name="Built-In" uuid="{uid()}"/>
    </luaManagerMethods>
  </luaManager>
  <panelResources/>
{''.join(mod_blocks)}
</panel>
"""


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--yaml",
        type=Path,
        default=ROOT / "synths/mono_synth/mono_synth.params.yaml",
    )
    parser.add_argument(
        "--out",
        type=Path,
        default=ROOT / "synths/mono_synth/panels/mono_synth.panel",
    )
    args = parser.parse_args()

    with args.yaml.open(encoding="utf-8") as fh:
        data = yaml.safe_load(fh)

    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(generate_panel(data), encoding="utf-8")
    print(f"Wrote {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
