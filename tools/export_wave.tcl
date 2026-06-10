# Export GTKWave view to PostScript for PNG conversion.
# Environment:
#   WAVE_PS_FILE - output .ps path (required)

if {![info exists ::env(WAVE_PS_FILE)] || $::env(WAVE_PS_FILE) eq ""} {
    puts stderr "WAVE_PS_FILE is not set"
    exit 1
}

set ps_file $::env(WAVE_PS_FILE)
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

catch { gtkwave::/Edit/Set_Trace_Max_Hier 0 }
catch { gtkwave::/Time/Zoom/Zoom_Full }
catch { gtkwave::/File/Print_To_File PS {A4} Full $ps_file }
catch { gtkwave::/File/Quit }
exit
