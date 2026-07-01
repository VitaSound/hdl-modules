// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vmini_fx.h for the primary calling header

#include "Vmini_fx.h"
#include "Vmini_fx__Syms.h"

//==========

void Vmini_fx::eval_step() {
    VL_DEBUG_IF(VL_DBG_MSGF("+++++TOP Evaluate Vmini_fx::eval\n"); );
    Vmini_fx__Syms* __restrict vlSymsp = this->__VlSymsp;  // Setup global symbol table
    Vmini_fx* const __restrict vlTOPp VL_ATTR_UNUSED = vlSymsp->TOPp;
#ifdef VL_DEBUG
    // Debug assertions
    _eval_debug_assertions();
#endif  // VL_DEBUG
    // Initialize
    if (VL_UNLIKELY(!vlSymsp->__Vm_didInit)) _eval_initial_loop(vlSymsp);
    // Evaluate till stable
    int __VclockLoop = 0;
    QData __Vchange = 1;
    do {
        VL_DEBUG_IF(VL_DBG_MSGF("+ Clock loop\n"););
        _eval(vlSymsp);
        if (VL_UNLIKELY(++__VclockLoop > 100)) {
            // About to fail, so enable debug to see what's not settling.
            // Note you must run make with OPT=-DVL_DEBUG for debug prints.
            int __Vsaved_debug = Verilated::debug();
            Verilated::debug(1);
            __Vchange = _change_request(vlSymsp);
            Verilated::debug(__Vsaved_debug);
            VL_FATAL_MT("top.sv", 1, "",
                "Verilated model didn't converge\n"
                "- See DIDNOTCONVERGE in the Verilator manual");
        } else {
            __Vchange = _change_request(vlSymsp);
        }
    } while (VL_UNLIKELY(__Vchange));
}

void Vmini_fx::_eval_initial_loop(Vmini_fx__Syms* __restrict vlSymsp) {
    vlSymsp->__Vm_didInit = true;
    _eval_initial(vlSymsp);
    // Evaluate till stable
    int __VclockLoop = 0;
    QData __Vchange = 1;
    do {
        _eval_settle(vlSymsp);
        _eval(vlSymsp);
        if (VL_UNLIKELY(++__VclockLoop > 100)) {
            // About to fail, so enable debug to see what's not settling.
            // Note you must run make with OPT=-DVL_DEBUG for debug prints.
            int __Vsaved_debug = Verilated::debug();
            Verilated::debug(1);
            __Vchange = _change_request(vlSymsp);
            Verilated::debug(__Vsaved_debug);
            VL_FATAL_MT("top.sv", 1, "",
                "Verilated model didn't DC converge\n"
                "- See DIDNOTCONVERGE in the Verilator manual");
        } else {
            __Vchange = _change_request(vlSymsp);
        }
    } while (VL_UNLIKELY(__Vchange));
}

