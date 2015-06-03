"""Utility code for running test programs on SW and RTL simulators.

This package automates the running of test cases. Basically, we run each test 
on two platforms (RTL simulator and SW simulator) and compare the execution 
logs. 

See comments for main function run().
"""

import sys
import os
import getopt
import subprocess
import difflib
from config import *


#### Project parameters. These parameters depend on the project directory 
#    structure or on constants embedded elsewhere. 

# Root directory for the per-tb Modelsim scripts and work directories.
MODELSIM_WORK_PATH = "../../sim/modelsim"
# Root directory for the software test cases.
TEST_ROOT_PATH = "../../sw"

# Names of log files, embedded into the RTL, makefiles and/or sw simulator source.
RTL_CONSOLE_LOG_FILE = "hw_sim_console_log.txt" 
RTL_EXECUTION_LOG_FILE = "hw_sim_log.txt"
SW_EXECUTION_LOG_FILE = "sw_sim_log.txt"
SW_CONSOLE_LOG_FILE = "console_log.txt" 


#### Package constants.

# VT100 contorl codes to print colored text to console.
CC = "\033[1;33m"
CF = "\033[0m"



def eval_exec_log(filename):
    """Parse execution log looking for memory stores on TB register TB_MSG_REG.
    Return value written by SW on register TB_MSG_REG or -1 if there was no write.
    """
    
    file = open(filename, 'r')
    lines = file.readlines()
    file.close()
    
    for i in reversed(range(len(lines))):
        line = lines[i].strip()
        if line.endswith("WR"):
            items = line.split()
            if len(items)>=3 and items[1]=="[FFFF8018]":
                fields = items[2].split('=')
                if len(fields)==2:
                    num_errors = int("0x"+fields[1],0)
                    return num_errors
    
    # Could find no write to the TB_MSG_REG register, so the test failed.
    return -1

    
def delete_log_files(exec_log_file, console_log_file):
    """Delete both files passed on as parameters if they exist."""
    # Delete log files if they exist.
    try:
        os.remove(exec_log_file)
    except OSError:
        pass
    try:
        os.remove(console_log_file)
    except OSError:
        pass
    
def eval_pass_condition(exec_log_file):
    """Find out if a test passed or failed by looking at an execution log file.
    
    If the execution log file does not exist, result is False.
    If it does exist, the result depends on its contents: it'll be True if the 
    last value written to 0xFFFF8018 is not zero, and False otherwise, including
    if no write to that address is on the log.
    """

    # If the exec log has been created, parse it for the simulation pass code.
    if os.path.exists(exec_log_file):
        num_errors = eval_exec_log(exec_log_file)
        if (num_errors<0):
            print "SW did not write on TB register TB_MSG_REG, crash suspected."
        elif num_errors >0:
            print "SW reported %d errors." % num_errors
        else:
            print "SW reported no errors."
        outcome = (num_errors == 0)
    else:
        outcome = False
        print "Execution log file '%s' missing, marking test as failed." % exec_log_file
    return outcome

