# Export GTKWave main window to PNG (color, correct orientation).
# Environment:
#   WAVE_PNG_FILE - output .png path (required)
#   GTKW_FILE     - if set, signals are loaded from save file (optional)

if {![info exists ::env(WAVE_PNG_FILE)] || $::env(WAVE_PNG_FILE) eq ""} {
    puts stderr "WAVE_PNG_FILE is not set"
    exit 1
}

set png_file $::env(WAVE_PNG_FILE)
set use_fallback 1

if {[info exists ::env(GTKW_FILE)] && $::env(GTKW_FILE) ne ""} {
    set use_fallback 0
}

if {$use_fallback} {
    set nfacs [gtkwave::getNumFacs]
    set facs {}

    for {set i 0} {$i < $nfacs} {incr i} {
        set facname [gtkwave::getFacName $i]
        if {[string match "testbench.*" $facname]} {
            lappend facs $facname
        }
    }

    if {[llength $facs] > 0} {
        gtkwave::addSignalsFromList $facs
    }
}

catch { gtkwave::/Edit/Color_Format/Use_Color 1 }

if {$use_fallback} {
    catch { gtkwave::/Edit/Set_Trace_Max_Hier 0 }
    catch { gtkwave::/Time/Zoom/Zoom_Full }
}

# Let test.gtkw restore zoom, trace formats (analog/digital), and signal list.
after 800
catch { gtkwave::/File/Grab_To_File $png_file }
catch { gtkwave::/File/Quit }
exit
