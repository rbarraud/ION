/**
    @file ion32sim.h
    @brief Global functions and variables.

    This header is meant to declare all global functions and variables of the
    program, so the source can be easily split into several files. 
*/

#ifndef ION32SIM_INC
#define ION32SIM_INC

#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <ctype.h>
#include <assert.h>
#include <stdbool.h>

/*---- Program configuration macros ------------------------------------------*/

/** Length of debugging jump target queue */
#define TRACE_BUFFER_SIZE (32)

/** Function map table -- number of function entries */
#define MAP_MAX_FUNCTIONS  (400)
/** Function map table -- size of name field */
#define MAP_MAX_NAME_LEN   (80)
/** Set to !=0 to disable file logging (much faster simulation) */
/* alternately you can just set an unreachable log trigger address */
#define FILE_LOGGING_DISABLED (0)
/** Define to enable cache simulation (unimplemented) */
//#define ENABLE_CACHE
/** Set to !=0 to display a fancier listing of register values */
#define FANCY_REGISTER_DISPLAY (1)
/** Number of memory blocks in memory map */
#define NUM_MEM_BLOCKS      (5)

/*---- HW constant macros ----------------------------------------------------*/

/** CPU identification code (contents of register CP0[15], PRId */
#define CPU_ID (0x00000200)
/** Reset value of CP0.Config register */
#define CP0_CONFIG0 (0x80002400)
/** Reset value of CP0.Config1 register */
#define CP0_CONFIG1 (0x80984c00)
/** Number of hardware interrupt inputs (irq0 is NMI) */
#define NUM_HW_IRQS (8)
/** Default value for timer prescaler */
#define DEFAULT_TIMER_PRESCALER (50)

#define VECTOR_RESET (0xbfc00000)
#define VECTOR_TRAP  (0xbfc00180)


/*---- Hardware system parameters --------------------------------------------*/

/*
 * These are features of the simulated subsystem that contains the CPU and not
 * of the CPU itself.
 * We simulate them here so that the RTL and the SW simulations are identical.
 */

/** Base address of GPIO register block. */
#define IO_GPIO           (0xffff0020)

/* Debug registers present only in this simulator and in the TB. */
#define TB_UART_TX        (0xffff8000)
#define TB_UART_RX        (0xffff8000)
#define TB_HW_IRQ         (0xffff8010)
#define TB_STOP_SIM       (0xffff8018)
#define TB_DEBUG          (0xffff8020)
#define TB_DEBUG_0        (0xffff8020)
#define TB_DEBUG_1        (0xffff8024)
#define TB_DEBUG_2        (0xffff8028)
#define TB_DEBUG_3        (0xffff802c)


/*---- Utility macros --------------------------------------------------------*/

/* Will be true when in kernel mode. */
#define KERNEL_MODE ((s->cp0_status & 0x016) != 0x010)
#define SR_BEV (1 << 22)
#define SR_ERL (1 << 2)
#define SR_EXL (1 << 1)

/* Flags used in the block definitions. */
/** Block is read only. */
#define MEM_READONLY        (1<<0)
/** Block is pre-loaded with test data pattern. */
#define MEM_TEST            (1<<1)


/* Endianess conversion macros. */
#define ntohs(A) ( ((A)>>8) | (((A)&0xff)<<8) )
#define htons(A) ntohs(A)
#define ntohl(A) ( ((A)>>24) | (((A)&0xff0000)>>8) | (((A)&0xff00)<<8) | ((A)<<24) )
#define htonl(A) ntohl(A)

/* Assertion flags that will be used to notify the main cycle function of any
 * failed assertions in its subfunctions. 
 */
// FIXME should be a bitfield
#define ASRT_UNALIGNED_READ         (1<<0)
#define ASRT_UNALIGNED_WRITE        (1<<1)


/*---- Remnants from Plasma to be refactored ---------------------------------*/

/* Much of this is a remnant from Plasma's mlite and is  no longer used. */
/* FIXME Refactor HW system params */

#define UART_STATUS       (0xffff0004)
#define TIMER_READ        (0xffff0100)



/* FIXME The following addresses are remnants of Plasma to be removed */
#define IRQ_MASK          0x20000010
#define IRQ_STATUS        0x20000020

#define IRQ_UART_READ_AVAILABLE  0x002
#define IRQ_UART_WRITE_AVAILABLE 0x001


/*---- Local data types ------------------------------------------------------*/

/** Definition of a memory block */
typedef struct s_block {
    uint32_t start;
    uint32_t size;
    uint32_t mask;
    uint32_t flags;
    uint8_t  *mem;
    char     *area_name;
} t_block;


/** Definition of a memory map */
/* FIXME i/o addresses missing, hardcoded */
typedef struct s_map {
    t_block blocks[NUM_MEM_BLOCKS];
} t_map;


/* FIXME memory areas should be refactored to account for TCMs. */
/*  Here's where we define the memory areas (blocks) of the system.

    The blocks should be defined in this order: BRAM, XRAM, FLASH

    BRAM is FPGA block ram initialized with bootstrap code
    XRAM is external SRAM
    FLASH is external flash

    Give any area a size of 0x0 to leave it unused.

    When a binary file is specified in the cmd line for one of these areas, it
    will be used to initialize it, checking bounds.

    Memory decoding is done in the order the blocks are defined; the address
    is anded with field .mask and then compared to field .start. If they match
    the address modulo the field .size is used to index the memory block, giving
    a 'mirror' effect. All of this simulates how the actual hardware works.
    Make sure the blocks don't overlap or the scheme will fail.
*/

