/*------------------------------------------------------------------------------
* ion32sim.c -- ION (MIPS32 clone) simulator based on Steve Rhoad's "mlite".
*
* This is a heavily modified version of Steve Rhoad's "mlite" simulator, which
* is part of his PLASMA project (original date: 1/31/01).
* As part of the project ION, it is being progressively modified to emulate a
* MIPS32 ION core and it is no longer compatible to Plasma.
*
*-------------------------------------------------------------------------------
* COPYRIGHT:    Software placed into the public domain by the author.
*               Software 'as is' without warranty.  Author liable for nothing.
*
* IMPORTANT: Assumes host is little endian and MIPS is big endian.
*-----------------------------------------------------------------------------*/

#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <ctype.h>
#include <assert.h>
#include <stdbool.h>

#include "ion32sim.h"

/*---- Local macros ----------------------------------------------------------*/

/** Mask for several COP0 regs, 1 per bit that is actually implemenmted. */
#define STATUS_MASK     (0x0040ff17)
#define CAUSE_MASK      (0xb080ff7c)


/*---- Static data -----------------------------------------------------------*/

t_map memory_maps[NUM_MEM_MAPS] = {
    {/* Experimental memory map (default) */
        {/* Code TCM (Holds bootstrap code) */
        {VECTOR_RESET,  0x00004000, 0xf8000000, MEM_READONLY, NULL, "Code TCM"},
        /* Data TCM */
        {0xa0000000,    0x00002000, 0xf8000000, 0, NULL, "Data TCM"},
        /* main external ram block  */
        {0x80000000,    0x00080000, 0xf8000000, 0, NULL, "Cached RAM"},
        /* main external ram block  */
        {0x90000000,    0x00080000, 0xf8000000, MEM_TEST, NULL, "Cached test ROM"},
        /* external flash block */
        {0x00000000,    0x00040000, 0xf8000000, 0, NULL, "Cached FLASH"},
        }
    },

    {/* uClinux memory map with bootstrap BRAM, debug only, to be removed */
        {/* Bootstrap BRAM, read only */
        {VECTOR_RESET,  0x00008000, 0xf8000000, MEM_READONLY, NULL, "Code TCM"},
        /* Data TCM */
        {0x00000000,    0x00002000, 0xf8000000, 0, NULL, "Data TCM"},
        /* main external ram block  */
        {0x80000000,    0x00800000, 0xf8000000, 0, NULL, "XRAM0"},
        {0x10000000,    0x00800000, 0xf8000000, 0, NULL, "XRAM1"},
        /* external flash block */
        {0xb0000000,    0x00100000, 0xf8000000, 0, NULL, "Flash"},
        }
    },
};

extern t_args cmd_line_args;

/*---- OS-dependent support functions and definitions ------------------------*/
#ifndef WIN32
//Support for Linux
#include <termios.h>
#include <unistd.h>

void sim_sleep(unsigned int value){
    usleep(value * 1000);
}

int kbhit(void){
    struct termios oldt, newt;
    struct timeval tv;
    fd_set read_fd;

    tcgetattr(STDIN_FILENO, &oldt);
    newt = oldt;
    newt.c_lflag &= ~(ICANON | ECHO);
    tcsetattr(STDIN_FILENO, TCSANOW, &newt);
    tv.tv_sec=0;
    tv.tv_usec=0;
    FD_ZERO(&read_fd);
    FD_SET(0,&read_fd);
    if(select(1, &read_fd, NULL, NULL, &tv) == -1){
        return 0;
    }
    //tcsetattr(STDIN_FILENO, TCSANOW, &oldt);
    if(FD_ISSET(0,&read_fd)){
        return 1;
    }
    return 0;
}

int getch(void){
    struct termios oldt, newt;
    int ch;

    tcgetattr(STDIN_FILENO, &oldt);
    newt = oldt;
    newt.c_lflag &= ~(ICANON | ECHO);
    tcsetattr(STDIN_FILENO, TCSANOW, &newt);
    ch = getchar();
    //tcsetattr(STDIN_FILENO, TCSANOW, &oldt);
    return ch;
}
#else
//Support for Windows
#include <conio.h>
extern void __stdcall Sleep(unsigned long value);

void sim_sleep(unsigned int value){
    Sleep(value);
}

#endif
/*---- End of OS-dependent support functions and definitions -----------------*/


char *assertion_messages[2] = {
   "Unaligned read",
   "Unaligned write"
};


static char *reg_names[]={
    "zero","at","v0","v1","a0","a1","a2","a3",
    "t0","t1","t2","t3","t4","t5","t6","t7",
    "s0","s1","s2","s3","s4","s5","s6","s7",
    "t8","t9","k0","k1","gp","sp","s8","ra"
};

static char *opcode_string[]={
   "0SPECIAL","0REGIMM","1J","1JAL","2BEQ","2BNE","3BLEZ","3BGTZ",
   "5ADDI","5ADDIU","5SLTI","5SLTIU","5ANDI","5ORI","5XORI","6LUI",
   "cCOP0","cCOP1","cCOP2","cCOP3","2BEQL","2BNEL","3BLEZL","3BGTZL",
   "0?","0?","0?","0?","0SPECIAL2","0?","0?","0SPECIAL3",
   "8LB","8LH","8LWL","8LW","8LBU","8LHU","8LWR","0?",
   "8SB","8SH","8SWL","8SW","0?","0?","8SWR","0CACHE",
   "0LL","0LWC1","0LWC2","0LWC3","?","0LDC1","0LDC2","0LDC3"
   "0SC","0SWC1","0SWC2","0SWC3","?","0SDC1","0SDC2","0SDC3"
};

static char *special_string[]={
   "4SLL","0?","4SRL","4SRA","bSLLV","0?","bSRLV","bSRAV",
   "aJR","aJALR","0MOVZ","0MOVN","0SYSCALL","0BREAK","0?","0SYNC",
   "0MFHI","0MTHI","0MFLO","0MTLO","0?","0?","0?","0?",
   "0MULT","0MULTU","0DIV","0DIVU","0?","0?","0?","0?",
   "7ADD","7ADDU","7SUB","7SUBU","7AND","7OR","7XOR","7NOR",
   "0?","0?","7SLT","7SLTU","0?","0DADDU","0?","0?",
   "7TGE","7TGEU","7TLT","7TLTU","7TEQ","0?","7TNE","0?",
   "0?","0?","0?","0?","0?","0?","0?","0?"
};

