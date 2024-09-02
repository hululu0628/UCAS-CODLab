#include "perf_cnt.h"

volatile unsigned long * const cpu_perf_cnt_0 = (void *)0x60010000;
volatile unsigned long * const cpu_perf_cnt_1 = (void *)0x60010008;
volatile unsigned long * const cpu_perf_cnt_2 = (void *)0x60011000;
volatile unsigned long * const cpu_perf_cnt_3 = (void *)0x60011008;
volatile unsigned long * const cpu_perf_cnt_4 = (void *)0x60012000;
volatile unsigned long * const cpu_perf_cnt_5 = (void *)0x60012008;
volatile unsigned long * const cpu_perf_cnt_6 = (void *)0x60013000;
volatile unsigned long * const cpu_perf_cnt_7 = (void *)0x60013008;
volatile unsigned long * const cpu_perf_cnt_8 = (void *)0x60014000;
volatile unsigned long * const cpu_perf_cnt_9 = (void *)0x60014008;

unsigned long _uptime() {
  // TODO [COD]
  //   You can use this function to access performance counter related with time or cycle.
  return *cpu_perf_cnt_0;  //cpu_perf_cnt_0
}

unsigned long _instr_num() {
  return *cpu_perf_cnt_1;
}

unsigned long _instr_req_cycle() {
  return *cpu_perf_cnt_2;
}

unsigned long _instr_valid_cycle() {
  return *cpu_perf_cnt_3;
}

unsigned long _mems_req_cycle() {
  return *cpu_perf_cnt_4;
}

unsigned long _meml_req_cycle() {
  return *cpu_perf_cnt_5;
}

unsigned long _mem_valid_cycle() {
  return *cpu_perf_cnt_6;
}

unsigned long _jump_num() {
  return *cpu_perf_cnt_7;
}

unsigned long _branch_num() {
  return *cpu_perf_cnt_8;
}

unsigned long _wrongbranch_num() {
  return *cpu_perf_cnt_9;
}

void bench_prepare(Result *res) {
  // TODO [COD]
  //   Add preprocess code, record performance counters' initial states.
  //   You can communicate between bench_prepare() and bench_done() through
  //   static variables or add additional fields in `struct Result`
  res->msec = _uptime();
  res->instrnum = _instr_num();
  res->instrreq = _instr_req_cycle();
  res->instrvalid = _instr_valid_cycle();
  res->memsreq = _mems_req_cycle();
  res->memlreq = _meml_req_cycle();
  res->memvalid = _mem_valid_cycle();
  res->jumpnum = _jump_num();
  res->branchnum = _branch_num();
  res->wrongbranchnum = _wrongbranch_num();
}

void bench_done(Result *res) {
  // TODO [COD]
  //  Add postprocess code, record performance counters' current states.
  res->msec = _uptime() - res->msec;
  res->instrnum = _instr_num() - res->instrnum;
  res->instrreq = _instr_req_cycle() - res->instrreq;
  res->instrvalid = _instr_valid_cycle() - res->instrvalid;
  res->memsreq = _mems_req_cycle() - res->memsreq;
  res->memlreq = _meml_req_cycle() - res->memlreq;
  res->memvalid = _mem_valid_cycle() - res->memvalid;
  res->jumpnum = _jump_num() - res->jumpnum;
  res->branchnum = _branch_num() - res->branchnum;
  res->wrongbranchnum = _wrongbranch_num() - res->wrongbranchnum;
}

