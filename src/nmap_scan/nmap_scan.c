#include <stdlib.h>
#include <unistd.h>
#include <signal.h>
#include <sys/param.h>
#include <pwd.h>

// This is here mainly so we can identify compiled binaries.
// Maybe someday we'll provide a -V option to spill it out.
static char *VERSION = "2.0.0";

static char *nmap_pl = "/usr/local/groundwork/monarch/bin/nmap_scan_one.pl";
static char *trusted_env[] =
    {
    "PATH=/usr/bin:/usr/sbin:/sbin:/bin",
    0
    };

void terminate (int sig)
    {
    exit (sig);
    }

int main(int argc, char *argv[])
    {
    char *ip_address = argv[1];
    struct passwd *pwd;
    int sig;
    uid_t uid;
    for (sig = 1; sig < NSIG; ++sig)
	{
	switch (sig)
	    {
	    case SIGKILL:
	    case SIGCHLD:
	    case SIGTERM:
	    case SIGHUP:
	        break;
	    case SIGCONT:
		/*
		// This is an abuse of SIGCONT (using it to terminate rather than
		// continue the process), but we use it because it's the only signal
		// we can send from our parent process to stop this process, given
		// that this process will run as a different user.
		*/
		(void) signal(sig, terminate);
	        break;
	    default:
		(void) signal(sig, SIG_IGN);
	        break;
	    }
	}
    uid=getuid();

    if ( (pwd = getpwuid(uid)) == (struct passwd *) 0 )
	exit(1);
    setuid((uid_t)0);

    execle(nmap_pl, nmap_pl, ip_address, (char *) 0, trusted_env);
    setuid(uid);
    exit(1);
    }