static char *regimm_string[]={
   "9BLTZ","9BGEZ","9BLTZL","9BGEZL","0?","0?","0?","0?",
   "0TGEI","0TGEIU","0TLTI","0TLTIU","0TEQI","0?","0TNEI","0?",
   "9BLTZAL","9BEQZAL","9BLTZALL","9BGEZALL","0?","0?","0?","0?",
   "0?","0?","0?","0?","0?","0?","0?","0?"
};

/*---- Local function prototypes ---------------------------------------------*/

/* Debug and logging */
uint32_t log_cycle(t_state *s);
void log_read(t_state *s, int full_address, int word_value, int size, int log);
void log_failed_assertions(t_state *s);
uint32_t log_enabled(t_state *s);
void trigger_log(t_state *s);
void print_opcode_fields(uint32_t opcode);
void reserved_opcode(uint32_t pc, uint32_t opcode, t_state* s);
void log_call(uint32_t to, uint32_t from);
void log_ret(uint32_t to, uint32_t from);

void unimplemented(t_state *s, const char *txt);
void reverse_endianess(uint8_t *data, uint32_t bytes);
int32_t signed_rem(int32_t dividend, int32_t divisor);

/* COP2 interface simulation */
void cop2(t_state *s, uint32_t opcode);
static uint32_t cop2_get_reg(t_state *s,uint32_t rcop, uint32_t sel, bool ctrl);
static void cop2_set_reg(t_state *s,uint32_t rcop, uint32_t sel, bool ctrl, uint32_t data);

/* Hardware simulation */

uint32_t start_load(t_state *s, uint32_t addr, int rt, int data, int size);
uint32_t simulate_hw_irqs(t_state *s);



/*---- Local functions -------------------------------------------------------*/


/*---- Execution log ---------------------------------------------------------*/

/** Log to file a memory read operation (not including target reg change) */
void log_read(t_state *s, int full_address, int word_value, int size, int log){
    /* if bit CP0.16==1, this is a D-Cache line invalidation access and
           the HW will not read any actual data, so skip the log (@note1) */
    // FIXME refactor
    //if(log_enabled(s) && log!=0 && !(s->cp0_status & 0x00010000)){
    if(log_enabled(s) && log!=0){
        fprintf(s->t.log, "(%08x) [%08x] <%1d>=%08x RD\n",
              s->op_addr, full_address, size, word_value);
    }
}


int test_pattern(unsigned int base, unsigned int address){

    address &= 0x0ffff;
    address = address + (address << 16);

    return address;
}


/**
    Compute signed remainder in C99 like the HW does.

    The remainder must have the same sign as the dividend. This is how the HW
    works and what C99 mandates, but this program might be compiled with C90.
    So, to be on the safe side, we do the remainder explicitly here.
*/
int32_t signed_rem(int32_t dividend, int32_t divisor) {
    int32_t rem = dividend % divisor;
    if ((rem<0 && dividend>0) || (rem>0 && dividend<0) ) {
        return -rem;
    }
    else {
        return rem;
    }
}


/*-- unaligned store and load instructions -----------------------------------*/
/*
 These are meant to be left unimplemented and trapped. These functions simulate
 the unaligned r/w instructions until proper trap handlers are written.
*/

void mem_swl(t_state *s, uint32_t address, uint32_t value, uint32_t log){
    uint32_t data, offset;

    if(!s->do_unaligned) return unimplemented(s, "SWL");

    offset = (address & 0x03);
    address = (address & (~0x03));
    data = value;

    while(offset<4){
        mem_write(s,1,address+offset,(data>>24) & 0xff,0);
        data = data << 8;
        offset++;
    }
}

void mem_swr(t_state *s, uint32_t address, uint32_t value, uint32_t log){
    uint32_t data, offset;

    if(!s->do_unaligned) return unimplemented(s, "SWR");

    offset = (address & 0x03);
    address = (address & (~0x03));
    data = value;

    while(offset>=0){
        mem_write(s,1,address+offset,data & 0xff,0);
        data = data >> 8;
        offset--;
    }
}

void mem_lwr(t_state *s, uint32_t address, uint32_t reg_index, uint32_t log){
    uint32_t offset, data;
    uint32_t disp[4] = {24,         16,         8,          0};
    uint32_t mask[4] = {0x000000ff, 0x0000ffff, 0x00ffffff, 0xffffffff};

    if(!s->do_unaligned) return unimplemented(s, "LWR");

    offset = (address & 0x03);
    address = (address & (~0x03));

    data = mem_read(s, 4, address, 0);
    data = (data >> disp[offset]) & mask[offset];

    s->r[reg_index] = (s->r[reg_index] & (~mask[offset])) | data;
}

void mem_lwl(t_state *s, uint32_t address, uint32_t reg_index, uint32_t log){
    uint32_t offset, data;
    uint32_t disp[4] = {0,          8,          16,         24};
    uint32_t mask[4] = {0xffffffff, 0xffffff00, 0xffff0000, 0xff000000};

    if(!s->do_unaligned) return unimplemented(s, "LWL");

    offset = (address & 0x03);
    address = (address & (~0x03));

    data = mem_read(s, 4, address, 0);
    data = (data << disp[offset]) & mask[offset];

    s->r[reg_index] = (s->r[reg_index] & (~mask[offset])) | data;
}

/*---- Optional MIPS32 opcodes -----------------------------------------------*/

uint32_t count_leading(uint32_t lead, uint32_t src){
    uint32_t mask, bit_val, i;

    mask = 0x80000000;
    bit_val = lead? 0xffffffff : 0x00000000;

    for(i=0;i<32;i++){
        if((src & mask) != (bit_val & mask)){
            return i;
        }
        mask = mask >> 1;
    }

    return i;
}

uint32_t mult_gpr(uint32_t m1, uint32_t m2){
    uint32_t temp;

    temp = m1 * m2;
    return temp;
}

uint32_t ext_bitfield(uint32_t src, uint32_t opcode){
    uint32_t pos, size, mask, value;

    pos = (opcode>>6) & 0x1f;
    size = ((opcode>>11) & 0x1f) + 1;
    mask = (1 << size)-1;
    mask = mask << pos;

    value = (src & mask) >> pos;
    return value;
}

