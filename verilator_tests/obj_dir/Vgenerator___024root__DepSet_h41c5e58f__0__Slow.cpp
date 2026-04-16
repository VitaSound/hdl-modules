// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vgenerator.h for the primary calling header

#include "Vgenerator__pch.h"
#include "Vgenerator___024root.h"

VL_ATTR_COLD void Vgenerator___024root___eval_static__TOP(Vgenerator___024root* vlSelf);

VL_ATTR_COLD void Vgenerator___024root___eval_static(Vgenerator___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vgenerator__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vgenerator___024root___eval_static\n"); );
    // Body
    Vgenerator___024root___eval_static__TOP(vlSelf);
}

VL_ATTR_COLD void Vgenerator___024root___eval_static__TOP(Vgenerator___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vgenerator__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vgenerator___024root___eval_static__TOP\n"); );
    // Body
    vlSelf->generator__DOT__counter = 0U;
}

VL_ATTR_COLD void Vgenerator___024root___eval_initial(Vgenerator___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vgenerator__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vgenerator___024root___eval_initial\n"); );
    // Body
    vlSelf->__Vtrigprevexpr___TOP__clk__0 = vlSelf->clk;
}

VL_ATTR_COLD void Vgenerator___024root___eval_final(Vgenerator___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vgenerator__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vgenerator___024root___eval_final\n"); );
}

#ifdef VL_DEBUG
VL_ATTR_COLD void Vgenerator___024root___dump_triggers__stl(Vgenerator___024root* vlSelf);
#endif  // VL_DEBUG
VL_ATTR_COLD bool Vgenerator___024root___eval_phase__stl(Vgenerator___024root* vlSelf);

VL_ATTR_COLD void Vgenerator___024root___eval_settle(Vgenerator___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vgenerator__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vgenerator___024root___eval_settle\n"); );
    // Init
    IData/*31:0*/ __VstlIterCount;
    CData/*0:0*/ __VstlContinue;
    // Body
    __VstlIterCount = 0U;
    vlSelf->__VstlFirstIteration = 1U;
    __VstlContinue = 1U;
    while (__VstlContinue) {
        if (VL_UNLIKELY((0x64U < __VstlIterCount))) {
#ifdef VL_DEBUG
            Vgenerator___024root___dump_triggers__stl(vlSelf);
#endif
            VL_FATAL_MT("generator.sv", 1, "", "Settle region did not converge.");
        }
        __VstlIterCount = ((IData)(1U) + __VstlIterCount);
        __VstlContinue = 0U;
        if (Vgenerator___024root___eval_phase__stl(vlSelf)) {
            __VstlContinue = 1U;
        }
        vlSelf->__VstlFirstIteration = 0U;
    }
}

#ifdef VL_DEBUG
VL_ATTR_COLD void Vgenerator___024root___dump_triggers__stl(Vgenerator___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vgenerator__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vgenerator___024root___dump_triggers__stl\n"); );
    // Body
    if ((1U & (~ (IData)(vlSelf->__VstlTriggered.any())))) {
        VL_DBG_MSGF("         No triggers active\n");
    }
    if ((1ULL & vlSelf->__VstlTriggered.word(0U))) {
        VL_DBG_MSGF("         'stl' region trigger index 0 is active: Internal 'stl' trigger - first iteration\n");
    }
}
#endif  // VL_DEBUG

void Vgenerator___024root___ico_sequent__TOP__0(Vgenerator___024root* vlSelf);

VL_ATTR_COLD void Vgenerator___024root___eval_stl(Vgenerator___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vgenerator__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vgenerator___024root___eval_stl\n"); );
    // Body
    if ((1ULL & vlSelf->__VstlTriggered.word(0U))) {
        Vgenerator___024root___ico_sequent__TOP__0(vlSelf);
    }
}

VL_ATTR_COLD void Vgenerator___024root___eval_triggers__stl(Vgenerator___024root* vlSelf);

VL_ATTR_COLD bool Vgenerator___024root___eval_phase__stl(Vgenerator___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vgenerator__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vgenerator___024root___eval_phase__stl\n"); );
    // Init
    CData/*0:0*/ __VstlExecute;
    // Body
    Vgenerator___024root___eval_triggers__stl(vlSelf);
    __VstlExecute = vlSelf->__VstlTriggered.any();
    if (__VstlExecute) {
        Vgenerator___024root___eval_stl(vlSelf);
    }
    return (__VstlExecute);
}

#ifdef VL_DEBUG
VL_ATTR_COLD void Vgenerator___024root___dump_triggers__ico(Vgenerator___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vgenerator__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vgenerator___024root___dump_triggers__ico\n"); );
    // Body
    if ((1U & (~ (IData)(vlSelf->__VicoTriggered.any())))) {
        VL_DBG_MSGF("         No triggers active\n");
    }
    if ((1ULL & vlSelf->__VicoTriggered.word(0U))) {
        VL_DBG_MSGF("         'ico' region trigger index 0 is active: Internal 'ico' trigger - first iteration\n");
    }
}
#endif  // VL_DEBUG

#ifdef VL_DEBUG
VL_ATTR_COLD void Vgenerator___024root___dump_triggers__act(Vgenerator___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vgenerator__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vgenerator___024root___dump_triggers__act\n"); );
    // Body
    if ((1U & (~ (IData)(vlSelf->__VactTriggered.any())))) {
        VL_DBG_MSGF("         No triggers active\n");
    }
    if ((1ULL & vlSelf->__VactTriggered.word(0U))) {
        VL_DBG_MSGF("         'act' region trigger index 0 is active: @(posedge clk)\n");
    }
}
#endif  // VL_DEBUG

#ifdef VL_DEBUG
VL_ATTR_COLD void Vgenerator___024root___dump_triggers__nba(Vgenerator___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vgenerator__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vgenerator___024root___dump_triggers__nba\n"); );
    // Body
    if ((1U & (~ (IData)(vlSelf->__VnbaTriggered.any())))) {
        VL_DBG_MSGF("         No triggers active\n");
    }
    if ((1ULL & vlSelf->__VnbaTriggered.word(0U))) {
        VL_DBG_MSGF("         'nba' region trigger index 0 is active: @(posedge clk)\n");
    }
}
#endif  // VL_DEBUG

VL_ATTR_COLD void Vgenerator___024root___ctor_var_reset(Vgenerator___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vgenerator__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vgenerator___024root___ctor_var_reset\n"); );
    // Body
    vlSelf->clk = VL_RAND_RESET_I(1);
    vlSelf->enable = VL_RAND_RESET_I(1);
    vlSelf->note = VL_RAND_RESET_I(7);
    vlSelf->audio_out = VL_RAND_RESET_I(1);
    vlSelf->generator__DOT__counter = VL_RAND_RESET_I(16);
    vlSelf->generator__DOT__divider = VL_RAND_RESET_I(16);
    vlSelf->__Vtrigprevexpr___TOP__clk__0 = VL_RAND_RESET_I(1);
}
