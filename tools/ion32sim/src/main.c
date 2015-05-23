/*------------------------------------------------------------------------------
* ion32sim.c -- ION (MIPS32 clone) simulator based on Steve Rhoad's "mlite".
*
* This is a heavily modified version of Steve Rhoad's "mlite" simulator, which
* is part of his PLASMA project (original date: 1/31/01).
* As part of the project ION, it is being progressively modified to emulate a
* MIPS32 ION core and it is no longer compatible to Plasma.
*
*-------------------------------------------------------------------------------
* Usage:
*     ion32sim [options]
*
* See function 'usage' for a very brief explaination of the available options.
*
* Generally, upon startup the program will allocate some RAM for the simulated
* system and initialize it with the contents of one or more plain binary,
* big-endian object files. Then it will simulate a cpu reset and start the
* simulation, in interactive or batch mode.
*
* A simulation log file will be dumped to file "sw_sim_log.txt". This log can be
* used to compare with an equivalent log dumped by the hardware simulation, as
* a simple way to validate the hardware for a given program. See the project
* readme files for details.
*
*-------------------------------------------------------------------------------
* Exit Codes:
* 0:        No problem.
* 64:       Error in command line arguments.
* 66:       Could not read one or more of the object input files.
* 71:       Trouble allocating memory.
*-------------------------------------------------------------------------------
* This program simulates the CPU connected to a certain memory map (chosen from
* a set of predefined options) and to a UART.
* The UART is hardcoded at a fixed address and is not configurable in runtime.
* The simulated UART includes the real UART status bits, hardcoded to 'always
* ready' so that software and hardware simulations can be made identical with
* more ease (no need to simulate the actual cycle count of TX/RX, etc.).
*-------------------------------------------------------------------------------
* KNOWN BUGS:
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

/*---- Static data -----------------------------------------------------------*/

/** Depth to ... */
static uint32_t call_depth = 0;

/** Parsed cmd line args globally accessible */
t_args cmd_line_args;

/** Function map table. Starting location, names, etc. */
t_map_info map_info;


/*---- Local function prototypes ---------------------------------------------*/

/* Debug and logging */
static void do_debug(t_state *s, uint32_t no_prompt);
static void init_trace_buffer(t_state *s, t_args *args);
static void close_trace_buffer(t_state *s);
static void dump_trace_buffer(t_state *s);
/* Command line */
static void parse_cmd_line(uint32_t argc, char **argv, t_args *args);
static void usage(FILE *f);
/* Function map */
static int32_t read_map_file(char *filename, t_map_info* map);
static int32_t function_index(uint32_t address);
/* Binary handling */
static int read_binary_files(t_state *s, t_args *args);
static void reverse_endianess(uint8_t *data, uint32_t bytes);

/*----------------------------------------------------------------------------*/

int main(int argc,char *argv[]){
    t_state state, *s=&state;

    /* Parse command line and pass any relevant arguments to CPU record */
    parse_cmd_line(argc,argv, &cmd_line_args);

    fprintf(stderr,"ION (MIPS32 clone) core emulator (" __DATE__ ")\n\n");
    if(!init_cpu(s, &cmd_line_args)){
        fprintf(stderr,"Trouble allocating memory, quitting!\n");
        exit(71);
    };

    /* Read binary object files into memory*/
    if(!read_binary_files(s, &cmd_line_args)){
        exit(66);
    }
    fprintf(stderr,"\n\n");

    init_trace_buffer(s, &cmd_line_args);

    /* NOTE: Original mlite supported loading little-endian code, which this
      program doesn't. The endianess-conversion code has been removed.
    */

    /* Simulate a CPU reset */
    reset_cpu(s);

    /* Simulate the work of the uClinux bootloader */
    if(cmd_line_args.memory_map == MAP_UCLINUX){
        /* FIXME this 'bootloader' is a stub, flesh it out */
        s->pc = 0x80002400;
    }

    /* Enter debug command interface; will only exit clean with user command */
    do_debug(s, cmd_line_args.no_prompt);

    /* Close and deallocate everything and quit */
    close_trace_buffer(s);
    free_cpu(s);
    exit(0);
}


/*-- Call & ret tracing (EARLY DRAFT) --*/

