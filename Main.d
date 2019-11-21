//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
// BacktraceBeautifier:
// 
// [2019-11-21]
// 
//   This program beautifies a backtrace generated by gdb from a C++ program.
//   
//   Usage examples (after having compiled-and-linked to "Main" or "Main.exe"):
//   
//     "./Main" < "Backtrace.txt"
//     
//     cat "Backtrace.txt" | "./Main"
//     
//     gdb -quiet "./LovelyButFragileProgram" "core" -ex "backtrace" -ex "quit" 2>&1 | "./Main" 2>&1 | tee "gdb-output.txt"
//   
//   Support: adder_2003 at yahoo dot com. Thank you ! (-:
//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

import std.exception;
import std.regex;
import std.algorithm;
import std.range.primitives;

bool
ParseFunction
(const (char) [] s0, out const (char) [] sJustName, out const (char) [] sJustArgs)
{
	uint    iState = 0;
	char [] sStack;
	
	char    Last_c;
	bool    Last_bOpener;
	bool    Last_bCloser;
	bool    Last_bSmiley;
	
	for (size_t ic = 0; ic <= s0.length; ++ic)
	{
		immutable char c       = ic < s0.length ? s0 [ic] : 0;
		immutable bool bOpener = c == '<' || c == '(' || c == '[' || c == '{';
		immutable bool bCloser = c == '>' || c == ')' || c == ']' || c == '}';
		immutable bool bSmiley = c == '*' || c == '&';
		enforce (! (bOpener && bCloser));
		
		if (bOpener)
			sStack ~= c;
		else
		if (bCloser)
		{
			enforce (sStack.length);
			immutable char cOpener = sStack [$ - 1];
			
			if      (cOpener == '<') enforce (c == '>');
			else if (cOpener == '(') enforce (c == ')');
			else if (cOpener == '[') enforce (c == ']');
			else if (cOpener == '{') enforce (c == '}');
			else                     enforce (0);
			
			sStack = sStack [0 .. $ - 1];
		}
		
		if (! iState)
		{
			if (c == '>' && Last_c == ' ')
				sJustName = sJustName [0 .. $ - 1];
			
			if (c == '(' && sStack.length == 1 && Last_c == ' ')
				iState = 50;
			else
			if (bOpener && ! Last_bOpener && Last_c != ' ' /* || ! bCloser && Last_bCloser && c != ':' */)
			{
				sJustName ~= ' ';
				sJustName ~= c;
			}
			else
			if (bSmiley && ! Last_bOpener && ! Last_bSmiley && Last_c != ' ')
			{
				sJustName ~= ' ';
				sJustName ~= c;
			}
			else
				sJustName ~= c;
		}
		else
		if (iState == 50)
		{
			if (c == ')' && ! sStack.length)
				iState = 90;
			else
				sJustArgs ~= c;
		}
		else
		if (iState == 90)
		{
			// [2019-11-21] TODO: Why is this fired ?
			//if (c)
			//	enforce (0);
		}
		else
			enforce (0);
		
		Last_c       = c;
		Last_bOpener = bOpener;
		Last_bCloser = bCloser;
		Last_bSmiley = bSmiley;
	}
	
	// [2019-11-21] TODO: Why is this fired ?
	//enforce (iState == 90);
	
	return true;
}


int main (string [] args)
{
	import std.stdio;
	
	auto r = regex
	(
		"^\\s*" ~
		"#(?P<Index>\\d+)\\s+" ~
		"(0x(?P<Address>\\w+) in )?" ~
		"(?P<Function>.*?)" ~
		"(?P<Source> at (?P<SourceFile>\\S+):(?P<SourceLine>\\d+))?" ~
		"\\s*$",
		
		""
	);
	
	uint iLine = 1;
	foreach (const (char) [] sLine; stdin.byLine)
	{
		//if (iLine >= 6) break;
		
		auto cs = matchFirst (sLine, r);
		if (! cs.empty ())
		{
			import std.format;
			
			char [] ss;
			{
				enforce (! cs ["Index"].empty);
				if (1)
					ss ~= format ("#%02s\n", cs ["Index"]);
				
				if (! cs ["Address"].empty)
					ss ~= format ("\t0x%016s in\n", cs ["Address"]);
				
				enforce (! cs ["Function"].empty);
				if (1)
				{
					const (char) [] sJustName;
					const (char) [] sJustArgs;
					       bool     bResult;
					{
						bResult = ParseFunction (cs ["Function"], sJustName, sJustArgs);
					}
					
					enforce (bResult);
					
					if (0)
					{
						ss ~= format ("\t%s\n", cs ["Function"]);
						ss ~= format ("\tsJustName: %s\n", sJustName);
						ss ~= format ("\tsJustArgs: %s\n", sJustArgs);
					}
					else
					{
						ss ~= format ("\t%s\n", sJustName);
						
						if (sJustArgs.length)
						{
							ss ~= "\t(\n";
							ss ~= format ("\t\t%s\n", sJustArgs);
							ss ~= "\t)\n";
						}
						else
							ss ~= "\t()\n";
					}
				}
				
				if (! cs ["Source"].empty)
					ss ~= format ("\tat %s:%s\n", cs ["SourceFile"], cs ["SourceLine"]);
			
			}
			
			sLine = ss.idup ();
			
			//sLine = format ("#%02s\n" ~ "\t%s\n", c [1], c [2]);
		}
		
		writef ("%s\n", sLine);
		
		++iLine;
	}
	
	return 0;
}