def rtl_modelsim(tbname, progname, quiet=False, check_output=True):
    """Simulate the selected RTL TB on Modelsim.
    
    The sw test in question is assumed to have been built previously, including 
    the object code packages used by the RTL TB.
    
    The function will run the test program on the selected RTL TB on 
    Modelsim using standard parameters.
    
    The execution log from the RTL simulation will be used to determine the 
    pass/fail outcome of the test.
    
    Returns True for pass or False for fail.
    """

    outcome = False
    print (CC + "Running test case '%s' on RTL test bench entity '%s'..." + CF) % (progname, tbname)
    
    # Modelsim invocation line. Note the nogui variable that will prevent the 
    # command file from trying to set up the wave window.
    modelsim_cmdline = "vsim -c -do \"set nogui 1; do %s_tb.do\"" % tbname
    
    # Build the path and file names.
    testbench_work_dir = MODELSIM_WORK_PATH + "/" + tbname 
    exec_log_file = testbench_work_dir + "/" + RTL_EXECUTION_LOG_FILE
    console_log_file = testbench_work_dir + "/" + RTL_CONSOLE_LOG_FILE
    
    # Delete log files if they exist.
    delete_log_files(exec_log_file, console_log_file)
    
    # Invoke Modelsim from within the TB work directory and using the tcl 
    # command file for the TB in question.
    try:
        if not quiet:
            redir_stderr = None
            redir_stdout = None
        else:
            redir_stderr = subprocess.PIPE
            redir_stdout = subprocess.PIPE
        
        sp = subprocess.Popen(
            modelsim_cmdline, executable=MODELSIM_EXEC_PATH, 
            cwd=testbench_work_dir, 
            stdout=redir_stdout, stderr=redir_stderr)
        (out, err) = sp.communicate()
        
        if sp.returncode != 0:
            print "Simulation returned error code %d:" % sp.returncode
            return False
    except Exception as e:
        raise e

    # Now, if the execution log was not created at all, the test failed.
    # If it was created, then optionally check the SW output code.
    outcome = os.path.exists(exec_log_file)
    if outcome:
        if check_output: outcome &= eval_pass_condition(exec_log_file)
    else:
        print "Execution log file not created, test failed."
        
    return outcome


def sw_build(tbname, progname, quiet=False):
    """Build a test case.
    
    The test bench name (tbname) is necessary because RTL object code packages
    will be generated along the object code files, for RTL simulation. 
    In the current version of the code we still have TB dependencies.
    """
    print (CC+"Building test case '%s'..."+CF) % (progname)
    
    # Build the path and file names.
    test_case_dir = TEST_ROOT_PATH + "/" + progname 
    exec_log_file = test_case_dir + "/" + SW_EXECUTION_LOG_FILE
    console_log_file = test_case_dir + "/" + SW_CONSOLE_LOG_FILE
    
    if not quiet:
        redir_stderr = None
        redir_stdout = None
    else:
        redir_stderr = subprocess.PIPE
        redir_stdout = subprocess.PIPE
    
    # Run the test case on the SW simulator.
    progdir = TEST_ROOT_PATH + "/" + progname
    command = ["make", "tb_core"]
    
    try:
        sp = subprocess.Popen(command,
            cwd=progdir, 
            stdout=redir_stdout, stderr=redir_stderr)
        (out, err) = sp.communicate()
        
        if sp.returncode != 0:
            print "Build failed with error code %d:" % sp.returncode
            return False
        else:
            return True
    except Exception as e:
        raise e
        
        

def sw_sim(tbname, progname, quiet=False, check_output=True):
    """Run some test program on the SW simulator.
    
    The execution log will conditionally be used to determine the 
    pass/fail outcome of the test.
    
    Returns True for pass or False for fail.
    """
    
    print (CC+"Running test case '%s' on SW core simulator..."+CF) % (progname)
    
    # Build the path and file names.
    test_case_dir = TEST_ROOT_PATH + "/" + progname 
    exec_log_file = test_case_dir + "/" + SW_EXECUTION_LOG_FILE
    console_log_file = test_case_dir + "/" + SW_CONSOLE_LOG_FILE
    
    # Delete log files if they exist.
    delete_log_files(exec_log_file, console_log_file)
    
    if not quiet:
        redir_stderr = None
        redir_stdout = None
    else:
        redir_stderr = subprocess.PIPE
        redir_stdout = subprocess.PIPE
    
    # Run the test case on the SW simulator.
    progdir = TEST_ROOT_PATH + "/" + progname
    command = [
        "ion32sim", 
        "--trigger=bfc00000", "--noprompt", "--nomips32",
        "--bram=%s.bin" % progname,
        "--map=%s.map" % progname, 
        "--trace_log=trace_log.txt"]
    if quiet: command.append("--conout=console_log.txt")
    out = ""
    err = ""
    try:
        sp = subprocess.Popen(command, executable=SWSIM_EXEC_PATH, 
            cwd=progdir, 
            stdout=redir_stdout, stderr=redir_stderr)
        (out, err) = sp.communicate()
        
        if sp.returncode != 0:
            print "Simulation returned error code %d:" % sp.returncode
            return False
    except Exception as e:
        raise e
    
    # Now, if the execution log was not created at all, the test failed.
    # If it was created, then optionally check the SW output code.
    outcome = os.path.exists(exec_log_file)
    if outcome:
        if check_output: outcome &= eval_pass_condition(exec_log_file)
    else:
        print "Execution log file not created, test failed."

    return outcome