uint32_t ins_bitfield(uint32_t target, uint32_t src, uint32_t opcode){
    uint32_t pos, size, mask, value;

    pos = (opcode>>6) & 0x1f;
    size = ((opcode>>11) & 0x1f) + 1;
    mask = (1 << size)-1;
    mask = mask << pos;

    value = target & (~mask);
    value |= ((src << pos) & mask);
    return value;
}

/*---- Optional MMU and cache implementation ---------------------------------*/


/*---- End optional cache implementation -------------------------------------*/


/** Simulates MIPS-I multiplier unsigned behavior*/
void mult_big(unsigned int a,
              unsigned int b,
              unsigned int *hi,
              unsigned int *lo,
              int addsub){
    unsigned int ahi, alo, bhi, blo;
    unsigned int c0, c1, c2;
    unsigned int c1_a, c1_b;

    ahi = a >> 16;
    alo = a & 0xffff;
    bhi = b >> 16;
    blo = b & 0xffff;

    c0 = alo * blo;
    c1_a = ahi * blo;
    c1_b = alo * bhi;
    c2 = ahi * bhi;

    c2 += (c1_a >> 16) + (c1_b >> 16);
    c1 = (c1_a & 0xffff) + (c1_b & 0xffff) + (c0 >> 16);
    c2 += (c1 >> 16);
    c0 = (c1 << 16) + (c0 & 0xffff);

    /* Add to current HI:LO value if accumulating. */
    if(addsub > 0) {
        uint64_t acc, res;

        acc = *hi;
        acc = acc << 32;
        acc |= *lo;

        res = c2;
        res = res << 32;
        res |= c0;

        res += acc;
        c2 = res >> 32;
        c0 = res & 0xffffffff;
    }

    *hi = c2;
    *lo = c0;
}

/** Simulates MIPS-I multiplier signed behavior*/
void mult_big_signed(int a,
                     int b,
                     unsigned int *hi,
                     unsigned int *lo,
                     int addsub){
    int64_t xa, xb, xr, temp;
    int32_t rh, rl;

    xa = a;
    xb = b;
    xr = xa * xb;

    /* Add to current HI:LO value if accumulating. */
    if(addsub > 0) {
        int64_t acc;

        acc = *hi;
        acc = acc << 32;
        acc |= *lo;
        xr += acc;
    }

    temp = (xr >> 32) & 0xffffffff;
    rh = temp;
    temp = (xr >> 0) & 0xffffffff;
    rl = temp;

    *hi = rh;
    *lo = rl;
}

/** Load data from memory (used to simulate load delay slots) */
uint32_t start_load(t_state *s, uint32_t addr, int rt, int data, int size){
    /* load delay slot not simulated */
    log_read(s, addr, data, size, 1);
    if (rt>=0 && rt<32) s->r[rt] = data;
    return data;
}

void process_traps(t_state *s, uint32_t epc, uint32_t rSave, uint32_t rt){
    int32_t cause= -1;

    if(s->trap_cause >= 0){
        /* If there is a software-triggered trap pending, deal with it */
        cause = s->trap_cause;
    }
    else{
        /* If there's any hardware interrupt pending, deal with it */
        if(s->t.irq_trigger_countdown==0){
            uint32_t mask;
            // FIXME should delay if victim instruction is in delay slot
            /* trigger interrupt IF it is not masked... */
            mask = (s->cp0_status >> 10) & 0x3f;
            s->t.irq_current_inputs = (s->t.irq_trigger_inputs & mask);
            s->t.irq_trigger_inputs = 0;
            //printf("MASK = %02x\n", mask);
            //printf("Z    = %02x\n", s->t.irq_current_inputs);
            /* ...and if globally enabled. */
            if ((s->t.irq_current_inputs != 0) && (s->cp0_status & 0x01)) {
                cause = 0; /* cause = hardware interrupt */
                s->cause_ip = s->t.irq_current_inputs & 0x3f;
                //printf("IP = %02x\n", s->cause_ip);
            }
            s->t.irq_trigger_countdown--;
        }
        else if (s->t.irq_trigger_countdown>0){
            s->t.irq_trigger_countdown--;
        }
    }

    /* Now, whatever the cause was, do the trap handling */
    if(cause >= 0){
        s->trap_cause = cause;
        /* 'undo' current instruction EXCEPT if this is a HW interrupt. */
        if (cause > 0) s->r[rt] = rSave;
        /* set cause field ... */
        s->cp0_cause = (s->delay_slot & 0x1) << 31 |
                       (s->cause_ip & 0x3f) << 10 |
                       (s->trap_cause & 0x1f) << 2;
        /* ...and raise EXL status flag */
        s->cp0_status |= SR_EXL; // FIXME handle ERL

        /* adjust epc if we (i.e. the victim instruction) are in a delay slot */
        if(s->delay_slot){
            //printf("EPC adjusted for delay slot at %08xh\n", s->op_addr);
            epc = s->op_addr - 4;
        }
        s->epc = epc;
        /* Compute vector address as a function of the type of exception. */
        /* FIXME vector address harcoded */
        s->pc_next = VECTOR_TRAP;
        s->pc = VECTOR_TRAP;
        /* Simulation control flags... */
        s->skip = 1; /* skip instruction following victim */
    }
}

