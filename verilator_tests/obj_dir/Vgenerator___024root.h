// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design internal header
// See Vgenerator.h for the primary calling header

#ifndef VERILATED_VGENERATOR___024ROOT_H_
#define VERILATED_VGENERATOR___024ROOT_H_  // guard

#include "verilated.h"


class Vgenerator__Syms;

class alignas(VL_CACHE_LINE_BYTES) Vgenerator___024root final : public VerilatedModule {
  public:

    // DESIGN SPECIFIC STATE
    VL_IN8(clk,0,0);
    VL_IN8(enable,0,0);
    VL_OUT8(audio_out,0,0);
    CData/*0:0*/ __Vtrigprevexpr___TOP__clk__0;
    CData/*0:0*/ __VactContinue;
    SData/*15:0*/ generator__DOT__counter;
    IData/*31:0*/ __VactIterCount;
    VlTriggerVec<1> __VactTriggered;
    VlTriggerVec<1> __VnbaTriggered;

    // INTERNAL VARIABLES
    Vgenerator__Syms* const vlSymsp;

    // CONSTRUCTORS
    Vgenerator___024root(Vgenerator__Syms* symsp, const char* v__name);
    ~Vgenerator___024root();
    VL_UNCOPYABLE(Vgenerator___024root);

    // INTERNAL METHODS
    void __Vconfigure(bool first);
};


#endif  // guard
