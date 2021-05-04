module app;

import commands.main;
import jcli;

int main(string[] args)
{
	auto executor = new CommandLineInterface!(commands.main);
    return executor.parseAndExecute(args);
}
