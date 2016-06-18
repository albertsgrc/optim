#include <iostream>
#include <unistd.h>
#include <chrono>
#include <stdio.h>
#include <fcntl.h>
#include <sys/time.h>
#include <sys/resource.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <cstring>
#include <cmath>
using namespace std;

const int MICROS_PER_SEC = 1e6;

const char* IGNORE_OUTPUT = "--ignore-output";
const char* IGNORE_OUTPUT_SHORT = "-i";

const char* NON_INTERACTIVE = "--non-interactive";
const char* NON_INTERACTIVE_SHORT = "-n";

const long double DECIMAL_PLACES_ROUNDER = 1e3;

typedef unsigned long long ull;

void usage() {
    cout << endl << " Usage:" << endl << endl
         << "     timer [options] <program_to_time> [program_arguments...]"
         << endl
         << endl
         << " Outputs total elapsed, user, system and CPU (system+user) times,"
         << endl
         << " and percentage of time spent in CPU."
         << endl
         << " Time units are seconds on interactive (default) mode, and microseconds"
         << endl
         << " on non-interactive mode."
         << endl
         << endl
         << " Options:"
         << endl
         << endl
         << "     -i, --ignore-output   : Redirects program output to /dev/null"
         << endl
         << "     -n, --non-interactive : Outputs the timing data in json format and microseconds."
         << endl
         << "                             Format is { elapsed: <v>, user: <v>, sys: <v> }."
         << endl
         << "                             Note that there is no trailing endline and both CPU\%"
         << endl
         << "                             and CPU time values are not outputted because they"
         << endl
         << "                             are derivate calculations."
         << endl << endl;

    exit(0);
}

void print_result_non_interactive(ostream& o, ull elapsed, ull user, ull sys, ull mem_max) {
    o  << "{ \"elapsed\": " << elapsed    << ","
       <<  " \"user\": "    << user       << ","
       <<  " \"sys\": "     << sys        << ","
       <<  " \"mem_max\": " << mem_max    << " }";
}

long double normalize(long double n) {
    return round(n*DECIMAL_PLACES_ROUNDER)/DECIMAL_PLACES_ROUNDER;
}

void print_result_interactive(ostream& o, ull elapsed, ull user, ull sys, ull mem_max) {
    long double elapsed_d = (long double)(elapsed)/MICROS_PER_SEC;
    long double user_d = (long double)(user)/MICROS_PER_SEC;
    long double sys_d  = (long double)(sys)/MICROS_PER_SEC;
    long double cpu = user_d + sys_d;
    long double cpu_per = 100.0L*cpu/elapsed_d;

    o << "CPU:     " << normalize(cpu) << " s ("
                     << normalize(cpu_per) << " \%) " << endl
      << "user:    " << normalize(user_d)    << " s" << endl
      << "sys:     " << normalize(sys_d)     << " s" << endl
      << "elapsed: " << normalize(elapsed_d) << " s" << endl
      << "mem_max: " << mem_max              << " KB" << endl;
}

void error(const char* msg) {
    perror(msg);
    exit(1);
}

void _close(int fd) {
    int r = close(fd);
    if (r < 0) error("close");
}

int _open(const char *pathname, int flags) {
    int r = open(pathname, flags);
    if (r < 0) error("open");
    return r;
}

int _dup2(int oldfd, int newfd) {
    int r = dup2(oldfd, newfd);
    if (r < 0) error("dup2");
    return r;
}

int _dup(int fd) {
    int r = dup(fd);
    if (r < 0) error("dup");
    return r;
}

int main(int argc, char* argv[]) {
    if (argc < 2) usage();

    int status, fd_stdout;
    int exitonsig = 0;
    rusage usage;
    chrono::time_point<chrono::system_clock> start, end;

    bool ignore = strcmp(argv[1], IGNORE_OUTPUT_SHORT) == 0 or
                  strcmp(argv[1], IGNORE_OUTPUT) == 0 or ( argc >= 3 and (
                  strcmp(argv[2], IGNORE_OUTPUT_SHORT) == 0 or
                  strcmp(argv[2], IGNORE_OUTPUT) == 0
                ));

    bool non_interactive = strcmp(argv[1], NON_INTERACTIVE_SHORT) == 0 or
                           strcmp(argv[1], NON_INTERACTIVE) == 0 or ( argc >= 3 and (
                           strcmp(argv[2], NON_INTERACTIVE_SHORT) == 0 or
                           strcmp(argv[2], NON_INTERACTIVE) == 0
                        ));

    if (strcmp(argv[1], "-in") == 0 or strcmp(argv[1], "-ni") == 0) {
        non_interactive = ignore = true;
        argv = &argv[2];
    }
    else argv = &argv[1 + ignore + non_interactive];

    if (ignore) {
        // This is done before the vfork() call in order to avoid extra overhead
        // during time measurement. Note that child inherits file table.

        // Make a copy of STDOUT fd for later restore
        fd_stdout = _dup(STDOUT_FILENO);
        // And replace STDOUT by /dev/null
        int fd = _open("/dev/null", O_WRONLY);
        _dup2(fd, STDOUT_FILENO);
        _close(fd);
    }

    start = std::chrono::system_clock::now();
    int pid = vfork();

    if (pid == 0) {
        execvp(argv[0], argv);
        perror(argv[0]);
        _exit(errno == ENOENT ? 127 : 126);
    }
    else if (pid > 0) {
        int wait = wait3(&status, 0, &usage);
        end = std::chrono::system_clock::now();

        if (wait < 0) error("waitpid");

        if (WIFSIGNALED(status))
		      exitonsig = WTERMSIG(status);
    	  if (!WIFEXITED(status))
    		  cerr << "Command terminated abnormally." << endl;

        ull elapsed = chrono::duration_cast<std::chrono::microseconds>
                      (end - start).count();

        timeval usertime = usage.ru_utime;
        timeval systime  = usage.ru_stime;

        ull user = usertime.tv_sec*MICROS_PER_SEC + usertime.tv_usec;
        ull sys  = systime.tv_sec*MICROS_PER_SEC  + systime.tv_usec;

        ull mem_max = usage.ru_maxrss;

        if (ignore) {
            // Restore stdout to the previous copy (it currently points to /dev/null)
            _dup2(fd_stdout, STDOUT_FILENO);
            _close(fd_stdout);
        }

        if (non_interactive) print_result_non_interactive(cerr, elapsed, user, sys, mem_max);
        else print_result_interactive(cerr, elapsed, user, sys, mem_max);
    }
    else error("fork");

    if (exitonsig) {
    		if (signal(exitonsig, SIG_DFL) == SIG_ERR)
    			perror("signal");
    		else
    			kill(getpid(), exitonsig);
    }
	  exit(WIFEXITED(status) ? WEXITSTATUS(status) : EXIT_FAILURE);
}