/** Execute one cycle of the CPU (including any interlock stall cycles) */
void cycle(t_state *s, int show_mode){
    unsigned int opcode;
    int delay_slot = 0; /* 1 of this instruction is a branch */
    unsigned int op, rs, rt, rd, re, func, imm, target;
    int imm_shift, branch=0, lbranch=2;
    int link=0; /* !=0 if this is a 'branch-and-link' opcode */
    int *r=s->r;
    unsigned int *u=(unsigned int*)s->r;
    unsigned int ptr, epc, rSave;
    char format;
    uint32_t aux;
    uint32_t target_offset16;
    uint32_t target_long;

    /* Update cycle counter (we implement an instruction counter actually )*/
    s->inst_ctr_prescaler++;
    if(s->inst_ctr_prescaler == (cmd_line_args.timer_prescaler-1)){
        s->inst_ctr_prescaler = 0;
        s->instruction_ctr++;
    }
    /* No traps pending for this instruction (yet) */
    s->trap_cause = -1;
    s->cause_ip = 0;

    /* fetch and decode instruction */
    opcode = mem_read(s, 4, s->pc, 0);

    op = (opcode >> 26) & 0x3f;
    rs = (opcode >> 21) & 0x1f;
    rt = (opcode >> 16) & 0x1f;
    rd = (opcode >> 11) & 0x1f;
    re = (opcode >> 6) & 0x1f;
    func = opcode & 0x3f;
    imm = opcode & 0xffff;
    imm_shift = (((int)(short)imm) << 2) - 4;
    target = (opcode << 6) >> 4;
    ptr = (short)imm + r[rs];
    r[0] = 0;
    target_offset16 = opcode & 0xffff;
    if(target_offset16 & 0x8000){
        target_offset16 |= 0xffff0000;
    }
    target_long = (opcode & 0x03ffffff)<<2;
    target_long |= (s->pc & 0xf0000000);

    /* Trigger log if we fetch from trigger address */
    if(s->pc == s->t.log_trigger_address){
        trigger_log(s);
    }

    /* if we are priting state to console, do it now */
    if(show_mode){
        printf("%8.8x %8.8x ", s->pc, opcode);
        if(op == 0){
            printf("  %-6s ", &(special_string[func][1]));
            format = special_string[func][0];
        }
        else if(op == 1){
            printf("  %-6s ", &(regimm_string[rt][1]));
            format = regimm_string[rt][0];
        }
        else{
            format = opcode_string[op][0];
            if(format!='c'){
                printf("  %-6s ", &(opcode_string[op][1]));
            }
            else{
                aux = op&0x03;
                switch(rs){
                    case 16:
                        /* FIXME partial decoding of some COP0 opcodes */
                        printf("  RFE      "); format = ' '; break;
                    case 4:
                        printf("  MTC%1d   ", aux); break;
                    case 0:
                        printf("  MFC%1d   ", aux); break;
                    default:
                        printf("  ???      "); break;
                        format = '?';
                }
            }
        }

        switch(format){
            case '1':
                printf("0x%08x", target_long);
                break;
            case '2':
                printf("%s,%s,0x%08x",
                       reg_names[rt], reg_names[rs],
                       (target_offset16*4)+s->pc+4);
                break;
            case '3':
                printf("%s,0x%08x", reg_names[rt], (target_offset16*4)+s->pc+4);
                break;
            case '4':
                printf("%s,%s,%d", reg_names[rd], reg_names[rt], re);
                break;
            case '5':
                printf("%s,%s,0x%04x",
                       reg_names[rt], reg_names[rs],
                       target_offset16&0xffff);
                break;
            case '6':
                printf("%s,0x%04x",
                       reg_names[rt],
                       target_offset16&0xffff);
                break;
            case '7':
                printf("%s,%s,%s", reg_names[rd], reg_names[rs], reg_names[rt]);
                break;
            case '8':
                printf("%s,%d(%s)", reg_names[rt],
                       (target_offset16), reg_names[rs]);
                break;
            case '9':
                printf("%s,0x%08x", reg_names[rt], (target_offset16*4)+s->pc+4);
                break;
            case 'a':
                printf("%s", reg_names[rs]);
                break;
            case 'b':
                printf("%s,%s,%s", reg_names[rd], reg_names[rt], reg_names[rs]);
                break;
            case 'c':
                printf("%s,$%d", reg_names[rt], rd);
                break;
            case '0':
                printf("$%2.2d $%2.2d $%2.2d $%2.2d ", rs, rt, rd, re);
                printf("%4.4x", imm);
                break;
            default:;
        }


        if(show_mode == 1){
            printf(" r[%2.2d]=%8.8x r[%2.2d]=%8.8x", rs, r[rs], rt, r[rt]);
        }
        printf("\n");
    }

    /* if we're just showing state to console, quit and don't run instruction */
    if(show_mode > 5){
        return;
    }

    /* epc will point to the intruction after the victim instruction; by
       default that's the instruction after this one */
    epc = s->pc + 4;

    /* If we catch a jump instruction jumping to itself, assume we hit the
       end of the program and quit. */
    if(s->pc == s->pc_next+4){
        printf("\n\nEndless loop at 0x%08x\n\n", s->pc-4);
        s->wakeup = 1;
    }
    s->op_addr = s->pc;
    s->pc = s->pc_next;
    s->pc_next = s->pc_next + 4;

    // Instructions in the delay slot of ERET will NOT be executed.
    if (s->eret_delay_slot) {
        s->eret_delay_slot = 0;
        return;
    }

    if(s->skip){
        s->skip = 0;
        return;
    }
    rSave = r[rt];
    //printf("PC = %08x\n", s->op_addr);
    switch(op){
    case 0x00:/*SPECIAL*/
        switch(func){
        case 0x00:/*SLL*/  r[rd]=r[rt]<<re;          break;
        case 0x02:/*SRL*/  r[rd]=u[rt]>>re;          break;
        case 0x03:/*SRA*/  r[rd]=r[rt]>>re;          break;
        case 0x04:/*SLLV*/ r[rd]=r[rt]<<r[rs];       break;
        case 0x06:/*SRLV*/ r[rd]=u[rt]>>r[rs];       break;
        case 0x07:/*SRAV*/ r[rd]=r[rt]>>r[rs];       break;
        case 0x08:/*JR*/   if(rs==31) log_ret(r[rs],epc);
                           delay_slot=1;
                           s->pc_next=r[rs];         break;
        case 0x09:/*JALR*/ delay_slot=1;
                           r[rd]=s->pc_next;
                           s->pc_next=r[rs];
                           log_call(s->pc_next, epc); break;
        case 0x0a:/*MOVZ*/  if(cmd_line_args.emulate_some_mips32){   /*IV*/
                                if(!r[rt]) r[rd]=r[rs];
                            };
                            break;
        case 0x0b:/*MOVN*/  if(cmd_line_args.emulate_some_mips32){    /*IV*/
                                if(r[rt]) r[rd]=r[rs];
                            };
                            break;
        case 0x0c:/*SYSCALL*/ s->trap_cause = 8;
                              //FIXME enable when running uClinux
                              //printf("SYSCALL (%08x)\n", s->pc);

                              break;
        case 0x0d:/*BREAK*/   s->trap_cause = 9;
                              //FIXME enable when running uClinux
                              //printf("BREAK (%08x)\n", s->pc);
                              break;
        case 0x0f:/*SYNC*/ s->wakeup=1;              break;
        case 0x10:/*MFHI*/ r[rd]=s->hi;              break;
        case 0x11:/*FTHI*/ s->hi=r[rs];              break;
        case 0x12:/*MFLO*/ r[rd]=s->lo;              break;
        case 0x13:/*MTLO*/ s->lo=r[rs];              break;
        case 0x18:/*MULT*/ mult_big_signed(r[rs],r[rt],&s->hi,&s->lo,0); break;
        case 0x19:/*MULTU*/ mult_big(r[rs],r[rt],&s->hi,&s->lo,0); break;
        case 0x1a:/*DIV*/  s->lo=r[rs]/r[rt]; s->hi=signed_rem(r[rs],r[rt]); break;
        case 0x1b:/*DIVU*/ s->lo=u[rs]/u[rt]; s->hi=u[rs]%u[rt]; break;
        case 0x20:/*ADD*/  r[rd]=r[rs]+r[rt];        break;
        case 0x21:/*ADDU*/ r[rd]=r[rs]+r[rt];        break;
        case 0x22:/*SUB*/  r[rd]=r[rs]-r[rt];        break;
        case 0x23:/*SUBU*/ r[rd]=r[rs]-r[rt];        break;
        case 0x24:/*AND*/  r[rd]=r[rs]&r[rt];        break;
        case 0x25:/*OR*/   r[rd]=r[rs]|r[rt];        break;
        case 0x26:/*XOR*/  r[rd]=r[rs]^r[rt];        break;
        case 0x27:/*NOR*/  r[rd]=~(r[rs]|r[rt]);     break;
        case 0x2a:/*SLT*/  r[rd]=r[rs]<r[rt];        break;
        case 0x2b:/*SLTU*/ r[rd]=u[rs]<u[rt];        break;
        case 0x2d:/*DADDU*/r[rd]=r[rs]+u[rt];        break;
        case 0x31:/*TGEU*/ break;
        case 0x32:/*TLT*/  break;
        case 0x33:/*TLTU*/ break;
        case 0x34:/*TEQ*/  break;
        case 0x36:/*TNE*/  break;
        default:
            reserved_opcode(epc, opcode, s);
        }
        break;
    case 0x01:/*REGIMM*/
        switch(rt){
            case 0x10:/*BLTZAL*/ r[31]=s->pc_next; link=1;
            case 0x00:/*BLTZ*/   branch=r[rs]<0;    break;
            case 0x11:/*BGEZAL*/ r[31]=s->pc_next; link=1;
            case 0x01:/*BGEZ*/   branch=r[rs]>=0;   break;
            case 0x12:/*BLTZALL*/r[31]=s->pc_next; link=1;
            case 0x02:/*BLTZL*/  lbranch=r[rs]<0;   break;
            case 0x13:/*BGEZALL*/r[31]=s->pc_next; link=1;
            case 0x03:/*BGEZL*/  lbranch=r[rs]>=0;  break;
            default: printf("ERROR1\n"); s->wakeup=1;
        }
        break;
    case 0x03:/*JAL*/    r[31]=s->pc_next; log_call(((s->pc&0xf0000000)|target), epc);
    case 0x02:/*J*/      delay_slot=1;
                       s->pc_next=(s->pc&0xf0000000)|target; break;
    case 0x04:/*BEQ*/    branch=r[rs]==r[rt];     break;
    case 0x05:/*BNE*/    branch=r[rs]!=r[rt];     break;
    case 0x06:/*BLEZ*/   branch=r[rs]<=0;         break;
    case 0x07:/*BGTZ*/   branch=r[rs]>0;          break;
    case 0x08:/*ADDI*/   r[rt]=r[rs]+(short)imm;  break;
    case 0x09:/*ADDIU*/  u[rt]=u[rs]+(short)imm;  break;
    case 0x0a:/*SLTI*/   r[rt]=r[rs]<(int)(short)imm; break;
    case 0x0b:/*SLTIU*/  u[rt]=u[rs]<(imm & 0x0000ffff); break;
    case 0x0c:/*ANDI*/   r[rt]=r[rs]&imm;         break;
    case 0x0d:/*ORI*/    r[rt]=r[rs]|imm;         break;
    case 0x0e:/*XORI*/   r[rt]=r[rs]^imm;         break;
    case 0x0f:/*LUI*/    r[rt]=(imm<<16);         break;
    case 0x10:/*COP0*/
        if(KERNEL_MODE){
            //fprintf(s->t.log, "STATUS = %08x\n", s->cp0_status);
            if(opcode==0x42000010){  // rfe -- not MIPS32 really.
                unimplemented(s,"RFE");
            }
            if(opcode==0x42000018){  // eret
                s->skip = 0;
                s->eret_delay_slot = 1;
                s->pc_next = s->epc;
                //printf("ERET to %08xh, STATUS = %08x\n", s->pc_next, s->cp0_status);
                /* Now, if ERL is set... */
                if (s->cp0_status & SR_ERL) {
                    s->cp0_status &= (~SR_ERL); /* ...clear ERL... */
                }
                else {
                    s->cp0_status &= (~SR_EXL); /* ...otherwise clear EXL */
                }
                //printf("ERET :: STATUS = %08x\n", s->cp0_status);
            }
            else if((opcode & (1<<23)) == 0){  //move from CP0 (mfc0)
                switch(rd){
                    case 8: r[rt] = 0; break; // FIXME BadVAddr
                    case 9: r[rt] = 0; break; // FIXME Count
                    case 11: r[rt] = 0; break; // FIXME Compare
                    case 12: r[rt]=(s->cp0_status & STATUS_MASK); break;
                    case 13: r[rt]=(s->cp0_cause & CAUSE_MASK); break;
                    case 14: r[rt]=s->epc; break;
                    case 15: r[rt]=CPU_ID; break;
                    case 16:
                            if ((func&0x07)==0) {
                                r[rt]=s->cp0_config0;
                            } else {
                                r[rt] = 0;
                            }; break;
                    case 30: r[rt] = s->cp0_errorpc;
                    default:
                        /* FIXME log access to unimplemented CP0 register */
                        printf("mfc0 [%02d]->%02d @ [0x%08x]\n", rd, rt,s->pc);
                        break;
                }
            }
            else{                         //move to CP0 (mtc0)
                switch (rd){
                    case 11: s->cp0_compare = r[rt]; break;
                    case 12: s->sr_load_pending_value = r[rt];
                             s->sr_load_pending = true;
                             fprintf(s->t.log, "(%08x) [01]=%08x\n", 0x0 /* log_pc */, r[rt] & STATUS_MASK);
                             break;
                    case 13: s->cp0_cause = r[rt] & CAUSE_MASK; break;
                    case 16:
                        if ((func&0x07)==0) {
                            s->cp0_config0 = r[rt] & 0x00030000;
                        }
                        else {
                            printf("mtc0 [%2d.%2d]=0x%08x @ [0x%08x] IGNORED\n",
                                   rd, rs, r[rt], epc);
                        }; break;
                    default:
                        /* Move to unimplemented/RO register: display warning */
                        /* FIXME should log ignored move */
                        printf("mtc0 [%2d]=0x%08x @ [0x%08x] IGNORED\n",
                                rd, r[rt], epc);
                }
            }
        }
        else{
            /* tried to execute mtc* or mfc* in user mode: trap */
            s->trap_cause = 11; /* unavailable coprocessor */
        }
        break;
    case 0x11:/*COP1*/ unimplemented(s,"COP1");  break;
    case 0x12:/*COP2*/ cop2(s,opcode); break;
    case 0x13:/*COP3*/ unimplemented(s,"COP3");  break;
    case 0x14:/*    */  lbranch=r[rs]==r[rt];    break;
    case 0x15:/*BNEL*/  lbranch=r[rs]!=r[rt];    break;
    case 0x16:/*BLEZL*/ lbranch=r[rs]<=0;        break;
    case 0x17:/*BGTZL*/ lbranch=r[rs]>0;         break;
    case 0x1c:/*SPECIAL2*/
        /* MIPS32r1 opcodes implemented, r2 unimplemented. */
        switch(func){
            case 0x00: /* MADD */ mult_big_signed(r[rs],r[rt],&s->hi,&s->lo,1); break;
            case 0x01: /* MADDU */ mult_big(r[rs],r[rt],&s->hi,&s->lo,1); break;
            case 0x20: /* CLZ */ r[rt] = count_leading(0, r[rs]); break;
            case 0x21: /* CLO */ r[rt] = count_leading(1, r[rs]); break;
            case 0x02: /* MUL */ r[rd] = mult_gpr(r[rs], r[rt]); break;
            default:
                reserved_opcode(epc, opcode, s);
                unimplemented(s, "SPECIAL2");
        }
        break;
    case 0x1f: /* SPECIAL3 */
        if(cmd_line_args.emulate_some_mips32){
            switch(func){
                case 0x00: /* EXT */ r[rt] = ext_bitfield(r[rs], opcode); break;
                case 0x04: /* INS */ r[rt] = ins_bitfield(r[rt], r[rs], opcode); break;
                default:
                    reserved_opcode(epc, opcode, s);
                    unimplemented(s, "SPECIAL3");
            }
        }
        else{
            reserved_opcode(epc, opcode, s);
        }
        break;
    case 0x20:/*LB*/    //r[rt]=(signed char)mem_read(s,1,ptr,1);  break;
                        start_load(s, ptr, rt,(signed char)mem_read(s,1,ptr,1), 1);
                        break;

    case 0x21:/*LH*/    //r[rt]=(signed short)mem_read(s,2,ptr,1); break;
                        start_load(s, ptr, rt, (signed short)mem_read(s,2,ptr,1), 2);
                        break;
    case 0x22:/*LWL*/   mem_lwl(s, ptr, rt, 1);
                        //printf("LWL\n");
                        break;
    case 0x23:/*LW*/    //r[rt]=mem_read(s,4,ptr,1);   break;
                        start_load(s, ptr, rt, mem_read(s,4,ptr,1), 4);
                        break;
    case 0x24:/*LBU*/   //r[rt]=(unsigned char)mem_read(s,1,ptr,1); break;
                        start_load(s, ptr, rt, (unsigned char)mem_read(s,1,ptr,1), 1);
                        break;
    case 0x25:/*LHU*/   //r[rt]= (unsigned short)mem_read(s,2,ptr,1);
                        start_load(s, ptr, rt, (unsigned short)mem_read(s,2,ptr,1), 2);
                        break;
    case 0x26:/*LWR*/   mem_lwr(s, ptr, rt, 1);
                        //printf("LWR\n");
                        break;
    case 0x28:/*SB*/    mem_write(s,1,ptr,r[rt],1);  break;
    case 0x29:/*SH*/    mem_write(s,2,ptr,r[rt],1);  break;
    case 0x2a:/*SWL*/   mem_swl(s, ptr, r[rt], 1);
                        //printf("SWL\n");
                        break;
    case 0x2b:/*SW*/    mem_write(s,4,ptr,r[rt],1);  break;
    case 0x2e:/*SWR*/   mem_swr(s, ptr, r[rt], 1);
                        //printf("SWR\n");
                        break;
    case 0x2f:/*CACHE*/ /* Since we don´t simulate the caches, the cache
                        instruction will be ignored. It is implemented as
                        a NOP. */
                        /* FIXME check operation code. */
                        // unimplemented(s,"CACHE");
                        break;
    case 0x30:/*LL*/    //unimplemented(s,"LL");
                        start_load(s, ptr, rt, mem_read(s,4,ptr,1), 4);
                        break;
//      case 0x31:/*LWC1*/ break;
    case 0x32:/*LWC2*/  aux = start_load(s, ptr, -1, mem_read(s,4,ptr,1), 4);
                        cop2_set_reg(s, rt, 0, 0, aux);
                        break;
//      case 0x33:/*LWC3*/ break;
//      case 0x35:/*LDC1*/ break;
//      case 0x36:/*LDC2*/ break;
//      case 0x37:/*LDC3*/ break;
//      case 0x38:/*SC*/     *(int*)ptr=r[rt]; r[rt]=1; break;
    case 0x38:/*SC*/    mem_write(s,4,ptr,r[rt],1); r[rt]=1; break;
//      case 0x39:/*SWC1*/ break;
    case 0x3a:/*SWC2*/  aux = cop2_get_reg(s, rt, 0, 0);
                        mem_write(s,4,ptr,aux,1);
                        break;
//      case 0x3b:/*SWC3*/ break;
//      case 0x3d:/*SDC1*/ break;
//      case 0x3e:/*SDC2*/ break;
//      case 0x3f:/*SDC3*/ break;
    default:  /* unimplemented opcode */
        reserved_opcode(epc, opcode, s);
        unimplemented(s, "???");
    }

    /* */
    if((branch || lbranch == 1) && link){
        log_call(s->pc_next + imm_shift, epc);
    }

    /* adjust next PC if this was a a jump instruction */
    s->pc_next += (branch || lbranch == 1) ? imm_shift : 0;
    s->pc_next &= ~3;
    //s->skip = (lbranch == 0); // FIXME experiment

    /* If there was trouble (failed assertions), log it */
    if(s->failed_assertions!=0){
        log_failed_assertions(s);
        s->failed_assertions=0;
    }

    /* if there's a delayed load pending, do it now: load reg with memory data*/
    /* load delay slots not simulated */

    /* Handle exceptions, software and hardware */
    /* Software-triggered traps have priority over HW interrupts, IIF they
       trigger in the same clock cycle. */
    process_traps(s, epc, rSave, rt);

    /* if we're NOT showing output to console, log state of CPU to file */
    if(!show_mode){
        s->wakeup |= log_cycle(s);
    }

    /* if this instruction was any kind of branch that actually jumped, then
       the next instruction will be in a delay slot. Remember it. */
    delay_slot = ((lbranch==1) || branch || delay_slot);
    s->delay_slot = delay_slot;
}