VL_INLINE_OPT void Vmini_fx::_sequent__TOP__2(Vmini_fx__Syms* __restrict vlSymsp) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmini_fx::_sequent__TOP__2\n"); );
    Vmini_fx* const __restrict vlTOPp VL_ATTR_UNUSED = vlSymsp->TOPp;
    // Variables
    CData/*7:0*/ __Vdly__mini_fx__DOT__u_midi_in__DOT__rcv_state;
    IData/*31:0*/ __Vdly__mini_fx__DOT__audio_acc;
    // Body
    __Vdly__mini_fx__DOT__audio_acc = vlTOPp->mini_fx__DOT__audio_acc;
    __Vdly__mini_fx__DOT__u_midi_in__DOT__rcv_state 
        = vlTOPp->mini_fx__DOT__u_midi_in__DOT__rcv_state;
    if (vlTOPp->rst) {
        vlTOPp->mini_fx__DOT__out_valid = 0U;
    } else {
        vlTOPp->mini_fx__DOT__out_valid = 0U;
        if (((IData)(vlTOPp->mini_fx__DOT__audio_tick) 
             & (IData)(vlTOPp->audio_in_valid))) {
            vlTOPp->mini_fx__DOT__out_valid = 1U;
        }
    }
    if (vlTOPp->rst) {
        vlTOPp->mini_fx__DOT__out_sample = 0x8000U;
    } else {
        if (((IData)(vlTOPp->mini_fx__DOT__audio_tick) 
             & (IData)(vlTOPp->audio_in_valid))) {
            vlTOPp->mini_fx__DOT__out_sample = (0xffffU 
                                                & ((IData)(0x8000U) 
                                                   + (IData)(vlTOPp->mini_fx__DOT__lp_out)));
        }
    }
    vlTOPp->mini_fx__DOT__u_midi_in__DOT__midi_command_ready_r = 0U;
    if (vlTOPp->rst) {
        __Vdly__mini_fx__DOT__u_midi_in__DOT__rcv_state = 0U;
        vlTOPp->mini_fx__DOT__u_midi_in__DOT__byte1 = 0U;
        vlTOPp->mini_fx__DOT__u_midi_in__DOT__byte2 = 0U;
        vlTOPp->mini_fx__DOT__u_midi_in__DOT__byte3 = 0U;
    } else {
        if (vlTOPp->byte_valid) {
            if ((0U == (IData)(vlTOPp->mini_fx__DOT__u_midi_in__DOT__rcv_state))) {
                if ((0xf0U == (IData)(vlTOPp->byte_in))) {
                    __Vdly__mini_fx__DOT__u_midi_in__DOT__rcv_state = 3U;
                } else {
                    if ((((8U <= (0xfU & ((IData)(vlTOPp->byte_in) 
                                          >> 4U))) 
                          & (0xeU >= (0xfU & ((IData)(vlTOPp->byte_in) 
                                              >> 4U)))) 
                         & ((IData)(vlTOPp->byte_in) 
                            >> 7U))) {
                        vlTOPp->mini_fx__DOT__u_midi_in__DOT__byte1 
                            = vlTOPp->byte_in;
                        __Vdly__mini_fx__DOT__u_midi_in__DOT__rcv_state = 1U;
                    }
                }
            } else {
                if ((1U == (IData)(vlTOPp->mini_fx__DOT__u_midi_in__DOT__rcv_state))) {
                    if ((0x80U & (IData)(vlTOPp->byte_in))) {
                        __Vdly__mini_fx__DOT__u_midi_in__DOT__rcv_state = 0U;
                    } else {
                        vlTOPp->mini_fx__DOT__u_midi_in__DOT__byte2 
                            = vlTOPp->byte_in;
                        __Vdly__mini_fx__DOT__u_midi_in__DOT__rcv_state = 2U;
                    }
                } else {
                    if ((2U == (IData)(vlTOPp->mini_fx__DOT__u_midi_in__DOT__rcv_state))) {
                        if ((0x80U & (IData)(vlTOPp->byte_in))) {
                            __Vdly__mini_fx__DOT__u_midi_in__DOT__rcv_state = 0U;
                        } else {
                            vlTOPp->mini_fx__DOT__u_midi_in__DOT__byte3 
                                = vlTOPp->byte_in;
                            vlTOPp->mini_fx__DOT__u_midi_in__DOT__midi_command_ready_r = 1U;
                            __Vdly__mini_fx__DOT__u_midi_in__DOT__rcv_state = 0U;
                        }
                    } else {
                        if ((3U == (IData)(vlTOPp->mini_fx__DOT__u_midi_in__DOT__rcv_state))) {
                            if ((0xf7U == (IData)(vlTOPp->byte_in))) {
                                __Vdly__mini_fx__DOT__u_midi_in__DOT__rcv_state = 0U;
                            }
                        } else {
                            __Vdly__mini_fx__DOT__u_midi_in__DOT__rcv_state = 0U;
                        }
                    }
                }
            }
        }
    }
    if (vlTOPp->mini_fx__DOT__cc121) {
        vlTOPp->mini_fx__DOT__fcut14 = 0x2000U;
    } else {
        if (((IData)(vlTOPp->mini_fx__DOT__cc_evt) 
             & (0x4aU == (IData)(vlTOPp->mini_fx__DOT__lsb)))) {
            vlTOPp->mini_fx__DOT__fcut14 = ((0x7fU 
                                             & (IData)(vlTOPp->mini_fx__DOT__fcut14)) 
                                            | ((IData)(vlTOPp->mini_fx__DOT__msb) 
                                               << 7U));
            vlTOPp->mini_fx__DOT__fcut14 = ((0x3f80U 
                                             & (IData)(vlTOPp->mini_fx__DOT__fcut14)) 
                                            | (IData)(vlTOPp->mini_fx__DOT__msb));
        } else {
            if (((IData)(vlTOPp->mini_fx__DOT__cc_evt) 
                 & (0x6aU == (IData)(vlTOPp->mini_fx__DOT__lsb)))) {
                vlTOPp->mini_fx__DOT__fcut14 = ((0x3f80U 
                                                 & (IData)(vlTOPp->mini_fx__DOT__fcut14)) 
                                                | (IData)(vlTOPp->mini_fx__DOT__msb));
            }
        }
    }
    if (vlTOPp->rst) {
        vlTOPp->mini_fx__DOT__u_svf__DOT__z1 = 0ULL;
    } else {
        if (vlTOPp->mini_fx__DOT____Vcellinp__u_svf__tick) {
            vlTOPp->mini_fx__DOT__u_svf__DOT__z1 = 
                (VL_LTS_IQQ(1,36,36, 0x7ffffffffULL, vlTOPp->mini_fx__DOT__u_svf__DOT__z1_next)
                  ? 0x7ffffffffULL : (VL_GTS_IQQ(1,36,36, 0x800000000ULL, vlTOPp->mini_fx__DOT__u_svf__DOT__z1_next)
                                       ? 0x800000000ULL
                                       : ((VL_GTS_IQQ(1,36,36, 1ULL, vlTOPp->mini_fx__DOT__u_svf__DOT__z1_next) 
                                           & VL_LTS_IQQ(1,36,36, 0xfffffffffULL, vlTOPp->mini_fx__DOT__u_svf__DOT__z1_next))
                                           ? 0ULL : vlTOPp->mini_fx__DOT__u_svf__DOT__z1_next)));
        }
    }
    if (vlTOPp->rst) {
        vlTOPp->mini_fx__DOT__u_svf__DOT__z2 = 0ULL;
    } else {
        if (vlTOPp->mini_fx__DOT____Vcellinp__u_svf__tick) {
            vlTOPp->mini_fx__DOT__u_svf__DOT__z2 = 
                (VL_LTS_IQQ(1,36,36, 0x7ffffffffULL, vlTOPp->mini_fx__DOT__u_svf__DOT__z2_next)
                  ? 0x7ffffffffULL : (VL_GTS_IQQ(1,36,36, 0x800000000ULL, vlTOPp->mini_fx__DOT__u_svf__DOT__z2_next)
                                       ? 0x800000000ULL
                                       : ((VL_GTS_IQQ(1,36,36, 1ULL, vlTOPp->mini_fx__DOT__u_svf__DOT__z2_next) 
                                           & VL_LTS_IQQ(1,36,36, 0xfffffffffULL, vlTOPp->mini_fx__DOT__u_svf__DOT__z2_next))
                                           ? 0ULL : vlTOPp->mini_fx__DOT__u_svf__DOT__z2_next)));
        }
    }
    if ((((IData)(vlTOPp->mini_fx__DOT__cc_evt) & (0x47U 
                                                   == (IData)(vlTOPp->mini_fx__DOT__lsb))) 
         | (IData)(vlTOPp->mini_fx__DOT__cc121))) {
        vlTOPp->mini_fx__DOT__fres7 = ((IData)(vlTOPp->mini_fx__DOT__cc121)
                                        ? 0U : (IData)(vlTOPp->mini_fx__DOT__msb));
    }
    vlTOPp->mini_fx__DOT__u_midi_in__DOT__rcv_state 
        = __Vdly__mini_fx__DOT__u_midi_in__DOT__rcv_state;
    vlTOPp->audio_valid = vlTOPp->mini_fx__DOT__out_valid;
    vlTOPp->audio_sample = vlTOPp->mini_fx__DOT__out_sample;
    if (vlTOPp->rst) {
        __Vdly__mini_fx__DOT__audio_acc = 0U;
        vlTOPp->mini_fx__DOT__audio_tick = 0U;
    } else {
        vlTOPp->mini_fx__DOT__audio_tick = 0U;
        if ((0xf4240U <= ((IData)(0xac44U) + vlTOPp->mini_fx__DOT__audio_acc))) {
            __Vdly__mini_fx__DOT__audio_acc = ((IData)(0xfff16a04U) 
                                               + vlTOPp->mini_fx__DOT__audio_acc);
            vlTOPp->mini_fx__DOT__audio_tick = 1U;
        } else {
            __Vdly__mini_fx__DOT__audio_acc = ((IData)(0xac44U) 
                                               + vlTOPp->mini_fx__DOT__audio_acc);
        }
    }
    if (vlTOPp->rst) {
        vlTOPp->mini_fx__DOT__lp_out = 0U;
    } else {
        if (vlTOPp->mini_fx__DOT____Vcellinp__u_svf__tick) {
            vlTOPp->mini_fx__DOT__lp_out = vlTOPp->mini_fx__DOT__u_svf__DOT__lp_next;
        }
    }
    vlTOPp->mini_fx__DOT__msb = (((IData)(vlTOPp->mini_fx__DOT__u_midi_in__DOT__midi_command_ready_r) 
                                  & (~ ((0xcU == (0xfU 
                                                  & ((IData)(vlTOPp->mini_fx__DOT__u_midi_in__DOT__byte1) 
                                                     >> 4U))) 
                                        | (0xdU == 
                                           (0xfU & 
                                            ((IData)(vlTOPp->mini_fx__DOT__u_midi_in__DOT__byte1) 
                                             >> 4U))))))
                                  ? (0x7fU & (IData)(vlTOPp->mini_fx__DOT__u_midi_in__DOT__byte3))
                                  : 0U);
    vlTOPp->mini_fx__DOT__cc_evt = ((IData)(vlTOPp->mini_fx__DOT__u_midi_in__DOT__midi_command_ready_r) 
                                    & (0xbU == ((IData)(vlTOPp->mini_fx__DOT__u_midi_in__DOT__midi_command_ready_r)
                                                 ? 
                                                (0xfU 
                                                 & ((IData)(vlTOPp->mini_fx__DOT__u_midi_in__DOT__byte1) 
                                                    >> 4U))
                                                 : 0U)));
    vlTOPp->mini_fx__DOT__lsb = ((IData)(vlTOPp->mini_fx__DOT__u_midi_in__DOT__midi_command_ready_r)
                                  ? (0x7fU & (IData)(vlTOPp->mini_fx__DOT__u_midi_in__DOT__byte2))
                                  : 0U);
    vlTOPp->__Vtableidx1 = vlTOPp->mini_fx__DOT__fcut14;
    vlTOPp->mini_fx__DOT__svf_f = vlTOPp->__Vtable1_mini_fx__DOT__svf_f
        [vlTOPp->__Vtableidx1];
    vlTOPp->__Vtableidx2 = (0x7fU & ((IData)(0x7fU) 
                                     - (IData)(vlTOPp->mini_fx__DOT__fres7)));
    vlTOPp->mini_fx__DOT__svf_q = vlTOPp->__Vtable2_mini_fx__DOT__svf_q
        [vlTOPp->__Vtableidx2];
    vlTOPp->mini_fx__DOT__audio_acc = __Vdly__mini_fx__DOT__audio_acc;
    vlTOPp->mini_fx__DOT__cc121 = ((IData)(vlTOPp->mini_fx__DOT__cc_evt) 
                                   & (0x79U == (IData)(vlTOPp->mini_fx__DOT__lsb)));
    vlTOPp->mini_fx__DOT__u_svf__DOT__z2_next = (0xfffffffffULL 
                                                 & (VL_MULS_QQQ(36,36,36, 
                                                                (0xfffffffffULL 
                                                                 & VL_EXTENDS_QI(36,18, vlTOPp->mini_fx__DOT__svf_f)), 
                                                                (0xfffffffffULL 
                                                                 & VL_SHIFTRS_QQI(36,36,32, vlTOPp->mini_fx__DOT__u_svf__DOT__z1, 0x11U))) 
                                                    + vlTOPp->mini_fx__DOT__u_svf__DOT__z2));
    vlTOPp->__Vfunc_mini_fx__DOT__u_svf__DOT__sat16__2__v 
        = (0xfffffffffULL & VL_SHIFTRS_QQI(36,36,32, vlTOPp->mini_fx__DOT__u_svf__DOT__z2_next, 0xeU));
    vlTOPp->__Vfunc_mini_fx__DOT__u_svf__DOT__sat16__2__Vfuncout 
        = (VL_LTS_IQQ(1,36,36, 0x7fffULL, vlTOPp->__Vfunc_mini_fx__DOT__u_svf__DOT__sat16__2__v)
            ? 0x7fffU : (VL_GTS_IQQ(1,36,36, 0xfffff8000ULL, vlTOPp->__Vfunc_mini_fx__DOT__u_svf__DOT__sat16__2__v)
                          ? 0x8000U : (0xffffU & (IData)(vlTOPp->__Vfunc_mini_fx__DOT__u_svf__DOT__sat16__2__v))));
    vlTOPp->mini_fx__DOT__u_svf__DOT__lp_next = vlTOPp->__Vfunc_mini_fx__DOT__u_svf__DOT__sat16__2__Vfuncout;
}

