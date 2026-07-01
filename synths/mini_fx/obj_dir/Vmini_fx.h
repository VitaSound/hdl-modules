// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Primary design header
//
// This header should be included by all source files instantiating the design.
// The class here is then constructed to instantiate the design.
// See the Verilator manual for examples.

#ifndef _VMINI_FX_H_
#define _VMINI_FX_H_  // guard

#include "verilated.h"

//==========

class Vmini_fx__Syms;

//----------

VL_MODULE(Vmini_fx) {
  public:
    
    // PORTS
    // The application code writes and reads these signals to
    // propagate new values into/out from the Verilated model.
    VL_IN8(clk,0,0);
    VL_IN8(rst,0,0);
    VL_IN8(byte_valid,0,0);
    VL_IN8(byte_in,7,0);
    VL_IN8(audio_in_valid,0,0);
    VL_OUT8(audio_valid,0,0);
    VL_IN16(audio_in,15,0);
    VL_OUT16(audio_sample,15,0);
    
    // LOCAL SIGNALS
    // Internals; generally not touched by application code
    CData/*6:0*/ mini_fx__DOT__lsb;
    CData/*6:0*/ mini_fx__DOT__msb;
    CData/*0:0*/ mini_fx__DOT__cc_evt;
    CData/*0:0*/ mini_fx__DOT__cc121;
    CData/*6:0*/ mini_fx__DOT__fres7;
    CData/*0:0*/ mini_fx__DOT__audio_tick;
    CData/*0:0*/ mini_fx__DOT__out_valid;
    CData/*7:0*/ mini_fx__DOT__u_midi_in__DOT__rcv_state;
    CData/*7:0*/ mini_fx__DOT__u_midi_in__DOT__byte1;
    CData/*7:0*/ mini_fx__DOT__u_midi_in__DOT__byte2;
    CData/*7:0*/ mini_fx__DOT__u_midi_in__DOT__byte3;
    CData/*0:0*/ mini_fx__DOT__u_midi_in__DOT__midi_command_ready_r;
    SData/*13:0*/ mini_fx__DOT__fcut14;
    SData/*15:0*/ mini_fx__DOT__lp_out;
    SData/*15:0*/ mini_fx__DOT__out_sample;
    SData/*15:0*/ mini_fx__DOT__u_svf__DOT__lp_next;
    IData/*17:0*/ mini_fx__DOT__svf_f;
    IData/*17:0*/ mini_fx__DOT__svf_q;
    IData/*31:0*/ mini_fx__DOT__audio_acc;
    IData/*17:0*/ mini_fx__DOT__u_svf__DOT__hp_int;
    QData/*35:0*/ mini_fx__DOT__u_svf__DOT__z1;
    QData/*35:0*/ mini_fx__DOT__u_svf__DOT__z2;
    QData/*35:0*/ mini_fx__DOT__u_svf__DOT__hp_full;
    QData/*35:0*/ mini_fx__DOT__u_svf__DOT__z1_next;
    QData/*35:0*/ mini_fx__DOT__u_svf__DOT__z2_next;
    
    // LOCAL VARIABLES
    // Internals; generally not touched by application code
    CData/*0:0*/ mini_fx__DOT____Vcellinp__u_svf__tick;
    CData/*6:0*/ __Vtableidx2;
    CData/*0:0*/ __Vclklast__TOP__clk;
    SData/*15:0*/ __Vfunc_mini_fx__DOT__u_svf__DOT__sat16__2__Vfuncout;
    SData/*13:0*/ __Vtableidx1;
    IData/*17:0*/ __Vfunc_mini_fx__DOT__u_svf__DOT__sat18__0__Vfuncout;
    QData/*35:0*/ __Vfunc_mini_fx__DOT__u_svf__DOT__sat18__0__v;
    QData/*35:0*/ __Vfunc_mini_fx__DOT__u_svf__DOT__sat16__2__v;
    static IData/*17:0*/ __Vtable1_mini_fx__DOT__svf_f[16384];
    static IData/*17:0*/ __Vtable2_mini_fx__DOT__svf_q[128];
    
    // INTERNAL VARIABLES
    // Internals; generally not touched by application code
    Vmini_fx__Syms* __VlSymsp;  // Symbol table
    
    // CONSTRUCTORS
  private:
    VL_UNCOPYABLE(Vmini_fx);  ///< Copying not allowed
  public:
    /// Construct the model; called by application code
    /// The special name  may be used to make a wrapper with a
    /// single model invisible with respect to DPI scope names.
    Vmini_fx(const char* name = "TOP");
    /// Destroy the model; called (often implicitly) by application code
    ~Vmini_fx();
    
    // API METHODS
    /// Evaluate the model.  Application must call when inputs change.
    void eval() { eval_step(); }
    /// Evaluate when calling multiple units/models per time step.
    void eval_step();
    /// Evaluate at end of a timestep for tracing, when using eval_step().
    /// Application must call after all eval() and before time changes.
    void eval_end_step() {}
    /// Simulation complete, run final blocks.  Application must call on completion.
    void final();
    
    // INTERNAL METHODS
  private:
    static void _eval_initial_loop(Vmini_fx__Syms* __restrict vlSymsp);
  public:
    void __Vconfigure(Vmini_fx__Syms* symsp, bool first);
  private:
    static QData _change_request(Vmini_fx__Syms* __restrict vlSymsp);
    static QData _change_request_1(Vmini_fx__Syms* __restrict vlSymsp);
  public:
    static void _combo__TOP__4(Vmini_fx__Syms* __restrict vlSymsp);
  private:
    void _ctor_var_reset() VL_ATTR_COLD;
  public:
    static void _eval(Vmini_fx__Syms* __restrict vlSymsp);
  private:
#ifdef VL_DEBUG
    void _eval_debug_assertions();
#endif  // VL_DEBUG
  public:
    static void _eval_initial(Vmini_fx__Syms* __restrict vlSymsp) VL_ATTR_COLD;
    static void _eval_settle(Vmini_fx__Syms* __restrict vlSymsp) VL_ATTR_COLD;
    static void _initial__TOP__1(Vmini_fx__Syms* __restrict vlSymsp) VL_ATTR_COLD;
    static void _sequent__TOP__2(Vmini_fx__Syms* __restrict vlSymsp);
    static void _settle__TOP__3(Vmini_fx__Syms* __restrict vlSymsp) VL_ATTR_COLD;
} VL_ATTR_ALIGNED(VL_CACHE_LINE_BYTES);

//----------


#endif  // guard
