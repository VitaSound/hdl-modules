// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vgenerator.h for the primary calling header

#include "Vgenerator__pch.h"
#include "Vgenerator___024root.h"

void Vgenerator___024root___eval_act(Vgenerator___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vgenerator__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vgenerator___024root___eval_act\n"); );
}

VL_INLINE_OPT void Vgenerator___024root___nba_sequent__TOP__0(Vgenerator___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vgenerator__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vgenerator___024root___nba_sequent__TOP__0\n"); );
    // Init
    SData/*15:0*/ __Vdly__generator__DOT__counter;
    __Vdly__generator__DOT__counter = 0;
    // Body
    __Vdly__generator__DOT__counter = vlSelf->generator__DOT__counter;
    if (vlSelf->enable) {
        __Vdly__generator__DOT__counter = (0xffffU 
                                           & ((IData)(1U) 
                                              + (IData)(vlSelf->generator__DOT__counter)));
        if ((0x470U <= (IData)(vlSelf->generator__DOT__counter))) {
            vlSelf->audio_out = (1U & (~ (IData)(vlSelf->audio_out)));
            __Vdly__generator__DOT__counter = 0U;
        }
    } else {
        vlSelf->audio_out = 0U;
    }
    vlSelf->generator__DOT__counter = __Vdly__generator__DOT__counter;
}

void Vgenerator___024root___eval_nba(Vgenerator___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vgenerator__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vgenerator___024root___eval_nba\n"); );
    // Body
    if ((1ULL & vlSelf->__VnbaTriggered.word(0U))) {
        Vgenerator___024root___nba_sequent__TOP__0(vlSelf);
    }
}

void Vgenerator___024root___eval_triggers__act(Vgenerator___024root* vlSelf);

bool Vgenerator___024root___eval_phase__act(Vgenerator___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vgenerator__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vgenerator___024root___eval_phase__act\n"); );
    // Init
    VlTriggerVec<1> __VpreTriggered;
    CData/*0:0*/ __VactExecute;
    // Body
    Vgenerator___024root___eval_triggers__act(vlSelf);
    __VactExecute = vlSelf->__VactTriggered.any();
    if (__VactExecute) {
        __VpreTriggered.andNot(vlSelf->__VactTriggered, vlSelf->__VnbaTriggered);
        vlSelf->__VnbaTriggered.thisOr(vlSelf->__VactTriggered);
        Vgenerator___024root___eval_act(vlSelf);
    }
    return (__VactExecute);
}

bool Vgenerator___024root___eval_phase__nba(Vgenerator___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vgenerator__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vgenerator___024root___eval_phase__nba\n"); );
    // Init
    CData/*0:0*/ __VnbaExecute;
    // Body
    __VnbaExecute = vlSelf->__VnbaTriggered.any();
    if (__VnbaExecute) {
        Vgenerator___024root___eval_nba(vlSelf);
        vlSelf->__VnbaTriggered.clear();
    }
    return (__VnbaExecute);
}

#ifdef VL_DEBUG
VL_ATTR_COLD void Vgenerator___024root___dump_triggers__nba(Vgenerator___024root* vlSelf);
#endif  // VL_DEBUG
#ifdef VL_DEBUG
VL_ATTR_COLD void Vgenerator___024root___dump_triggers__act(Vgenerator___024root* vlSelf);
#endif  // VL_DEBUG

void Vgenerator___024root___eval(Vgenerator___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vgenerator__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vgenerator___024root___eval\n"); );
    // Init
    IData/*31:0*/ __VnbaIterCount;
    CData/*0:0*/ __VnbaContinue;
    // Body
    __VnbaIterCount = 0U;
    __VnbaContinue = 1U;
    while (__VnbaContinue) {
        if (VL_UNLIKELY((0x64U < __VnbaIterCount))) {
#ifdef VL_DEBUG
            Vgenerator___024root___dump_triggers__nba(vlSelf);
#endif
            VL_FATAL_MT("generator.sv", 1, "", "NBA region did not converge.");
        }
        __VnbaIterCount = ((IData)(1U) + __VnbaIterCount);
        __VnbaContinue = 0U;
        vlSelf->__VactIterCount = 0U;
        vlSelf->__VactContinue = 1U;
        while (vlSelf->__VactContinue) {
            if (VL_UNLIKELY((0x64U < vlSelf->__VactIterCount))) {
#ifdef VL_DEBUG
                Vgenerator___024root___dump_triggers__act(vlSelf);
#endif
                VL_FATAL_MT("generator.sv", 1, "", "Active region did not converge.");
            }
            vlSelf->__VactIterCount = ((IData)(1U) 
                                       + vlSelf->__VactIterCount);
            vlSelf->__VactContinue = 0U;
            if (Vgenerator___024root___eval_phase__act(vlSelf)) {
                vlSelf->__VactContinue = 1U;
            }
        }
        if (Vgenerator___024root___eval_phase__nba(vlSelf)) {
            __VnbaContinue = 1U;
        }
    }
}

#ifdef VL_DEBUG
void Vgenerator___024root___eval_debug_assertions(Vgenerator___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vgenerator__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vgenerator___024root___eval_debug_assertions\n"); );
    // Body
    if (VL_UNLIKELY((vlSelf->clk & 0xfeU))) {
        Verilated::overWidthError("clk");}
    if (VL_UNLIKELY((vlSelf->enable & 0xfeU))) {
        Verilated::overWidthError("enable");}
}
#endif  // VL_DEBUG