VL_INLINE_OPT void Vmini_fx::_combo__TOP__4(Vmini_fx__Syms* __restrict vlSymsp) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmini_fx::_combo__TOP__4\n"); );
    Vmini_fx* const __restrict vlTOPp VL_ATTR_UNUSED = vlSymsp->TOPp;
    // Body
    vlTOPp->mini_fx__DOT__u_svf__DOT__hp_full = (0xfffffffffULL 
                                                 & (((((QData)((IData)(
                                                                       (0x3fU 
                                                                        & (- (IData)(
                                                                                (1U 
                                                                                & ((IData)(vlTOPp->audio_in) 
                                                                                >> 0xfU))))))) 
                                                       << 0x1eU) 
                                                      | (QData)((IData)(
                                                                        ((IData)(vlTOPp->audio_in) 
                                                                         << 0xeU)))) 
                                                     - 
                                                     VL_MULS_QQQ(36,36,36, 
                                                                 (0xfffffffffULL 
                                                                  & VL_SHIFTRS_QQI(36,36,32, vlTOPp->mini_fx__DOT__u_svf__DOT__z1, 0x11U)), 
                                                                 (0xfffffffffULL 
                                                                  & VL_EXTENDS_QI(36,18, vlTOPp->mini_fx__DOT__svf_q)))) 
                                                    - vlTOPp->mini_fx__DOT__u_svf__DOT__z2));
    vlTOPp->mini_fx__DOT____Vcellinp__u_svf__tick = 
        ((IData)(vlTOPp->mini_fx__DOT__audio_tick) 
         & (IData)(vlTOPp->audio_in_valid));
    vlTOPp->__Vfunc_mini_fx__DOT__u_svf__DOT__sat18__0__v 
        = (0xfffffffffULL & VL_SHIFTRS_QQI(36,36,32, vlTOPp->mini_fx__DOT__u_svf__DOT__hp_full, 0x11U));
    vlTOPp->__Vfunc_mini_fx__DOT__u_svf__DOT__sat18__0__Vfuncout 
        = (VL_LTS_IQQ(1,36,36, 0x1ffffULL, vlTOPp->__Vfunc_mini_fx__DOT__u_svf__DOT__sat18__0__v)
            ? 0x1ffffU : (VL_GTS_IQQ(1,36,36, 0xffffe0000ULL, vlTOPp->__Vfunc_mini_fx__DOT__u_svf__DOT__sat18__0__v)
                           ? 0x20000U : (0x3ffffU & (IData)(vlTOPp->__Vfunc_mini_fx__DOT__u_svf__DOT__sat18__0__v))));
    vlTOPp->mini_fx__DOT__u_svf__DOT__hp_int = vlTOPp->__Vfunc_mini_fx__DOT__u_svf__DOT__sat18__0__Vfuncout;
    vlTOPp->mini_fx__DOT__u_svf__DOT__z1_next = (0xfffffffffULL 
                                                 & (VL_MULS_QQQ(36,36,36, 
                                                                (0xfffffffffULL 
                                                                 & VL_EXTENDS_QI(36,18, vlTOPp->mini_fx__DOT__svf_f)), 
                                                                (0xfffffffffULL 
                                                                 & VL_EXTENDS_QI(36,18, vlTOPp->mini_fx__DOT__u_svf__DOT__hp_int))) 
                                                    + vlTOPp->mini_fx__DOT__u_svf__DOT__z1));
}

