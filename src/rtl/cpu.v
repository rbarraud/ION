/**
    MIPS32r1 CPU.

    Conventional 5-stage MIPS32r1 implementation. 
    Optimized for ease of development and maintenance. 


    UNFINISHED!
    ~~~~~~~~~~~

    Major stuff remains to be done:

        - COP0 & supervisor mode stuff partially implemented.
        - Interrupt logic partially implemented.
        - Many instructions missing.
        - No support for wait states in code or data buses.

    I started this module as a minimal riscv implementation. I've morphed it 
    into a MIPS32 but many riscv traces remain, mostly around COP0 registers
    (called CSR here).


    Signal naming convention
    ~~~~~~~~~~~~~~~~~~~~~~~~

    Signals are prefixed according th the pipeline stage they belong to:

        sX_*    - Combinational signal within stage X.
        sXYr_*  - Register, input from stage X, output to stage Y.
        co_*    - Combinational signal, control logic outside pipeline.
        cor_*   - Register, control logic outside pipeline.

*/

module cpu
    #(
        parameter OPTION_RESET_ADDR = 32'hbfc00000,
        parameter OPTION_TRAP_ADDR =  32'hbfc00180
    )
    (
        input               CLK,
        input               RESET_I,

        output      [31:0]  CADDR_O,
        output      [1:0]   CTRANS_O,
        input       [31:0]  CRDATA_I,
        input               CREADY_I,
        input       [1:0]   CRESP_I,

        output      [31:0]  DADDR_O,
        output      [1:0]   DTRANS_O,
        output      [2:0]   DSIZE_O,
        input       [31:0]  DRDATA_I,
        output      [31:0]  DWDATA_O,
        output              DWRITE_O,
        input               DREADY_I,
        input       [1:0]   DRESP_I,

        input       [4:0]   HWIRQ_I
    );

    //==== Local parameters ====================================================

    localparam FEATURE_PRID =           32'h00000000;
    localparam FEATURE_CONFIG0 =        32'h00000000;
    localparam FEATURE_CONFIG1 =        32'h00000000;

    // Translated indices of writeable CSRs.
    localparam CSRB_MCOMPARE =          4'b0000;
    localparam CSRB_MSTATUS =           4'b0001;
    localparam CSRB_MCAUSE =            4'b0010;
    localparam CSRB_MEPC =              4'b0011;
    localparam CSRB_MCONFIG0 =          4'b0100;
    localparam CSRB_MERROREPC =         4'b0101;

    localparam EN_ALWAYS = 1'b1;

    localparam TYP_J =      4'b0000; 
    localparam TYP_B =      4'b0001;
    localparam TYP_I =      4'b0010;
    localparam TYP_M =      4'b0011;
    localparam TYP_S =      4'b0100;
    localparam TYP_R =      4'b0101;
    localparam TYP_P =      4'b0110;
    localparam TYP_T =      4'b0111;
    localparam TYP_E =      4'b1000;
    localparam TYP_IH =     4'b1001;
    localparam TYP_IU =     4'b1010;
    localparam TYP_BAD =    4'b1111;

    localparam P0_0 =       3'b000;
    localparam P0_RS1 =     3'b001;
    localparam P0_PC =      3'b010;
    localparam P0_PCS =     3'b011;
    localparam P0_IMM =     3'b100;
    localparam P0_X =       3'b000;
    localparam P1_0 =       2'b00;
    localparam P1_RS2 =     2'b01;
    localparam P1_CSR =     2'b10;
    localparam P1_IMM =     2'b11;
    localparam P1_X =       2'b00;

    localparam OP_NOP =     5'b00000;
    localparam OP_SLL =     5'b00100;
    localparam OP_SRL =     5'b00110;
    localparam OP_SRA =     5'b00111;
    localparam OP_ADD =     5'b10000;
    localparam OP_SUB =     5'b10001;
    localparam OP_SLT =     5'b10101;
    localparam OP_SLTU =    5'b10111;
    localparam OP_OR =      5'b01000;
    localparam OP_AND =     5'b01001;
    localparam OP_XOR =     5'b01010;
    localparam OP_NOR =     5'b01011;

    localparam WB_R =       2'b10;
    localparam WB_N =       2'b00;
    localparam WB_C =       2'b01;


    //==== Register macros -- all DFFs inferred using these ====================

    `define PREG(st, name, resval, enable, loadval) \
        always @(posedge CLK) \
            if (RESET_I) \
                name <= resval; \
            else if(enable & ~st) \
                name <= loadval;

    `define PREGC(st, name, resval, enable, loadval) \
        always @(posedge CLK) \
            if (RESET_I || ~enable) \
                name <= resval; \
            else if(enable & ~st) \
                name <= loadval;

    `define CSREGT(st, name, resval, trapen, trapval, loadval) \
        always @(posedge CLK) \
            if (RESET_I) \
                s42r_csr_``name <= resval; \
            else begin \
                if (s4_en & ~st & trapen) \
                    s42r_csr_``name <= trapval; \
                else if (s4_en & s34r_wb_csr_en & (s34r_csr_xindex==CSRB_``name)) \
                    s42r_csr_``name <= loadval; \
            end 

    `define CSREG(st, name) \
        always @(posedge CLK) \
            if (RESET_I) \
                s42r_csr_``name <= 32'h0; \
            else if (s4_en & ~st & s34r_wb_csr_en & (s34r_csr_xindex==CSRB_``name)) \
                s42r_csr_``name <= s34r_alu_res; 


    // FIXME Per-machine CSRs unimplemented
    `define CSREGM(st, name)


    //==== Per-machine state registers =========================================

    // COP0 registers. @note6.
    reg [16:0] s42r_csr_MCAUSE;
    reg [12:0] s42r_csr_MSTATUS;
    reg [31:0] s42r_csr_MEPC;
    reg [31:0] s42r_csr_MIP; // FIXME merge into CAUSE
    reg [31:0] s42r_csr_MERROREPC;
    reg [31:0] s42r_csr_MCOMPARE;
    // Register bank.
    reg [31:0] s42r_rbank [0:31];
    // PC bank.
    reg [31:0] s20r_pc_nonseq;

    // These macros unpack COP0 regs into useful names.
    `define STATUS_BEV          s42r_csr_MSTATUS[12]
    `define STATUS_IM           s42r_csr_MSTATUS[11:4]
    `define STATUS_UM           s42r_csr_MSTATUS[3]
    `define STATUS_ERL          s42r_csr_MSTATUS[2]
    `define STATUS_EXL          s42r_csr_MSTATUS[1]
    `define STATUS_IE           s42r_csr_MSTATUS[0]
    `define STATUS_PACK(w)      {w[22],w[15:8],w[4],w[2],w[1],w[0]}
    `define STATUS_UNPACK(p)    {9'h0,p[12],6'h0,p[11:4],3'h0,p[3:0]}
    `define CAUSE_BD            s42r_csr_MCAUSE[16]
    `define CAUSE_CE            s42r_csr_MCAUSE[15:14]
    `define CAUSE_IV            s42r_csr_MCAUSE[13]
    `define CAUSE_IPHW          s42r_csr_MCAUSE[12:7]
    `define CAUSE_IPSW          s42r_csr_MCAUSE[6:5]
    `define CAUSE_EXCODE        s42r_csr_MCAUSE[4:0]
    `define CAUSE_PACK(w)       {w[31],w[29:28],w[23],w[15:8],w[6:2]}
    `define CAUSE_UNPACK(p)     {p[16],1'b0,p[15:14],4'b0,p[13],7'b0,p[12:5],1'b0,p[4:0],2'b0}



    //==== Forward declaration of control signals ==============================

    reg co_s0_en;               // FAddr stage enable.
    reg co_s0_bubble;           // Insert bubble in FAddr stage.
    reg co_s1_bubble;           // Insert bubble in FData stage.
    reg co_s2_bubble;           // Insert bubble in Decode stage.
    reg s0_st, s1_st, s2_st, s3_st, s4_st;  // Per-stage stall controls.


    //==== Pipeline stage 0 -- Fetch-Address ===================================
    // Address phase of fetch cycle.     

    reg [31:0] s0_pc_fetch;     // Fetch address (PC of next instruction).
    reg s01r_en;                // FData stage enable carried from FAaddr.
    reg [31:0] s01r_pc;         // PC of instr in FData stage.
    reg [31:0] s01r_pc_seq;     
    

    // Fetch address mux: sequential or non sequential.
    always @(*) begin
        s0_pc_fetch = s2_go_seq? s01r_pc_seq : s2_pc_nonseq;
    end

    assign CADDR_O = s0_pc_fetch;
    assign CTRANS_O = co_s0_en? 2'b10 : 2'b00;

    // FA-FD pipeline registers.
    `PREG (1'b0,  s01r_en, 1'b0, EN_ALWAYS, co_s0_en)
    `PREG (s0_st, s01r_pc, OPTION_RESET_ADDR-4, co_s0_en, s0_pc_fetch)
    `PREG (s0_st, s01r_pc_seq, OPTION_RESET_ADDR, co_s0_en, s0_pc_fetch + 4)


    //==== Pipeline stage 1 -- Fetch-Data ======================================
    // Data phase of fetch cycle.

    reg s1_en;                  // FD stage enable.
    reg s12r_en;                // Decode stage enable carried from FData.
    reg [31:0] s12r_ir;         // Instruction register (valid in stage DE).
    reg [31:0] s12r_irs;        // FIXME explain.
    reg [31:0] s12r_pc;         // PC of instruction in DE stage.
    reg [31:0] s12r_pc_seq;     // PC of instr following fdr_pc_de one.
    reg s12r_continue;
    reg [31:0] s1_ir;           // Mux at input of IR reg.

    always @(*) begin
        // FIXME only if cycle is complete?
        s1_en = s01r_en & ~co_s1_bubble;
        s1_ir = s12r_continue? s12r_irs : CRDATA_I; // @note1
    end

    // Load IR from code bus (if cycle is complete) OR saved IR after a stall.
    `PREG (s1_st, s12r_ir, 32'h0, s1_en & CREADY_I, s1_ir)
    // When stage 1 is stalled, save IR to be used after end of stall.
    `PREG (1'b0,  s12r_irs, 32'h0, s1_en & CREADY_I & s1_st, CRDATA_I)
    // Will pulse high after a data-hazard-stall.
    `PREG (1'b0,  s12r_continue, 1'b0, 1'b1, s1_st)

    // FD-DE pipeline registers.
    `PREG (1'b0,  s12r_en, 1'b0, EN_ALWAYS, s1_en)
    `PREG (s1_st, s12r_pc, OPTION_RESET_ADDR, s1_en, s01r_pc)
    `PREG (s1_st, s12r_pc_seq, OPTION_RESET_ADDR, s1_en, s01r_pc_seq)
    

    //==== Pipeline stage Decode ===============================================
    // Last stage of Fetch pipeline, first of Execute pipeline.
    // PC flow logic / IR decoding / RBank read.

    reg [31:0] s23r_arg0;       // ALU arg0.
    reg [31:0] s23r_arg1;       // ALU arg1.
    reg s23r_wb_en;             // Writeback enable (main reg bank).
    reg s23r_wb_csr_en;         // Writeback enable (CSR reg bank).
    reg [3:0] s23r_csr_xindex;  // Index (translated) of target CSR if any.
    reg [4:0] s23r_rd_index;    // Index of target register if any.
    reg [4:0] s23r_alu_op;      // ALU operation.
    reg [31:0] s23r_mem_addr;   // MEM address.
    reg [1:0] s23r_mem_trans;   // MEM transaction type.
    reg [1:0] s23r_mem_size;    // MEM transaction size.
    reg s23r_store_en;          // Active for store MEM cycle.
    reg s23r_load_en;           // Active for load MEM cycle.
    reg [31:0] s23r_mem_wdata;  // MEM write data.
    reg s23r_load_exz;          // 1 if MEM subword load zero-extends to word.
    reg s23r_trap;              // TRAP event CSR control passed on to EX.
    reg s23r_eret;              // ERET event CSR control passed on to EX.
    reg [4:0] s23r_trap_cause;  // Trap cause code passed on to EX.
    reg [31:0] s23r_epc;        // Next EPC to be passed on to next stages.

    reg s2_en;                  // DE stage enable.
    reg s23r_en;                // Execute stage enable carried over from Dec.
    reg [31:0] s2_pc_nonseq;    // Next PC if any possible jump is taken.
    reg [5:0] s2_opcode;        // IR opcode field.
    reg [2:0] s2_func3;         // IR func3 field.
    reg [4:0] s2_rs1_index;     // Index for RS1 from IR.
    reg [4:0] s2_rs2_index;     // Index for RS2 from IR.
    reg [4:0] s2_rd_index;      // Index for RD from IR.
    reg [7:0] s2_csr_index;     // Index for CSR from IR (Reg index + sel).
    reg [3:0] s2_csr_xindex;    // Index for CSR translated.
    reg [27:0] s2_m;            // Concatenation of other signals for clarity.
    reg [3:0] s2_type;          // Format of instruction in IR.
    reg s2_link;                // Save PC to r31.
    reg [2:0] s2_p0_sel;        // ALU argument 0 selection.
    reg [1:0] s2_p1_sel;        // ALU argument 1 selection.
    reg s2_wb_en;               // Writeback enable for reg bank.
    reg s2_wb_csr_en;           // Writeback enable for CSR.
    reg [1:0] s2_alu_sel;       // Select ALU operation (hardwired/IR).
    reg [4:0] s2_alu_op;        // ALU operation fully decoded.
    reg [4:0] s2_alu_op_f3;     // ALU operation as encoded in func3 (IMM).
    reg [4:0] s2_alu_op_csr;    // ALU operation for CSR instructions.
    reg s2_alu_en;              // ALU operation is actually used.

    reg s2_invalid;             // IR is invalid;
    reg [1:0] s2_flow_sel;      // {00,01,10,11} = {seq/trap, JALR, JAL, Bxx}.
    reg s2_cop0_access;         // COP0 access instruction in IR.
    reg s2_user_mode;           // 1 -> user mode, 0 -> kernel mode.
    reg s2_trap_break_syscall;  // Trap caused by BREAK or SYSCALL instruction.
    reg s2_trap_cop_unusable;   // Trap caused by COP access in user mode.
    reg s2_trap;                // Take trap for any cause.
    reg s2_eret;                // ERET instruction.
    reg [4:0] s2_trap_cause;    // Trap cause code.

    reg [31:0] s2_pc_branch;    // Branch target;
    reg [31:0] s2_pc_jump;      // Jump (JAL) target;
    reg [31:0] s2_pc_jalr;      // Jump (JALR) target;
    reg [31:0] s2_pc_trap_eret; // Trap/ERET PC target.

    reg [31:0] s2_j_immediate;  // Immediate value from J-type IR.
    reg [31:0] s2_b_immediate;  // Immediate value from B-type IR.
    reg [31:0] s2_s_immediate;  // Immediate value from S-type IR.
    reg [31:0] s2_i_immediate;  // Immediate value from I-type IR.
    reg [31:0] s2_ih_immediate; // Immediate value from IH-type IR.
    reg [31:0] s2_iu_immediate; // Immediate value from IU-type IR.
    reg [31:0] s2_e_immediate;  // Immediate value from E-type IR.
    reg [31:0] s2_t_immediate;  // Immediate value from T-type IR.
    reg [31:0] s2_immediate;    // Immediate value used in Execute stage.
    reg [31:0] s2_cop_imm;      // Immediate value for trap-related instructions.

    reg [31:0] s2_csr;          // CSR value read from CSR bank.
    reg [31:0] s2_rs1_bank;     // Register RS1 value read from bank.
    reg [31:0] s2_rs2_bank;     // Register RS2 value read from bank.
    reg [31:0] s2_rs1;          // Register RS1 value after FFWD mux.
    reg [31:0] s2_rs2;          // Register RS2 value after FFWD mux.    
    reg s2_rs12_equal;          // RS1 == RS2.
    reg s2_bxx_cond_val;        // Set if Bxx condition is true.
    reg [2:0] s2_bxx_cond_sel;  // Selection of branch condition.
    reg [31:0] s2_arg0;         // ALU arg0 selection mux.
    reg [31:0] s2_arg1;         // ALU arg1 selection mux.
    reg s2_3reg;                // 1 in 3-reg formats, 0 in others.
    reg [31:0] s2_mem_addr;     // MEM address for load/store ops.
    reg [31:0] s2_mem_addr_imm; // Immediate value used to compute mem address.
    reg [1:0] s2_mem_trans;     // MEM transaction type.
    reg [1:0] s2_mem_size;      // MEM transaction size.
    reg s2_load_exz;            // 1 if MEM subword load zero-extends to word. 
    reg s2_load_en;             // MEM load.
    reg s2_store_en;            // MEM store.
    reg [31:0] s2_mem_wdata;    // MEM write data.
    reg s2_ie;                  // Final irq enable.
    reg [7:0] s2_masked_irq;    // IRQ lines after masking.
    reg s2_irq_final;           // At least one pending IRQ enabled.
    reg s2_hw_trap;             // Any HW trap caught in stages 0..2.
    reg s2_go_seq;              // Sequential/Non-sequential PC selection.        

    // Pipeline bubble logic.
    always @(*) begin
        // The load hazard stalls & trap stalls inserts a bubble in stage 2 by 
        // clearing s2_en (in addition to stalling stages 0 to 2.)
        s2_en = s12r_en & ~co_s2_bubble;
    end

    // Macros for several families of instruction binary pattern.
    // Used as keys in the decoding table below.
    // 'TA2' stands for "Table A-2" of the MIPS arch manual, vol. 2.
    `define TA2(op)     {op, 26'b?????_?????_????????????????}
    `define TA2rt0(op)  {op, 26'b?????_00000_????????????????}
    `define TA2rs0(op)  {op, 26'b00000_?????_????????????????}
    `define TA3(fn)     {26'b000000_?????_????????????????, fn}
    `define TA3rs0(fn)  {26'b000000_00000_????????????????, fn}
    `define TA4(fn)     {26'b000001_?????, fn, 16'b????????????????}
    `define TA9(mt)     {6'b010000, mt, 21'b?????_?????_00000000_???}
    `define TA10(fn)    {26'b010000_1_0000000000000000000, fn}

    // Grouped control signals output by decoding table, grouped as macros.
    // Each macro is used for a bunch of alike instructions.
    `define IN_B(sel)   {3'b000, sel,  4'h0, 2'd3, TYP_B,   P0_X,   P1_X,   WB_N, OP_NOP}
    `define IN_BAL(sel) {3'b000, sel,  4'h0, 2'd3, TYP_B,   P0_PCS, P1_0,   WB_R, OP_ADD}
    `define IN_IH(op)   {3'b000, 3'b0, 4'h0, 2'b0, TYP_IH,  P0_RS1, P1_IMM, WB_R, op}
    `define IN_IU(op)   {3'b000, 3'b0, 4'h0, 2'b0, TYP_IU,  P0_RS1, P1_IMM, WB_R, op}
    `define IN_Ilx      {3'b000, 3'b0, 4'h8, 2'b0, TYP_I,   P0_RS1, P1_IMM, WB_R, OP_NOP}
    `define IN_Isx      {3'b000, 3'b0, 4'h4, 2'b0, TYP_I,   P0_RS1, P1_IMM, WB_N, OP_NOP}
    `define IN_I(op)    {3'b000, 3'b0, 4'h0, 2'b0, TYP_I,   P0_RS1, P1_IMM, WB_R, op}
    `define IN_J(link)  {3'b000, 3'b0, 4'h0, 2'd2, TYP_J,   P0_PCS, P1_0,   link, OP_ADD}
    `define IN_IS(op)   {3'b000, 3'b0, 4'h0, 2'b0, TYP_S,   P0_IMM, P1_RS2, WB_R, op}
    `define IN_R(op)    {3'b000, 3'b0, 4'h0, 2'b0, TYP_R,   P0_RS1, P1_RS2, WB_R, op}
    `define IN_JR       {3'b000, 3'b0, 4'h0, 2'b1, TYP_I,   P0_PCS, P1_0,   WB_N, OP_ADD}
    `define IN_CP0(r,w) {3'b001, 3'b0, 4'h0, 2'd0, TYP_I,   P0_0,   r,      w,    OP_OR}
    `define SPEC(r)     {3'b000, 3'b0, 3'h0,r, 2'd0, TYP_I, P0_0,   P1_X,   WB_N, OP_NOP}
    `define IN_BAD      {3'b000, 3'b0, 4'h0, 2'b0, TYP_BAD, P0_X,   P1_X,   WB_N, OP_NOP}

    // Decoding table.
    // TODO A few bits of decoding still done outside this table (see @note7).
    always @(*) begin
        // FIXME A fair few instructions missing, notably COP0 and privileged.
        casez (s12r_ir)
        `TA2    (6'b000100):        s2_m = `IN_B(3'b000);       // BEQ
        `TA2    (6'b000101):        s2_m = `IN_B(3'b001);       // BNE
        `TA2    (6'b000110):        s2_m = `IN_B(3'b010);       // BLEZ
        `TA2    (6'b000111):        s2_m = `IN_B(3'b011);       // BGTZ
        `TA4    (5'b00000):         s2_m = `IN_B(3'b100);       // BLTZ
        `TA4    (5'b00001):         s2_m = `IN_B(3'b101);       // BGEZ
        `TA4    (5'b10000):         s2_m = `IN_BAL(3'b100);     // BLTZAL
        `TA4    (5'b10001):         s2_m = `IN_BAL(3'b101);     // BGEZAL      
        `TA2rs0 (6'b001111):        s2_m = `IN_IH(OP_OR);       // LUI
        `TA2    (6'b001001):        s2_m = `IN_I(OP_ADD);       // ADDIU
        `TA2    (6'b001000):        s2_m = `IN_I(OP_ADD);       // ADDI
        `TA2    (6'b001101):        s2_m = `IN_IU(OP_OR);       // ORI
        `TA2    (6'b000011):        s2_m = `IN_J(WB_R);         // JAL
        `TA2    (6'b000010):        s2_m = `IN_J(WB_N);         // J
        `TA2    (6'b100000):        s2_m = `IN_Ilx;             // LB
        `TA2    (6'b100100):        s2_m = `IN_Ilx;             // LBU
        `TA2    (6'b100011):        s2_m = `IN_Ilx;             // LW
        `TA2    (6'b100001):        s2_m = `IN_Ilx;             // LH
        `TA2    (6'b100101):        s2_m = `IN_Ilx;             // LHU
        `TA2    (6'b101000):        s2_m = `IN_Isx;             // SB
        `TA2    (6'b101011):        s2_m = `IN_Isx;             // SW
        `TA2    (6'b101001):        s2_m = `IN_Isx;             // SH

        `TA3    (6'b001000):        s2_m = `IN_JR;              // JR
        `TA3    (6'b100000):        s2_m = `IN_R(OP_ADD);       // ADD
        `TA3    (6'b100001):        s2_m = `IN_R(OP_ADD);       // ADDU @note2
        `TA3    (6'b100010):        s2_m = `IN_R(OP_SUB);       // SUB
        `TA3    (6'b100011):        s2_m = `IN_R(OP_SUB);       // SUBU
        `TA3    (6'b101010):        s2_m = `IN_R(OP_SLT);       // SLT
        `TA3    (6'b101011):        s2_m = `IN_R(OP_SLTU);      // SLTU
        `TA2    (6'b001010):        s2_m = `IN_I(OP_SLT);       // SLTI
        `TA2    (6'b001011):        s2_m = `IN_IU(OP_SLTU);     // SLTIU
        `TA3    (6'b100100):        s2_m = `IN_R(OP_AND);       // AND
        `TA3    (6'b100101):        s2_m = `IN_R(OP_OR);        // OR
        `TA3    (6'b100110):        s2_m = `IN_R(OP_XOR);       // XOR
        `TA3    (6'b100111):        s2_m = `IN_R(OP_NOR);       // NOR
        `TA2    (6'b001100):        s2_m = `IN_IU(OP_AND);      // ANDI
        `TA2    (6'b001101):        s2_m = `IN_IU(OP_OR);       // ORI
        `TA2    (6'b001110):        s2_m = `IN_IU(OP_XOR);      // XORI
        `TA2    (6'b001111):        s2_m = `IN_IU(OP_NOR);      // NORI
        `TA3rs0 (6'b000000):        s2_m = `IN_IS(OP_SLL);      // SLL
        `TA3    (6'b000100):        s2_m = `IN_R(OP_SLL);       // SLLV
        `TA3rs0 (6'b000010):        s2_m = `IN_IS(OP_SRL);      // SRL
        `TA3    (6'b000110):        s2_m = `IN_R(OP_SRL);       // SRLV
        `TA3rs0 (6'b000011):        s2_m = `IN_IS(OP_SRA);      // SRA
        `TA3    (6'b000111):        s2_m = `IN_R(OP_SRA);       // SRAV
        `TA9    (5'b00100):         s2_m = `IN_CP0(P1_RS2,WB_C);// MTC0
        `TA9    (5'b00000):         s2_m = `IN_CP0(P1_CSR,WB_R);// MFC0
        `TA10   (6'b011000):        s2_m = `SPEC(1'b1);         // ERET


        default:                    s2_m = `IN_BAD;             // All others
        endcase
        // Unpack the control signals output by the table.
        s2_trap_break_syscall               = s2_m[27:26];
        s2_cop0_access                      = s2_m[25];
        s2_bxx_cond_sel                     = s2_m[24:22];
        {s2_load_en, s2_store_en}           = s2_m[21:20];
        {s2_eret,  s2_flow_sel, s2_type}    = s2_m[19:12];
        {s2_p0_sel, s2_p1_sel}              = s2_m[11:7];
        {s2_wb_en, s2_wb_csr_en, s2_alu_op} = s2_m[6:0];
        s2_alu_en = ~(s2_alu_op == OP_NOP);
        s2_3reg = (s2_type==TYP_R) | (s2_type == TYP_P) | (s2_type == TYP_S);
        s2_link = (s2_p0_sel==P0_PCS) & s2_wb_en;
    end

    initial $display("--> %h", `TA10   (6'b011000));

    // Extract some common instruction fields including immediate field.
    always @(*) begin
        s2_opcode = s12r_ir[31:26];
        s2_func3 = s12r_ir[14:12];

        s2_rs1_index = s12r_ir[25:21];
        s2_rs2_index = s12r_ir[20:16];
        s2_rd_index = s2_link? 5'b11111 : s2_3reg? s12r_ir[15:11] : s12r_ir[20:16];
        s2_csr_index = {s12r_ir[15:11], s12r_ir[2:0]};
        
        // Decode immediate field.
        s2_j_immediate = {s01r_pc[31:28], s12r_ir[25:0], 2'b00};
        s2_b_immediate = {{14{s12r_ir[15]}}, s12r_ir[15:0], 2'b00};
        s2_i_immediate = {{16{s12r_ir[15]}}, s12r_ir[15:0]};
        s2_iu_immediate = {16'h0, s12r_ir[15:0]};
        s2_ih_immediate = {s12r_ir[15:0], 16'h0};
        s2_s_immediate = {27'h0, s12r_ir[10:6]};
        s2_e_immediate = {12'h0, s12r_ir[25:6]};
        s2_t_immediate = {22'h0, s12r_ir[15:6]};

        case (s2_type)
        TYP_M,
        TYP_I:      s2_immediate = s2_i_immediate;
        TYP_S:      s2_immediate = s2_s_immediate;
        TYP_IH:     s2_immediate = s2_ih_immediate;
        TYP_IU:     s2_immediate = s2_iu_immediate;
        default:    s2_immediate = s2_i_immediate;
        endcase
        case (s2_type)
        TYP_E:      s2_cop_imm = s2_e_immediate;
        default:    s2_cop_imm = s2_t_immediate;
        endcase
    end

    // Register bank read ports.
    always @(*) begin
        s2_rs1_bank = (s2_rs1_index == 5'd0)? 32'd0 : s42r_rbank[s2_rs1_index];
        s2_rs2_bank = (s2_rs2_index == 5'd0)? 32'd0 : s42r_rbank[s2_rs2_index];
    end

    // Feedforward mux.
    always @(*) begin
        s2_rs1 = co_dhaz_rs1_s3? s3_alu_res : co_dhaz_rs1_s4? s4_wb_data : s2_rs1_bank;
        s2_rs2 = co_dhaz_rs2_s3? s3_alu_res : co_dhaz_rs2_s4? s4_wb_data : s2_rs2_bank;
    end 

    // CSR bank multiplexors.
    always @(*) begin
        // Translation of CSR address to CSR implementation index for writeback.
        // (We only need to translate indices of implemented writeable regs.)
        case (s2_csr_index)
        8'b01011_000:   s2_csr_xindex = CSRB_MCOMPARE;
        8'b01100_000:   s2_csr_xindex = CSRB_MSTATUS;
        8'b01101_000:   s2_csr_xindex = CSRB_MCAUSE;
        8'b01110_000:   s2_csr_xindex = CSRB_MEPC;
        8'b10000_000:   s2_csr_xindex = CSRB_MCONFIG0;
        8'b11110_000:   s2_csr_xindex = CSRB_MERROREPC;
        default:        s2_csr_xindex = 4'b1111; // CSR WB does nothing.
        endcase
        // CSR read multiplexor.
        case (s2_csr_index)
        8'b01011_000:   s2_csr = s42r_csr_MCOMPARE;
        8'b01100_000:   s2_csr = `STATUS_UNPACK(s42r_csr_MSTATUS);  
        8'b01101_000:   s2_csr = `CAUSE_UNPACK(s42r_csr_MCAUSE);
        8'b01110_000:   s2_csr = s42r_csr_MEPC;
        8'b01111_000:   s2_csr = FEATURE_PRID;
        8'b10000_000:   s2_csr = FEATURE_CONFIG0;
        8'b10000_001:   s2_csr = FEATURE_CONFIG1;
        8'b11110_000:   s2_csr = s42r_csr_MERROREPC;
        default:        s2_csr = 32'h00000000; // Value for unimplemented CSRs.
        endcase
    end

    // Branch condition logic.
    always @(*) begin
        s2_rs12_equal = (s2_rs1 == s2_rs2);
        case (s2_bxx_cond_sel)
        3'b000: s2_bxx_cond_val = s2_rs12_equal;                // BEQ
        3'b001: s2_bxx_cond_val = ~s2_rs12_equal;               // BNE
        3'b010: s2_bxx_cond_val = s2_rs1[31] | ~(|s2_rs1);      // BLEZ
        3'b011: s2_bxx_cond_val = ~s2_rs1[31] & (|s2_rs1);      // BGTZ
        3'b100: s2_bxx_cond_val = s2_rs1[31];                   // BLTZ
        3'b101: s2_bxx_cond_val = ~s2_rs1[31] | ~(|s2_rs1);     // BGEZ
        default:s2_bxx_cond_val = s2_rs12_equal;                // Don't care case.
        endcase
    end

    // Branch/sequential PC selection logic.
    always @(*) begin
        // Mux: either sequential or TRAP or ERET -- All SW driven.
        s2_pc_trap_eret = (s2_trap|s2_hw_trap)? OPTION_TRAP_ADDR : s42r_csr_MEPC;
        s2_pc_branch = s12r_pc_seq + s2_b_immediate;
        s2_pc_jump = s2_j_immediate;
        s2_pc_jalr = s2_rs1;

        // Final PC change mux. Includes branch cond evaluation and HW-driven TRAPs.
        s2_go_seq = 1'b0;
        casez ({(s2_trap|s2_hw_trap|s2_eret),s2_bxx_cond_val,s2_flow_sel})
        4'b1???:    s2_pc_nonseq = s2_pc_trap_eret;
        4'b0?01:    s2_pc_nonseq = s2_pc_jalr;
        4'b0?10:    s2_pc_nonseq = s2_pc_jump;
        4'b0111:    s2_pc_nonseq = s2_pc_branch;
        default:    begin
                    s2_pc_nonseq = s2_pc_trap_eret;
                    s2_go_seq = 1'b1; // meaning no jump at all.           
                    end 
        endcase
    end

    // ALU input & function code selection.
    always @(*) begin
        case (s2_p0_sel)
        P0_0:       s2_arg0 = 32'h0;
        P0_RS1:     s2_arg0 = s2_rs1;
        P0_PCS:     s2_arg0 = s01r_pc_seq; // JAL (-> instr after delay slot)
        P0_PC:      s2_arg0 = s12r_pc; // AUIPC
        P0_IMM:     s2_arg0 = s2_immediate; // Shift instructions 
        default:    s2_arg0 = 32'h0;
        endcase

        case (s2_p1_sel)
        P1_0:       s2_arg1 = 32'h0;
        P1_IMM:     s2_arg1 = s2_immediate;
        P1_RS2:     s2_arg1 = s2_rs2;
        P1_CSR:     s2_arg1 = s2_csr;
        default:    s2_arg1 = 32'h0;
        endcase
    end

    // Interrupt.  (@note5)
    always @(*) begin
        s2_ie = `STATUS_IE & ~(`STATUS_ERL | `STATUS_EXL);
        // TODO timer interrupt request missing.
        s2_masked_irq = {1'b0, HWIRQ_I, `CAUSE_IPSW} & `STATUS_IM;
        s2_irq_final = |(s2_masked_irq) & s2_ie;
        s2_hw_trap = s2_irq_final; // Our only HW trap so far in stages 0..2.
    end

    // Trap logic.
    always @(*) begin
        s2_user_mode = {`STATUS_UM,`STATUS_ERL,`STATUS_EXL}==3'b100;
        s2_trap_cop_unusable = s2_cop0_access & s2_user_mode;

        // Encode trap cause as per table 9.31 in arch manual vol 3.
        casez ({s2_irq_final,s2_trap_cop_unusable,s2_trap_break_syscall})
        4'b1???: s2_trap_cause = 5'b00000;      // Int -- Interrupt.
        4'b01??: s2_trap_cause = 5'b01011;      // CpU -- Coprocessor unusable.
        4'b0010: s2_trap_cause = 5'b01001;      // Bp -- Breakpoint.
        4'b0001: s2_trap_cause = 5'b01000;      // Sys -- Syscall.
        default: s2_trap_cause = 5'b00000;      // Don't care.
        endcase

        // Final trap OR.
        s2_trap = s2_trap_break_syscall | s2_trap_cop_unusable | s2_irq_final;
    end

    // MEM control logic.
    always @(*) begin
        s2_mem_addr_imm = s2_i_immediate;
        s2_mem_addr = s2_rs1 + s2_mem_addr_imm;
        
        s2_mem_trans = (s2_load_en | s2_store_en)? 2'b10 : 2'b00; // NONSEQ.
        s2_load_exz = s12r_ir[28]; // @note7.

        case (s2_opcode[1:0]) // @note7.
        2'b00:     s2_mem_size = 2'b00;
        2'b01:     s2_mem_size = 2'b01;
        2'b10:     s2_mem_size = 2'b10;
        default:   s2_mem_size = 2'b10;
        endcase
        case (s2_mem_size)
        2'b00:      s2_mem_wdata = {4{s2_rs2[ 7: 0]}};
        2'b01:      s2_mem_wdata = {2{s2_rs2[15: 0]}};
        default:    s2_mem_wdata = s2_rs2;
        endcase
    end

    // DE-FA pipeline registers.
    // Update PC (PC writeback sits on DE-FA boundary).
    `PREG (1'b0, s20r_pc_nonseq, OPTION_RESET_ADDR, s2_en, s2_pc_nonseq)


    // DE-EX pipeline registers.
    `PREG (1'b0,  s23r_en, 1'b0, EN_ALWAYS, s2_en)
    `PREG (s2_st, s23r_arg0, 32'h0, s2_en, s2_arg0)
    `PREG (s2_st, s23r_arg1, 32'h0, s2_en, s2_arg1)
    `PREGC(s2_st, s23r_wb_en, 1'b0, s2_en, s2_wb_en & ~s2_trap)
    `PREG (s2_st, s23r_rd_index, 5'd0, s2_en & s2_wb_en, s2_rd_index)
    `PREG (s2_st, s23r_alu_op, 5'd0, s2_en & s2_alu_en, s2_alu_op)
    `PREG (s2_st, s23r_mem_addr, 32'h0, s2_en, s2_mem_addr)
    `PREGC(s2_st, s23r_store_en, 1'b0, s2_en, s2_store_en /* & ~s2_trap*/)
    `PREGC(s2_st, s23r_load_en, 1'b0, s2_en, s2_load_en & ~s2_trap)
    `PREG (s2_st, s23r_mem_wdata, 32'h0, s2_en, s2_mem_wdata)
    `PREG (s2_st, s23r_mem_size, 2'b0, s2_en, s2_mem_size)
    `PREGC(s2_st, s23r_mem_trans, 2'b0, s2_en, s2_mem_trans)
    `PREG (s2_st, s23r_load_exz, 1'b0, s2_en, s2_load_exz)
    `PREG (s2_st, s23r_csr_xindex, 4'd0, s2_en & s2_wb_csr_en, s2_csr_xindex)
    `PREGC(s2_st, s23r_wb_csr_en, 1'b0, s2_en, s2_wb_csr_en & ~s2_trap)
    `PREGC(s2_st, s23r_trap, 1'd0, s2_en, s2_trap)
    `PREGC(s2_st, s23r_eret, 1'd0, s2_en, s2_eret)
    `PREG (s2_st, s23r_epc, 32'h0, s2_en & s2_trap, s12r_pc)
    `PREG (s2_st, s23r_trap_cause, 5'd0, s2_en & s2_trap, s2_trap_cause)


    //==== Pipeline stage Execute ==============================================
    // Combinational ALU logic / address phase of MEM cycle.

    reg s3_en;                  // EX stage enable.
    reg s34r_en;                // WB stage enable carried from EX stage.
    reg [31:0] s3_alu_res;      // Final ALU result.
    reg [31:0] s34r_alu_res;    // ALU result in WB stage.
    reg s34r_wb_en;             // Writeback enable for reg bank.
    reg [4:0] s34r_rd_index;    // Writeback register index.
    reg s34r_load_en;           // MEM load.
    reg [31:0] s34r_mem_wdata;  // MEM store data.
    reg [1:0] s34r_mem_size;    // 2 LSBs of MEM op size for LOAD data mux.
    reg [1:0] s34r_mem_addr;    // 2 LSBs of MEM address for LOAD data mux.
    reg s34r_load_exz;          // 1 if MEM subword load zero-extends to word.
    reg s34r_wb_csr_en;         // WB enable for CSR bank.
    reg [3:0] s34r_csr_xindex;  // CSR WB target (translated index).
    reg s34r_trap;              // TRAP event CSR control passed on to WB.
    reg s34r_eret;              // ERET event CSR control passed on to WB.
    reg [4:0] s34r_trap_cause;  // Trap cause code passed on to WB.
    reg [31:0] s34r_epc;        // Next EPC to be passed on to next stages.
    reg [32:0] s3_arg0_ext;     // ALU arg0 extended for arith ops.
    reg [32:0] s3_arg1_ext;     // ALU arg1 extended for arith ops.
    reg [32:0] s3_alu_addsub;   // Add/sub intermediate result.
    reg [31:0] s3_alu_arith;    // Arith (+/-/SLT*) intermediate result.
    reg [31:0] s3_alu_logic;    // Logic intermediate result.
    reg [31:0] s3_alu_shift;    // Shift intermediate result.
    reg [31:0] s3_alu_noarith;  // Mux for shift/logic interm-results.

    // DATA AHB outputs driven directly by S2/3 pipeline registers.
    assign DADDR_O = s23r_mem_addr;
    assign DTRANS_O = s23r_mem_trans;
    assign DSIZE_O = s23r_mem_size;
    assign DWRITE_O = s23r_store_en;

    // Stage bubble logic.
    always @(*) begin
        s3_en = s23r_en;
    end

    // ALU.
    always @(*) begin

        s3_arg0_ext[31:0] = s23r_arg0;
        s3_arg0_ext[32] = s23r_alu_op[1]? 1'b0 : s23r_arg0[31];
        s3_arg1_ext[31:0] = s23r_arg1;
        s3_arg1_ext[32] = s23r_alu_op[1]? 1'b0 : s23r_arg1[31];

        s3_alu_addsub = s23r_alu_op[0]? 
            s3_arg0_ext - s3_arg1_ext :
            s3_arg0_ext + s3_arg1_ext;

        case (s23r_alu_op[2:1])
        2'b10,
        2'b11:      s3_alu_arith = {31'h0, s3_alu_addsub[32]};
        default:    s3_alu_arith = s3_alu_addsub[31:0];
        endcase        

        case (s23r_alu_op[1:0])
        2'b00:      s3_alu_shift = s23r_arg1 << s23r_arg0[4:0];
        2'b10:      s3_alu_shift = s23r_arg1 >> s23r_arg0[4:0];
        default:    s3_alu_shift = $signed(s23r_arg1) >>> s23r_arg0[4:0];
        endcase        

        case (s23r_alu_op[1:0])
        2'b00:      s3_alu_logic = s23r_arg0 | s23r_arg1;
        2'b01:      s3_alu_logic = s23r_arg0 & s23r_arg1;
        2'b10:      s3_alu_logic = s23r_arg0 ^ s23r_arg1;
        default:    s3_alu_logic = ~(s23r_arg0 | s23r_arg1);
        endcase 

        s3_alu_noarith = s23r_alu_op[3]? s3_alu_logic : s3_alu_shift;
        s3_alu_res = s23r_alu_op[4]? s3_alu_arith : s3_alu_noarith;
    end

    `PREG (1'b0,  s34r_en, 1'b0, EN_ALWAYS, s3_en)
    `PREG (s3_st, s34r_alu_res, 32'h0, s3_en, s3_alu_res)
    `PREGC(s3_st, s34r_wb_en, 1'b0, s3_en, s23r_wb_en)
    `PREG (s3_st, s34r_rd_index, 5'd0, s3_en, s23r_rd_index)
    `PREGC(s3_st, s34r_load_en, 1'b0, s3_en, s23r_load_en)
    `PREG (s3_st, s34r_mem_size, 2'b00, s3_en, s23r_mem_size)
    `PREG (s3_st, s34r_mem_addr, 2'b00, s3_en, s23r_mem_addr[1:0])
    `PREG (s3_st, s34r_load_exz, 1'b0, s3_en, s23r_load_exz)
    `PREG (s3_st, s34r_csr_xindex, 4'd0, s3_en & s23r_wb_csr_en, s23r_csr_xindex)
    `PREG (s3_st, s34r_wb_csr_en, 1'b0, s3_en, s23r_wb_csr_en)
    `PREG (s3_st, s34r_mem_wdata, 32'h0, s3_en & s23r_store_en, s23r_mem_wdata)
    `PREGC(s3_st, s34r_trap, 1'd0, s3_en, s23r_trap)
    `PREGC(s3_st, s34r_eret, 1'd0, s3_en, s23r_eret)
    `PREG (s3_st, s34r_epc, 32'h0, s3_en & s23r_trap, s23r_epc)
    `PREG (s3_st, s34r_trap_cause, 5'd0, s3_en & s23r_trap, s23r_trap_cause)


    //==== Pipeline stage Writeback ============================================
    // Writeback selection logic / data phase of MEM cycle.

    reg s4_en;                  // EX stage enable.
    reg [31:0] s4_load_data;    // Data from MEM load.
    reg [31:0] s4_wb_data;      // Writeback data (ALU or MEM).
    reg [4:0] s4_trap_cause;    // Cause code to load in MCAUSE CSR.
    reg [13:0] s4_status_trap;  // Value to load on MSTATUS CSR on trap.
    reg [31:0] s4_mip_updated;  // Updated MIP after raising new IRQ.
    reg [31:0] s4_irq_raised;   // New interrupt, one-hot encoded.

    assign DWDATA_O = s34r_mem_wdata;

    // Mux for load data byte lanes.
    always @(*) begin
        case ({s34r_mem_size, s34r_mem_addr})
        4'b0011: s4_load_data = DRDATA_I[7:0];
        4'b0010: s4_load_data = DRDATA_I[15:8];
        4'b0001: s4_load_data = DRDATA_I[23:16];
        4'b0000: s4_load_data = DRDATA_I[31:24];
        4'b0110: s4_load_data = DRDATA_I[15:0];
        4'b0100: s4_load_data = DRDATA_I[31:16];
        default: s4_load_data = DRDATA_I;
        endcase
        if (~s34r_load_exz) begin
            case (s34r_mem_size)
            2'b00: s4_load_data[31:8] = {24{s4_load_data[7]}}; 
            2'b01: s4_load_data[31:16] = {16{s4_load_data[15]}};
            endcase
        end
    end

    always @(*) begin
        s4_en = s34r_en;
        // FIXME ready/split ignored
        s4_wb_data = s34r_load_en? s4_load_data : s34r_alu_res; 
        // FIXME traps caught in WB stage missing.
        s4_trap_cause = s34r_trap_cause;
    end

    // Register bank write port.
    always @(posedge CLK) begin
        if (s4_en & ~s4_st & s34r_wb_en) begin
            s42r_rbank[s34r_rd_index] <= s4_wb_data;
        end
    end 

    // CSR input logic. These values are only used if the CSR is not loaded
    // using MTC0, see macros CSREGT and CSREG.
    always @(*) begin
        // STATUS logic: flags modified by TRAP/ERET. 
        s4_status_trap = s42r_csr_MSTATUS;
        casez ({s34r_trap, s34r_eret})
        2'b1?: begin  // TRAP | (TRAP & ERET)
            s4_status_trap[1] = 1'b1; // EXL = 0
        end 
        2'b01: begin  // ERET
            if (`STATUS_ERL) begin
                s4_status_trap[2] = 1'b0; // ERL = 0
            end
            else begin
                s4_status_trap[1] = 1'b0; // EXL = 0
            end            
        end
        default:; // No change to STATUS flags.
        endcase

        // MIP -- set incoming interrupt if any.
        s4_irq_raised = {8'h0, s2_masked_irq, 16'h0}; // FIXME MSIP/MTIP missing.
        s4_mip_updated = s4_irq_raised | s42r_csr_MIP;
    end

    // CSR 'writeback ports'.
    `CSREGT(s4_st, MCAUSE, 17'h0, s34r_trap, s4_trap_cause, `CAUSE_PACK(s34r_alu_res))
    `CSREGT(s4_st, MEPC, 32'h0, s34r_trap, s34r_epc, s34r_alu_res)
    `CSREGT(s4_st, MERROREPC, 32'h0, s34r_trap, s34r_epc, s34r_alu_res)
    `CSREGT(s4_st, MSTATUS, 13'h1004, s34r_trap|s34r_eret, s4_status_trap, `STATUS_PACK(s34r_alu_res))
    `CSREG (s4_st, MCOMPARE)


    //==== Control logic =======================================================


    reg co_dhaz_rs1_s3;         // S3 wb matches rs1 read.
    reg co_dhaz_rs2_s3;         // S3 wb matches rs2 read. 
    reg co_dhaz_rs1_s4;         // S4 wb matches rs1 read.
    reg co_dhaz_rs2_s4;         // S4 wb matches rs2 read. 
    reg co_dhaz_rs1_ld;         // S3vload matches rs1 read.
    reg co_dhaz_rs2_ld;         // S3vload matches rs2 read.
    reg co_s2_stall_load;       // Decode stage stall, by load hazard.
    reg co_s2_stall_trap;       // Decode stage stall, SW trap. 
    reg co_s012_stall_eret;     // Stages 0..2 stall, ERET. 
    reg temp;

    `PREG (1'b0,  temp, 1'b0, EN_ALWAYS, s4_en)

    always @(*) begin
        co_s0_en = ~RESET_I & ~co_s0_bubble;
    end

    always @(*) begin
        // Data hazard: instr. on stage 3 will write on reg used in stage 2.
        co_dhaz_rs1_s3 = (s3_en & s23r_wb_en & (s23r_rd_index==s2_rs1_index));
        co_dhaz_rs2_s3 = (s3_en & s23r_wb_en & (s23r_rd_index==s2_rs2_index));
        // Data hazard: instr on stage 4 will write on reg used in stage 2.
        co_dhaz_rs1_s4 = (s4_en & s34r_wb_en & (s34r_rd_index==s2_rs1_index));
        co_dhaz_rs2_s4 = (s4_en & s34r_wb_en & (s34r_rd_index==s2_rs2_index));
        // Load data hazard: instr. on stage 3 will load data used in stage 2.
        co_dhaz_rs1_ld = (s3_en & s23r_load_en & (s23r_rd_index==s2_rs1_index));
        co_dhaz_rs2_ld = (s3_en & s23r_load_en & (s23r_rd_index==s2_rs2_index));

        co_s2_stall_load = (co_dhaz_rs1_ld | co_dhaz_rs2_ld);
        // Stall S0..2 until bubble propagates from S2..4. @note3.
        co_s2_stall_trap = s23r_trap & s4_en;

        // Stall & bubble S0..2 until bubble propagates to S4. @note4.
        co_s012_stall_eret = s23r_eret & s4_en;

        co_s2_bubble = co_s2_stall_load | co_s2_stall_trap | co_s012_stall_eret; 
        // FIXME bubble stage 1 too in traps so that instruction after victim 
        // does not get executed twice (before and after trap handler).

        co_s1_bubble = co_s012_stall_eret;
        co_s0_bubble = co_s012_stall_eret;


        s4_st = 1'b0;
        s3_st = s4_st;
        s2_st = s3_st | co_s2_bubble;
        s1_st = s2_st;
        s0_st = s1_st;
    end


endmodule // cpu

// FIXME extract notes
// @note1 -- The cycle after a load-hazard-stall we load IR with the value we 
//           saved during the stall cycle, NOT the code bus.
//           FIXME won't work once wait states are implemented. 
// @note2 -- No traps on arith overflow implemented.
// @note3 -- So that trap values have time to reach STATUS and CAUSE regs in 
//           stage 4 before 1st trap handler instruction is executed.
//           This should work with MEM wait states and whatever's in stages
//           3 & 4 at the time of the trap.
// @note4 -- On ERET we stall the pipeline until the STATUS change reaches S4.
//           So instruction after ERET lands on user mode.
//           Also bubble stages 0..1. This means that the two instructions after
//           ERET (sequential after ERET + instruction at EPC) will be fetched 
//           and will be dropped (not executed).
// @note5 -- EPC saved by IRQ is victim instruction, NOT the following one.
// @note6 -- COP0 regs 'packed': implemented bits registered, others h-wired.
// @note7 -- Bits of decoding outside decoding table.