/** */
void log_call(uint32_t to, uint32_t from){
    int32_t i,j;

    /* If no map file has been loaded, skip trace */
    if((!map_info.num_functions) || (!map_info.log)) return;

    i = function_index(to);
    if(i>=0){
        call_depth++;
        fprintf(map_info.log, "[%08x]  ", from);
        for(j=0;j<call_depth;j++){
            fprintf(map_info.log, ". ");
        }
        fprintf(map_info.log, "%s{\n", map_info.fn_name[i]);
    }
}


void log_ret(uint32_t to, uint32_t from){
    int32_t i,j;

    /* If no map file has been loaded, skip trace */
    if((!map_info.num_functions) || (!map_info.log)) return;

    if(call_depth>0){
        fprintf(map_info.log, "[%08x]  ", from);
        for(j=0;j<call_depth;j++){
            fprintf(map_info.log, ". ");
        }
        fprintf(map_info.log, "}\n");
        call_depth--;
    }
    else{
        i = function_index(to);
        if(i>=0){
            fprintf(map_info.log, "[%08x]  %s\n", from, map_info.fn_name[i]);
        }
        else{
            fprintf(map_info.log, "[%08x]  %08x\n", from, to);
        }
    }
}

/*---- Local functions -------------------------------------------------------*/

/*-- Debug helps --*/


void init_trace_buffer(t_state *s, t_args *args){
    int i;

    /* setup misc info related to the monitor interface */
    s->t.disasm_ptr = VECTOR_RESET;

#if FILE_LOGGING_DISABLED
    s->t.log = NULL;
    s->t.log_triggered = 0;
    map_info.log = NULL;
    return;
#else
    /* clear trace buffer */
    for(i=0;i<TRACE_BUFFER_SIZE;i++){
        s->t.buf[i]=0xffffffff;
    }
    s->t.next = 0;

    /* if file logging is enabled, open log file */
    if(args->log_file_name!=NULL){
        s->t.log = fopen(args->log_file_name, "w");
        if(s->t.log==NULL){
            fprintf(stderr,"Error opening log file '%s', file logging disabled\n",
                    args->log_file_name);
        }
    }
    else{
        s->t.log = NULL;
    }

    /* Setup log trigger */
    s->t.log_triggered = 0;
    s->t.log_trigger_address = args->log_trigger_address;

    /* if file logging of function calls is enabled, open log file */
    if(map_info.log_filename!=NULL){
        map_info.log = fopen(map_info.log_filename, "w");
        if(map_info.log==NULL){
            fprintf(stderr,"Error opening log file '%s', file logging disabled\n",
                    map_info.log_filename);
        }
    }
#endif
}

/** Dumps last jump targets as a chunk of hex numbers (older is left top) */
void dump_trace_buffer(t_state *s){
    int i, col;

    for(i=0, col=0;i<TRACE_BUFFER_SIZE;i++, col++){
        printf("%08x ", s->t.buf[s->t.next + i]);
        if((col % 8)==7){
            printf("\n");
        }
    }
}


/** Frees debug buffers and closes log file */
void close_trace_buffer(t_state *s){
    if(s->t.log){
        fclose(s->t.log);
    }
    if(map_info.log){
        fclose(map_info.log);
    }
}