/** Print opcode fields for easier debugging */
void print_opcode_fields(uint32_t opcode){
    uint32_t field;

    field = (opcode >> 26)&0x3f;
    printf("%02x:", field);
    field = (opcode >> 21)&0x1f;
    printf("%02x:", field);
    field = (opcode >> 16)&0x1f;
    printf("%02x:", field);
    field = (opcode >> 11)&0x1f;
    printf("%02x:", field);
    field = (opcode >>  6)&0x1f;
    printf("%02x:", field);
    field = (opcode >>  0)&0x3f;
    printf("%02x",  field);
}

/** Deal with reserved, unimplemented opcodes. Updates s->trap_cause. */
void reserved_opcode(uint32_t pc, uint32_t opcode, t_state* s){
    if(cmd_line_args.trap_on_reserved){
        s->trap_cause = 10; /* reserved instruction */
    }
    else{
        printf("RESERVED OPCODE [0x%08x] = 0x%08x %c -- ",
                pc, opcode, (s->delay_slot? 'D':' '));
        print_opcode_fields(opcode);
        printf("\n");
    }
}


/** Dump CPU state to console */
void show_state(t_state *s){
    int i,j;
    printf("pid=%d userMode=%d, epc=0x%x\n", 0, 0, s->epc);
    printf("hi=0x%08x lo=0x%08x\n", s->hi, s->lo);

    /* print register values */
    #if FANCY_REGISTER_DISPLAY
    printf(" v = [%08x %08x]  ", s->r[2], s->r[3]);
    printf("           a = [");
    for(i=4;i<8;i++){
        printf("%08x ", s->r[i]);
    }
    printf("]\n");
    printf(" s = [");
    for(i=16;i<24;i++){
        printf("%08x ", s->r[i]);
    }
    printf("]\n");
    printf(" t = [");
    for(i=8;i<16;i++){
        printf("%08x ", s->r[i]);
    }
    printf("-\n");
    printf("      %08x %08x]  ", s->r[24], s->r[25]);
    printf("                          ");
    printf("  k = [ %08x %08x ]\n", s->r[26], s->r[27]);
    printf(" gp = %08x     sp = %08x    ", s->r[28], s->r[29]);
    printf(" fp = %08x     ra = %08x ", s->r[30], s->r[31]);
    printf("\n\n");
    #else
    for(i = 0; i < 4; ++i){
        printf("%2.2d ", i * 8);
        for(j = 0; j < 8; ++j){
            printf("%8.8x ", s->r[i*8+j]);
        }
        printf("\n");
    }
    #endif

    j = s->pc; /* save pc value (it's altered by the 'cycle' function) */
    for(i = -4; i <= 8; ++i){
        printf("%c", i==0 ? '*' : ' ');
        s->pc = j + i * 4;
        cycle(s, 10);
    }
    s->t.disasm_ptr = s->pc; /* executing code updates the disasm pointer */
    s->pc = j; /* restore pc value */
}

