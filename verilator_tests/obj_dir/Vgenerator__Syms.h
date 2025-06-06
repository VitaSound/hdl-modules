// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Symbol table internal header
//
// Internal details; most calling programs do not need this header,
// unless using verilator public meta comments.

#ifndef VERILATED_VGENERATOR__SYMS_H_
#define VERILATED_VGENERATOR__SYMS_H_  // guard

#include "verilated.h"

// INCLUDE MODEL CLASS

#include "Vgenerator.h"

// INCLUDE MODULE CLASSES
#include "Vgenerator___024root.h"

// SYMS CLASS (contains all model state)
class alignas(VL_CACHE_LINE_BYTES)Vgenerator__Syms final : public VerilatedSyms {
  public:
    // INTERNAL STATE
    Vgenerator* const __Vm_modelp;
    VlDeleter __Vm_deleter;
    bool __Vm_didInit = false;

    // MODULE INSTANCE STATE
    Vgenerator___024root           TOP;

    // CONSTRUCTORS
    Vgenerator__Syms(VerilatedContext* contextp, const char* namep, Vgenerator* modelp);
    ~Vgenerator__Syms();

    // METHODS
    const char* name() { return TOP.name(); }
};

#endif  // guard
