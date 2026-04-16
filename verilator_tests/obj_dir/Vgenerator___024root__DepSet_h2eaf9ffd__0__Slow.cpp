// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vgenerator.h for the primary calling header

#include "Vgenerator__pch.h"
#include "Vgenerator__Syms.h"
#include "Vgenerator___024root.h"

#ifdef VL_DEBUG
VL_ATTR_COLD void Vgenerator___024root___dump_triggers__stl(Vgenerator___024root* vlSelf);
#endif  // VL_DEBUG

VL_ATTR_COLD void Vgenerator___024root___eval_triggers__stl(Vgenerator___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vgenerator__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vgenerator___024root___eval_triggers__stl\n"); );
    // Body
    vlSelf->__VstlTriggered.set(0U, (IData)(vlSelf->__VstlFirstIteration));
#ifdef VL_DEBUG
    if (VL_UNLIKELY(vlSymsp->_vm_contextp__->debug())) {
        Vgenerator___024root___dump_triggers__stl(vlSelf);
    }
#endif
}