/*-- Simulated COP2 interface (for CPU testing only) -------------------------*/

static uint32_t cop2_get_reg(t_state *s,
    uint32_t rcop, uint32_t sel, bool ctrl){
    if (ctrl) rcop += 32;
    return s->cop2.r[rcop];
}

static void cop2_set_reg(t_state *s,
    uint32_t rcop, uint32_t sel, bool ctrl, uint32_t data){
    if (ctrl) rcop += 32;
    s->cop2.r[rcop] = data;
}

static void cop2_read( t_state *s,
    uint32_t rcop, uint32_t sel, bool control,
    int32_t cofun, uint32_t rcpu) {

    s->r[rcpu] = cop2_get_reg(s, rcop, sel, control);

    //printf("CPU[%d] <- COP2[%d,%d] (%08x)\n", rcpu, rcop, sel, s->r[rcpu]);
}

static void cop2_write(t_state *s,
    uint32_t rcop, uint32_t sel, bool control,
    int32_t cofun, uint32_t rcpu) {
    uint32_t cpu_data;

    cpu_data = s->r[rcpu];
    if (!control) cpu_data = (sel << 29) | (cpu_data & 0x1fffffff);

    cop2_set_reg(s, rcop, sel, control, cpu_data);

    //printf("COP2[%d,%d] <- CPU[%d] (%08x)\n", rcop, sel, rcpu, cpu_data);
}

