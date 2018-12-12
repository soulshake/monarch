#include <stdlib.h>
#include <unistd.h>
#include <signal.h>
#include <sys/param.h>
#include <pwd.h>

static char *trusted_env[] =
    {
    "PATH=/usr/bin:/usr/sbin:/sbin:/bin",
    0
    };

int main(int argc, char *argv[])
    {
    struct passwd *pwd;
    int i;
    uid_t uid;

    for (i = 0; i < NSIG; i++)
	{
	if (i != SIGKILL && i != SIGCHLD)
	    {
	    (void) signal(i, SIG_IGN);
	    }
	}
    uid = getuid();

    if ( (pwd = getpwuid(uid)) == (struct passwd *) 0 )
	{
	exit(1);
	}
    setuid((uid_t) 0);

    execle("/etc/init.d/nagios", "/etc/init.d/nagios", "restart", (char *) 0, trusted_env);

    setuid(uid);
    exit(1);
    }
