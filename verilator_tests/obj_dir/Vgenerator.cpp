// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Model implementation (design independent parts)

#include "Vgenerator__pch.h"

//============================================================
// Constructors

Vgenerator::Vgenerator(VerilatedContext* _vcontextp__, const char* _vcname__)
    : VerilatedModel{*_vcontextp__}
    , vlSymsp{new Vgenerator__Syms(contextp(), _vcname__, this)}
    , clk{vlSymsp->TOP.clk}
    , audio_out{vlSymsp->TOP.audio_out}
    , rootp{&(vlSymsp->TOP)}
{
    // Register model with the context
    contextp()->addModel(this);
}

Vgenerator::Vgenerator(const char* _vcname__)
    : Vgenerator(Verilated::threadContextp(), _vcname__)
{
}

//============================================================
// Destructor

Vgenerator::~Vgenerator() {
    delete vlSymsp;
}

//============================================================
// Evaluation function

#ifdef VL_DEBUG
void Vgenerator___024root___eval_debug_assertions(Vgenerator___024root* vlSelf);
#endif  // VL_DEBUG
void Vgenerator___024root___eval_static(Vgenerator___024root* vlSelf);
void Vgenerator___024root___eval_initial(Vgenerator___024root* vlSelf);
void Vgenerator___024root___eval_settle(Vgenerator___024root* vlSelf);
void Vgenerator___024root___eval(Vgenerator___024root* vlSelf);

void Vgenerator::eval_step() {
    VL_DEBUG_IF(VL_DBG_MSGF("+++++TOP Evaluate Vgenerator::eval_step\n"); );
#ifdef VL_DEBUG
    // Debug assertions
    Vgenerator___024root___eval_debug_assertions(&(vlSymsp->TOP));
#endif  // VL_DEBUG
    vlSymsp->__Vm_deleter.deleteAll();
    if (VL_UNLIKELY(!vlSymsp->__Vm_didInit)) {
        vlSymsp->__Vm_didInit = true;
        VL_DEBUG_IF(VL_DBG_MSGF("+ Initial\n"););
        Vgenerator___024root___eval_static(&(vlSymsp->TOP));
        Vgenerator___024root___eval_initial(&(vlSymsp->TOP));
        Vgenerator___024root___eval_settle(&(vlSymsp->TOP));
    }
    VL_DEBUG_IF(VL_DBG_MSGF("+ Eval\n"););
    Vgenerator___024root___eval(&(vlSymsp->TOP));
    // Evaluate cleanup
    Verilated::endOfEval(vlSymsp->__Vm_evalMsgQp);
}

//============================================================
// Events and timing
bool Vgenerator::eventsPending() { return false; }

uint64_t Vgenerator::nextTimeSlot() {
    VL_FATAL_MT(__FILE__, __LINE__, "", "%Error: No delays in the design");
    return 0;
}

//============================================================
// Utilities

const char* Vgenerator::name() const {
    return vlSymsp->name();
}

//============================================================
// Invoke final blocks

void Vgenerator___024root___eval_final(Vgenerator___024root* vlSelf);

VL_ATTR_COLD void Vgenerator::final() {
    Vgenerator___024root___eval_final(&(vlSymsp->TOP));
}

//============================================================
// Implementations of abstract methods from VerilatedModel

const char* Vgenerator::hierName() const { return vlSymsp->name(); }
const char* Vgenerator::modelName() const { return "Vgenerator"; }
unsigned Vgenerator::threads() const { return 1; }
void Vgenerator::prepareClone() const { contextp()->prepareClone(); }
void Vgenerator::atClone() const {
    contextp()->threadPoolpOnClone();
}

//============================================================
// Trace configuration

VL_ATTR_COLD void Vgenerator::trace(VerilatedVcdC* tfp, int levels, int options) {
    vl_fatal(__FILE__, __LINE__, __FILE__,"'Vgenerator::trace()' called on model that was Verilated without --trace option");
}
