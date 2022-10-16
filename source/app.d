module app;

import commands.main;
import jcli;

int main(string[] args)
{
	return executeSingleCommand!DefaultCommand(args[1 .. $]);
}