void Vmini_fx::_eval(Vmini_fx__Syms* __restrict vlSymsp) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmini_fx::_eval\n"); );
    Vmini_fx* const __restrict vlTOPp VL_ATTR_UNUSED = vlSymsp->TOPp;
    // Body
    if (((IData)(vlTOPp->clk) & (~ (IData)(vlTOPp->__Vclklast__TOP__clk)))) {
        vlTOPp->_sequent__TOP__2(vlSymsp);
    }
    vlTOPp->_combo__TOP__4(vlSymsp);
    // Final
    vlTOPp->__Vclklast__TOP__clk = vlTOPp->clk;
}

VL_INLINE_OPT QData Vmini_fx::_change_request(Vmini_fx__Syms* __restrict vlSymsp) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmini_fx::_change_request\n"); );
    Vmini_fx* const __restrict vlTOPp VL_ATTR_UNUSED = vlSymsp->TOPp;
    // Body
    return (vlTOPp->_change_request_1(vlSymsp));
}

VL_INLINE_OPT QData Vmini_fx::_change_request_1(Vmini_fx__Syms* __restrict vlSymsp) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmini_fx::_change_request_1\n"); );
    Vmini_fx* const __restrict vlTOPp VL_ATTR_UNUSED = vlSymsp->TOPp;
    // Body
    // Change detection
    QData __req = false;  // Logically a bool
    return __req;
}

#ifdef VL_DEBUG
void Vmini_fx::_eval_debug_assertions() {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vmini_fx::_eval_debug_assertions\n"); );
    // Body
    if (VL_UNLIKELY((clk & 0xfeU))) {
        Verilated::overWidthError("clk");}
    if (VL_UNLIKELY((rst & 0xfeU))) {
        Verilated::overWidthError("rst");}
    if (VL_UNLIKELY((byte_valid & 0xfeU))) {
        Verilated::overWidthError("byte_valid");}
    if (VL_UNLIKELY((audio_in_valid & 0xfeU))) {
        Verilated::overWidthError("audio_in_valid");}
}
#endif  // VL_DEBUG