//static void cop2_execute(t_state *s, uint32_t cofun) {
//
//}

void cop2(t_state *s, uint32_t opcode) {
    uint32_t function, rcpu, rcop, sel;
    uint16_t impl;

    function = (opcode >> 21) & 0x1f;
    impl = (opcode >> 21) & 0x1f;
    rcpu = (opcode >> 16) & 0x1f;
    rcop = (opcode >> 11) & 0x1f;
    sel = (opcode >> 0) & 0x7;

    switch(function) {
    case 0:     /* MFC2 */
        cop2_read(s, rcop, sel, 0, -1, rcpu);
        break;
    case 2:     /* CFC2 */
        cop2_read(s, rcop, sel, 1, -1, rcpu);
        break;
    case 4:     /* MTC2 */
        cop2_write(s, rcop, sel, 0, -1, rcpu);
        break;
    case 6:     /* CTC2 */
        cop2_write(s, rcop, sel, 1, -1, rcpu);
        break;
    default:
        // Unimplemented COP2 opcode.
        printf("COP2 (%08x)\n", opcode);
        (void) unimplemented(s, "COP2");
        break;
    }
}



/** Logs last cycle's activity (changes in state and/or loads/stores) */
uint32_t log_cycle(t_state *s){
    static unsigned int last_pc = 0;
    int i;
    uint32_t log_pc;

    /* store PC in trace buffer only if there was a jump */
    if(s->pc != (last_pc+4)){
        s->t.buf[s->t.next] = s->pc;
        s->t.next = (s->t.next + 1) % TRACE_BUFFER_SIZE;
    }
    last_pc = s->pc;
    log_pc = s->op_addr;


    /* if file logging is enabled, dump a trace log to file */
    if(log_enabled(s)){

        /* skip register zero which does not change */
        for(i=1;i<32;i++){
            if(s->t.pr[i] != s->r[i]){
                fprintf(s->t.log, "(%08x) [%02x]=%08x\n", log_pc, i, s->r[i]);
            }
            s->t.pr[i] = s->r[i];
        }
        if(s->lo != s->t.lo){
            //fprintf(s->t.log, "(%08x) [LO]=%08x\n", log_pc, s->lo);
        }
        s->t.lo = s->lo;

        if(s->hi != s->t.hi){
            //fprintf(s->t.log, "(%08x) [HI]=%08x\n", log_pc, s->hi);
        }
        s->t.hi = s->hi;

        /* Catch changes in EPC by direct write (mtc0) and by exception */
        // TODO actually, log only MTC0
        //if(s->epc != s->t.epc){
        //    fprintf(s->t.log, "(%08x) [03]=%08x\n", log_pc, s->epc);
        //}
        s->t.epc = s->epc;

        if(s->cp0_status != s->t.status){
            // TODO we'll only log status changes caused by MTC0.
            #if 0
            fprintf(s->t.log, "(%08x) [01]=%08x\n", 0x0 /* log_pc */, s->cp0_status & STATUS_MASK);
            #endif
        }
        s->t.status = s->cp0_status & STATUS_MASK;

        // When SR is loaded via a MTC0, the load is delayed by one cycle.
        // We update the register after checking for a change (above), so the
        // logged value will be correct.
        if (s->sr_load_pending) {
            s->cp0_status = s->sr_load_pending_value & STATUS_MASK;
            s->sr_load_pending = false;
        }

    }

#if 0
    /* FIXME Try to detect a code crash by looking at SP */
    if(1){
            if((s->r[29]&0xffff0000) == 0xffff00000){
                printf("SP derailed! @ 0x%08x [0x%08x]\n", log_pc, s->r[29]);
                return 1;
            }
    }
#endif

    return 0;
}

