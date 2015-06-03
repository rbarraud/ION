"""
"""

import sys
from optparse import OptionParser

import test


def usage(progname, to_stdout=False):
    """Print standard usage text."""
    
    if not to_stdout:
        file = sys.stderr
    else:
        file = sys.stdout
    
    print >> file, "usage: %s {[-t testname] | [-r --regression]} [options]"
    
def help():
    """Print a bit of help text longer than the usage message."""
    pass

def main(argv):
    """ """

    parser = OptionParser("usage: %prog [options] testname")
    parser.add_option("--tb", dest="tbname",
        default="ion_core",
        help="use RTL testbench NAME", metavar="NAME")
    parser.add_option("--regression", dest="regression",
        default=None,
        help="execute regression list in FILE", metavar="FILE")
    parser.add_option("-q", "--quiet",
        action="store_true", dest="quiet", default=False,
        help="don't print build and simulation output to console")
    parser.add_option("-n", "--noexitcode",
        action="store_false", dest="check_exit", default=True,
        help="don't check test program exit code")
    parser.add_option("-r", "--rtl",
        action="store_true", dest="only_rtl", default=False,
        help="run only RTL simulation")
    parser.add_option("-s", "--sw",
        action="store_true", dest="only_sw", default=False,
        help="run only software simulation")
    (opts, args) = parser.parse_args()
    
    if not opts.regression and len(args) != 1:
        print >> sys.stderr, "Error: Must specify a test name or a regression list file.\n"
        parser.print_help()
        sys.exit(1)
        
    test.run(opts.tbname, args[0], 
        hw=not opts.only_sw,
        sw=not opts.only_rtl,
        quiet=opts.quiet, 
        check_output=opts.check_exit)
    
    
if __name__ == "__main__":
    main(sys.argv[1:])

    sys.exit(0)