typedef enum {
    MAP_DEFAULT =       0,
    MAP_UCLINUX =       1,
    NUM_MEM_MAPS =      2
} t_mem_area;



/** Values for the command line arguments */
typedef struct s_args {
    /** !=0 to trap on unimplemented opcodes, 0 to print warning and NOP */
    uint32_t trap_on_reserved;
    /** !=0 to stop simulation on unimplemented opcodes */
    uint32_t stop_on_unimplemented;
    /** !=0 to emulate some common mips32 opcodes */
    uint32_t emulate_some_mips32;
    /** Prescale value used for the timer/counter */
    uint32_t timer_prescaler;
    /** address to start execution from (by default, reset vector) */
    uint32_t start_addr;
    /** memory map to be used */
    uint32_t memory_map;
    /** implement unaligned load/stores (don't just trap them) */
    uint32_t do_unaligned;
    /** start simulation without showing monitor prompt and quit on
        end condition -- useful for batch runs */
    uint32_t no_prompt;
    /** breakpoint address (0xffffffff if unused) */
    uint32_t breakpoint;
    /** a code fetch from this address starts logging */
    uint32_t log_trigger_address;
    /** full name of log file */
    char *log_file_name;
    /** bin file to load to each area or null */
    char *bin_filename[NUM_MEM_BLOCKS];
    /** map file to be used for function call tracing, if any */
    char *map_filename;
    /** name of file to write CPU console output to, or NULL to use stdout. */
    char *conout_filename;
    /** offset into area (in bytes) where bin will be loaded */
    /* only used when loading a linux kernel image */
    uint32_t offset[NUM_MEM_BLOCKS];
} t_args;

/** File to be used for simulated CPU console output. */
extern FILE *cpuconout;

/** Assorted debug & trace info */
typedef struct s_trace {
   unsigned int buf[TRACE_BUFFER_SIZE];   /**< queue of last jump targets */
   unsigned int next;                     /**< internal queue head pointer */
   FILE *log;                             /**< text log file or NULL */
   int log_triggered;                     /**< !=0 if log has been triggered */
   uint32_t log_trigger_address;          /**< */
   int pr[32];                            /**< last value of register bank */
   int hi, lo, epc, status;               /**< last value of internal regs */
   int disasm_ptr;                        /**< disassembly pointer */
   /** Instruction cycles remaining to trigger, or -1 if irq inactive */
   int32_t irq_trigger_countdown;         /**< (in instructions) */
   int8_t irq_trigger_inputs;             /**< HW interrupt to be triggered */
   int8_t irq_current_inputs;             /**< HW interrupt inputs */
} t_trace;

typedef struct s_cop2_stub {
    /* {D[0..31], C[0..31] } */
    uint32_t r[32*2];      /**< Reg banks, data & control. */
} t_cop2_stub;

typedef struct s_state {
   unsigned failed_assertions;            /**< assertion bitmap */
   unsigned faulty_address;               /**< addr that failed assertion */
   uint32_t do_unaligned;                 /**< !=0 to enable unaligned L/S */
   uint32_t breakpoint;                   /**< BP address of 0xffffffff */

   int delay_slot;              /**< !=0 if prev. instruction was a branch */
   uint32_t instruction_ctr;    /**< # of instructions executed since reset */
   uint32_t inst_ctr_prescaler; /**< Prescaler counter for instruction ctr. */
   uint32_t debug_regs[16];     /**< Rd/wr debug registers */
   uint16_t gpio_regs[1];       /**< Rd/wr GPIO registers */

   int r[32];
   int opcode;
   int pc, pc_next, epc;
   uint32_t op_addr;            /**< address of opcode being simulated */
   uint32_t hi;
   uint32_t lo;
   uint32_t cp0_status;
   int32_t trap_cause;          /**< temporary trap code or <0 if no trap */
   uint32_t cause_ip;           /**< Temporary IP field of Cause reg. */
   uint32_t cp0_cause;
   uint32_t cp0_errorpc;
   uint32_t cp0_config0;
   uint32_t cp0_compare;

   t_cop2_stub cop2;            /**< COP2 stub. */

   int irqStatus;               /**< DEPRECATED, to be removed */
   int skip;
   int eret_delay_slot;
   t_trace t;
   t_block blocks[NUM_MEM_BLOCKS];
   int wakeup;
   int big_endian;
   bool sr_load_pending;
   uint32_t sr_load_pending_value;
} t_state;


/** Information extracted from the map file, if any */
typedef struct {
    uint32_t num_functions;         /**< number of functions in the table */
    FILE *log;                      /**< text log file or stdout */
    char *log_filename;             /**< name of log file or NULL */
    uint32_t fn_address[MAP_MAX_FUNCTIONS];
    char fn_name[MAP_MAX_FUNCTIONS][MAP_MAX_NAME_LEN];
} t_map_info;


/*---- Common functions defined in files other than main ---------------------*/

extern int mem_read(t_state *s, int size, unsigned int address, int log);
extern void mem_write(t_state *s, int size, unsigned address, unsigned value, int log);

/* CPU model */
extern void free_cpu(t_state *s);
extern int init_cpu(t_state *s, t_args *args);
extern void reset_cpu(t_state *s);

extern void log_call(uint32_t to, uint32_t from);
extern void log_ret(uint32_t to, uint32_t from);

#endif