def compare_exec_logs(tbname, progname, match_sizes=True):
    """ """
    
    # Build the log file names.
    test_case_dir = TEST_ROOT_PATH + "/" + progname 
    sw_exec_log_file = test_case_dir + "/" + SW_EXECUTION_LOG_FILE
    testbench_work_dir = MODELSIM_WORK_PATH + "/" + tbname 
    hw_exec_log_file = testbench_work_dir + "/" + RTL_EXECUTION_LOG_FILE
    
    error = None
    
    try:
        file = open(hw_exec_log_file, 'r')
        hw_lines = file.readlines()
        file.close()
        file = open(sw_exec_log_file, 'r')
        sw_lines = file.readlines()
        file.close() 
        
        if (len(hw_lines) != len(sw_lines)) and match_sizes:
            error = "Different number of lines."
        else:
            for i in range(len(hw_lines)):
                if hw_lines[i].strip() != sw_lines[i].strip():
                    error = "@%d: %s != %s" % (i, hw_lines[i].strip(), sw_lines[i].strip())
                    break
        
    except Exception as e:
        raise e

    if error:
        print "Exec log mismatch -- %s\033[0m" % error
            
    return error==None
    
def print_outcome(tbname, progname, passed):
    """Print pass/fail message to stderr."""
    
    if passed:
        msg = "Test '%s' \033[1;32mPASSED\033[0m" % progname
    else:
        msg = "Test '%s' \033[1;31mFAILED\033[0m" % progname
    
    print >> sys.stderr, msg
    

def test_case_exists(progname):
    """ """
    test_case_dir = TEST_ROOT_PATH + "/" + progname
    return os.path.exists(test_case_dir)
    
def testbench_exists(tbname):
    """ """
    testbench_work_dir = MODELSIM_WORK_PATH + "/" + tbname
    return os.path.exists(testbench_work_dir)
    
    
def run(tbname, progname, quiet=False, check_output=True, hw=True, sw=True):
    """Run a test on SW simulator AND on RTL simulator, compare logs. 
    
    This function will do the following:
    
    1.- Build test program.
    2.- Run test program on SW simulator, checking exit code.
    3.- Run test program on selected RTL TB, checking exit code.
    4.- Compare execution logs for steps 2 and 3.
    
    If any of the above steps fail, the test fails.
    
    The program 'exit code' is the last value written on register 0xffff8018.
    It is assumed to be an error count so it must be zero for the test to pass.
    If check_output==False, then the program exit code is not checked.
    
    The function will print relevant progfress and outcome messages, plus the
    entire simulation output if quiet==False.
    
    Return True if the test passed, False otherwise.
    """
    
    if not test_case_exists(progname):
        print >> sys.stderr, "Error: could not find test program '%s'" % progname
        sys.exit(1)
   
    if not testbench_exists(tbname):
        print >> sys.stderr, "Error: could not find RTL testbench '%s'" % tbname
        sys.exit(1)
    
    passed = True
    
    passed &= sw_build(tbname, progname, quiet=quiet)
    if not passed:
        return False
    if sw:
        passed &= sw_sim(tbname, progname, quiet=quiet, check_output=check_output)
        if not passed:
            return False
    if hw:
        passed &= rtl_modelsim(tbname, progname, quiet=quiet, check_output=check_output)
        if not passed:
            return False

    if sw and hw:
        passed &= compare_exec_logs(tbname, progname)
    
    print_outcome(tbname, progname, passed)
    
    return passed
