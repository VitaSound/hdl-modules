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

VL_ATTR_COLD void Vgenerator___024root___eval_settle(Vgenerator___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vgenerator__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vgenerator___024root___eval_settle\n"); );
}

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
    vlSelf->audio_out = VL_RAND_RESET_I(1);
    vlSelf->generator__DOT__counter = VL_RAND_RESET_I(16);
    vlSelf->__Vtrigprevexpr___TOP__clk__0 = VL_RAND_RESET_I(1);
}