/** Logs a message for each failed assertion, each in a line */
void log_failed_assertions(t_state *s){
    unsigned bitmap = s->failed_assertions;
    int i = 0;

    /* This loop will crash the program if the message table is too short...*/
    if(s->t.log != NULL){
        for(i=0;i<32;i++){
            if(bitmap & 0x1){
                fprintf(s->t.log, "ASSERTION FAILED: [%08x] %s\n",
                        s->faulty_address,
                        assertion_messages[i]);
            }
            bitmap = bitmap >> 1;
        }
    }
}

uint32_t log_enabled(t_state *s){
    return ((s->t.log != NULL) && (s->t.log_triggered!=0));
}

void trigger_log(t_state *s){
    uint32_t i;

    s->t.log_triggered = 1;

    for(i=0;i<32;i++){
        s->t.pr[i] = s->r[i];
    }

    s->t.lo = s->lo;
    s->t.hi = s->hi;
    s->t.epc = s->epc;
}


void free_cpu(t_state *s){
    int i;

    for(i=0;i<NUM_MEM_BLOCKS;i++){
        free(s->blocks[i].mem);
        s->blocks[i].mem = NULL;
    }
}

void reset_cpu(t_state *s){
    s->cp0_cause = 0;
    s->cp0_compare = 0;
    s->cp0_config0 = CP0_CONFIG0;
    s->sr_load_pending = false;

    s->pc = cmd_line_args.start_addr; /* reset start vector or cmd line address */
    s->delay_slot = 0;
    s->eret_delay_slot = 0;
    s->failed_assertions = 0; /* no failed assertions pending */
    s->cp0_status = SR_BEV | SR_ERL;
    s->instruction_ctr = 0;
    s->inst_ctr_prescaler = 0;
    s->t.irq_trigger_countdown = -1;
    s->t.irq_trigger_inputs = 0;
    s->t.irq_current_inputs = 0;
    /* init trace struct to prevent spurious logs */
    s->t.status = s->cp0_status;
}

/* FIXME redundant function, merge with reserved_opcode */
void unimplemented(t_state *s, const char *txt){
    printf("[%08x] UNIMPLEMENTED: %s\n", s->epc, txt);
    if(cmd_line_args.stop_on_unimplemented) exit(1);
}

int init_cpu(t_state *s, t_args *args){
    int i, j;
    uint32_t k = args->memory_map;

    memset(s, 0, sizeof(t_state));
    s->big_endian = 1;

    s->do_unaligned = args->do_unaligned;
    s->breakpoint = args->breakpoint;

    /* Initialize memory map */
    for(i=0;i<NUM_MEM_BLOCKS;i++){
        s->blocks[i].start =        memory_maps[k].blocks[i].start;
        s->blocks[i].size =         memory_maps[k].blocks[i].size;
        s->blocks[i].area_name =    memory_maps[k].blocks[i].area_name;
        s->blocks[i].mask =         memory_maps[k].blocks[i].mask;
        s->blocks[i].flags =        memory_maps[k].blocks[i].flags;

        s->blocks[i].mem = (unsigned char*)malloc(s->blocks[i].size);

        if(s->blocks[i].mem == NULL){
            for(j=0;j<i;j++){
                free(s->blocks[j].mem);
            }
            return 0;
        }
        memset(s->blocks[i].mem, 0, s->blocks[i].size);
    }
    return NUM_MEM_BLOCKS;
}