/** Dump CPU state to console */
static void show_state(t_state *s){
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

/** Show debug monitor prompt and execute user command */
static void do_debug(t_state *s, uint32_t no_prompt){
    int ch;
    int i, j=0, watch=0, addr;
    j = s->breakpoint;
    s->pc_next = s->pc + 4;
    s->skip = 0;
    s->wakeup = 0;

    printf("Starting simulation.\n");

    if(no_prompt){
        ch = '5'; /* 'go' command */
        //printf("\n\n");
    }
    else{
        show_state(s);
        ch = ' ';
    }

    for(;;){
        if(ch != 'n' && !no_prompt){
            if(watch){
                printf("0x%8.8x=0x%8.8x\n", watch, mem_read(s, 4, watch,0));
            }
            printf("1=Debug   2=Trace   3=Step    4=BreakPt 5=Go      ");
            printf("6=Memory  7=Watch   8=Jump\n");
            printf("9=Quit    A=Dump    L=LogTrg  C=Disasm  ");
            printf("> ");
        }
        if(ch==' ') ch = getch();
        if(ch != 'n'){
            printf("\n");
        }
        switch(ch){
        case 'a': case 'A':
            dump_trace_buffer(s); break;
        case '1': case 'd': case ' ':
            cycle(s, 0); show_state(s); break;
        case 'n':
            cycle(s, 1); break;
        case '2': case 't':
            cycle(s, 0); printf("*"); cycle(s, 10); break;
        case '3': case 's':
            printf("Count> ");
            scanf("%d", &j);
            for(i = 0; i < j; ++i){
                cycle(s, 1);
            }
            show_state(s);
            break;
        case '4': case 'b':
            printf("Line> ");
            scanf("%x", &j);
            printf("break point=0x%x\n", j);
            break;
        case '5': case 'g':
            s->wakeup = 0;
            cycle(s, 0);
            while(s->wakeup == 0){
                if(s->pc == j){
                    printf("\n\nStop: pc = 0x%08x\n\n", j);
                    break;
                }
                cycle(s, 0);
            }
            if(no_prompt) return;
            show_state(s);
            break;
        case 'G':
            s->wakeup = 0;
            cycle(s, 1);
            while(s->wakeup == 0){
                if(s->pc == j){
                    break;
                }
                cycle(s, 1);
            }
            show_state(s);
            break;
        case '6': case 'm':
            printf("Memory> ");
            scanf("%x", &j);
            for(i = 0; i < 8; ++i){
                printf("%8.8x ", mem_read(s, 4, j+i*4, 0));
            }
            printf("\n");
            break;
        case '7': case 'w':
            printf("Watch> ");
            scanf("%x", &watch);
            break;
        case '8': case 'j':
            printf("Jump> ");
            scanf("%x", &addr);
            s->pc = addr;
            s->pc_next = addr + 4;
            show_state(s);
            break;
        case '9': case 'q':
            return;
        case 'l':
            printf("Address> ");
            scanf("%x", &(s->t.log_trigger_address));
            printf("Log trigger address=0x%x\n", s->t.log_trigger_address);
            break;
        case 'c': case 'C':
            j = s->pc;
            for(i = 1; i <= 16; ++i){
                printf("%c", i==0 ? '*' : ' ');
                s->pc = s->t.disasm_ptr + i * 4;
                cycle(s, 10);
            }
            s->t.disasm_ptr = s->pc;
            s->pc = j;
        }
        ch = ' ';
    }
}


static int32_t function_index(uint32_t address){
    uint32_t i;

    for(i=0;i<map_info.num_functions;i++){
        if(address==map_info.fn_address[i]){
            return i;
        }
    }
    return -1;
}

static int32_t read_map_file(char *filename, t_map_info* map){
    FILE *f;
    uint32_t address, i;
    uint32_t segment_text = 0;
    char line[256];
    char name[256];

    f = fopen (filename, "rt");  /* open the file for reading */

    if(!f){
        return -1;
    }

   while(fgets(line, sizeof(line)-1, f) != NULL){
       if(!strncmp(line, ".text", 5)){
           segment_text = 1;
       }
       else if(line[0]==' ' && segment_text){
            /* may be a function address */
            for(i=0;(i<sizeof(line)-1) && (line[i]==' '); i++);
            if(line[i]=='0'){
                sscanf(line, "%*[ \n\t]%x%*[ \n\t]%s", &address, &(name[0]));

                strncpy(map->fn_name[map->num_functions],
                        name, MAP_MAX_NAME_LEN-1);
                map->fn_address[map->num_functions] = address;
                map->num_functions++;
                if(map->num_functions >= MAP_MAX_FUNCTIONS){
                    printf("WARNING: too many functions in map file!\n");
                    return map->num_functions;
                }
            }
       }
       else if(line[0]=='.' && segment_text){
           break;
       }
    }
    fclose(f);

#if 0
    for(i=0;i<map->num_functions;i++){
        printf("--> %08x %s\n", map->fn_address[i], map->fn_name[i]);
    }
#endif

    return map->num_functions;
}


/*-- Binary file handling --*/


/** Read binary code and data files */
static int read_binary_files(t_state *s, t_args *args){
    FILE *in;
    uint8_t *target;
    uint32_t bytes=0, i, files_read=0;

    /* read map file if requested */
    if(args->map_filename!=NULL){
        if(read_map_file(args->map_filename, &map_info)<0){
            printf("Trouble reading map file '%s', quitting!\n",
                   args->map_filename);
            return 0;
        }
        printf("Read %d functions from the map file; call trace enabled.\n\n",
               map_info.num_functions);
    }

    /* read object code binaries */
    for(i=0;i<NUM_MEM_BLOCKS;i++){
        bytes = 0;
        if(args->bin_filename[i]!=NULL){

            in = fopen(args->bin_filename[i], "rb");
            if(in == NULL){
                free_cpu(s);
                printf("Can't open file %s, quitting!\n",args->bin_filename[i]);
                return(0);
            }

            /* FIXME load offset 0x2000 for linux kernel hardcoded! */
            //bytes = fread((s->blocks[i].mem + 0x2000), 1, s->blocks[i].size, in);
            target = (uint8_t *)(s->blocks[i].mem + args->offset[i]);
            while(!feof(in) &&
                  ((bytes+1024+args->offset[i]) < (s->blocks[i].size))){
                bytes += fread(&(target[bytes]), 1, 1024, in);
                if(errno!=0){
                    printf("ERROR: file load failed with code %d ('%s')\n",
                        errno, strerror(errno));
                    free_cpu(s);
                    return 0;
                }
            }

            fclose(in);

            /* Now reverse the endianness of the data we just read, if it's
             necessary. */
             /* FIXME handle little-endian stuff (?) */
            //reverse_endianess(target, bytes);

            files_read++;
        }
        fprintf(stderr,"%-16s [size= %6dKB, start= 0x%08x] loaded %d bytes.\n",
                s->blocks[i].area_name,
                s->blocks[i].size/1024,
                s->blocks[i].start,
                bytes);
    }

    if(!files_read){
        free_cpu(s);
        fprintf(stderr,"No binary object files read, quitting\n");
        return 0;
    }

    return files_read;
}

static void reverse_endianess(uint8_t *data, uint32_t bytes){
    uint8_t w[4];
    uint32_t i, j;

    for(i=0;i<bytes;i=i+4){
        for(j=0;j<4;j++){
            w[3-j] = data[i+j];
        }
        for(j=0;j<4;j++){
            data[i+j] = w[j];
        }
    }
}

/*-- Command line arguments --*/

/* Parse command line. Will quit with error code is necessary. */
static void parse_cmd_line(uint32_t argc, char **argv, t_args *args){
    uint32_t i;

    /* Initialize logging parameters */
    map_info.num_functions = 0;
    map_info.log_filename = NULL;
    map_info.log = stdout;

    /* fill cmd line args with default values */
    args->memory_map = MAP_DEFAULT;
    args->trap_on_reserved = 0;
    args->stop_on_unimplemented = 0;
    args->emulate_some_mips32 = 1;
    args->timer_prescaler = DEFAULT_TIMER_PRESCALER;
    args->start_addr = VECTOR_RESET;
    args->do_unaligned = 0;
    args->no_prompt = 0;
    args->breakpoint = 0xffffffff;
    args->log_file_name = "sw_sim_log.txt";
    args->log_trigger_address = VECTOR_RESET;
    args->map_filename = NULL;
    for(i=0;i<NUM_MEM_BLOCKS;i++){
        args->bin_filename[i] = NULL;
        args->offset[i] = 0;
    }

    /* parse actual cmd line args */
    for(i=1;i<argc;i++){
        if(strncmp(argv[i],"--memory=", strlen("--memory="))==0){
            args->memory_map = atoi(&(argv[i][strlen("--memory=")]));
            /* FIXME selecting uClinux enables unaligned L/S emulation */
            if (args->memory_map == MAP_UCLINUX){
                args->do_unaligned = 1;
            }
        }
        else if(strcmp(argv[i],"--unaligned")==0){
            args->do_unaligned = 1;
        }
        else if(strcmp(argv[i],"--noprompt")==0){
            args->no_prompt = 1;
        }
        else if(strcmp(argv[i],"--stop_on_unimplemented")==0){
            args->stop_on_unimplemented = 1;
        }
        else if(strcmp(argv[i],"--notrap")==0){
            args->trap_on_reserved = 0;
        }
        else if(strcmp(argv[i],"--nomips32")==0){
            args->emulate_some_mips32 = 0;
        }
        // FIXME simplify object code file options
        else if(strncmp(argv[i],"--bram=", strlen("--bram="))==0){
            args->bin_filename[0] = &(argv[i][strlen("--bram=")]);
        }
        else if(strncmp(argv[i],"--flash=", strlen("--flash="))==0){
            args->bin_filename[3] = &(argv[i][strlen("--flash=")]);
        }
        else if(strncmp(argv[i],"--xram=", strlen("--xram="))==0){
            args->bin_filename[1] = &(argv[i][strlen("--xram=")]);
        }
        else if(strncmp(argv[i],"--map=", strlen("--map="))==0){
            args->map_filename = &(argv[i][strlen("--map=")]);
        }
        else if(strncmp(argv[i],"--trace_log=", strlen("--trace_log="))==0){
            map_info.log_filename = &(argv[i][strlen("--trace_log=")]);
        }
        else if(strncmp(argv[i],"--start=", strlen("--start="))==0){
            sscanf(&(argv[i][strlen("--start=")]), "%x", &(args->start_addr));
        }
        else if(strncmp(argv[i],"--kernel=", strlen("--kernel="))==0){
            args->bin_filename[1] = &(argv[i][strlen("--kernel=")]);
            /* FIXME uClinux kernel 'offset' hardcoded */
            args->offset[1] = 0x2000;
        }
        else if(strncmp(argv[i],"--trigger=", strlen("--trigger="))==0){
            sscanf(&(argv[i][strlen("--trigger=")]), "%x", &(args->log_trigger_address));
        }
        else if(strncmp(argv[i],"--break=", strlen("--break="))==0){
            sscanf(&(argv[i][strlen("--break=")]), "%x", &(args->breakpoint));
        }
        else if(strncmp(argv[i],"--breakpoint=", strlen("--breakpoint="))==0){
            sscanf(&(argv[i][strlen("--breakpoint=")]), "%x", &(args->breakpoint));
        }
        else if((strcmp(argv[i],"--help")==0)||(strcmp(argv[i],"-h")==0)){
            usage(stdout);
            exit(0);
        }
        else{
            fprintf(stderr,"unknown argument '%s'\n\n",argv[i]);
            usage(stderr);
            exit(64);
        }
    }
}

static void usage(FILE *out){
    fprintf(out,"Usage:");
    fprintf(out,"    ion32sim file.exe [arguments]\n");
    fprintf(out,"Arguments:\n");
    fprintf(out,"--bram=<file name>      : BRAM initialization file\n");
    fprintf(out,"--xram=<file name>      : XRAM initialization file\n");
    fprintf(out,"--kernel=<file name>    : XRAM initialization file for uClinux kernel\n");
    fprintf(out,"                          (loads at block offset 0x2000)\n");
    fprintf(out,"--flash=<file name>     : FLASH initialization file\n");
    fprintf(out,"--map=<file name>       : Map file to be used for tracing, if any\n");
    fprintf(out,"--trace_log=<file name> : Log file used for tracing, if any\n");
    fprintf(out,"--trigger=<hex number>  : Log trigger address\n");
    fprintf(out,"--break=<hex number>    : Breakpoint address\n");
    fprintf(out,"--start=<hex number>    : Start here instead of at reset vector\n");
    fprintf(out,"--notrap                : Reserved opcodes are NOPs and don't trap\n");
    fprintf(out,"--nomips32              : Do not emulate any mips32 opcodes\n");
    fprintf(out,"--memory=<dec number>   : Select emulated memory map\n");
    fprintf(out,"    N=0 -- Development memory map (DEFAULT):\n");
    fprintf(out,"        Code TCM at     0xbfc00000 (64KB)\n");
    fprintf(out,"        Cached RAM at   0x80000000 (512KB)\n");
    fprintf(out,"        Cached ROM at   0x90000000 (512KB) (dummy hardwired data)\n");
    fprintf(out,"        Cached FLASH at 0xa0000000 (256KB)\n");
    fprintf(out,"    N=1 -- Experimental uClinux map (under construction, do not use)\n");
    fprintf(out,"--unaligned             : Implement unaligned load/store instructions\n");
    fprintf(out,"--noprompt              : Run in batch mode\n");
    fprintf(out,"--stop_at_zero          : Stop simulation when fetching from address 0x0\n");
    fprintf(out,"--stop_on_unimplemented : Stop simulation when executing unimplemented opcode\n");
    fprintf(out,"--help, -h              : Show this usage text\n");
}
