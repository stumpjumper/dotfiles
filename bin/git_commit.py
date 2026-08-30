#!/usr/bin/env python2

import sys
import os
from optparse import OptionParser
from subprocess import call

def setupCmdLineArgs(cmdLineArgs):
  usage =\
"""
usage: %prog [-h|--help] [options] message file_1 [file_2 ...]
       where:
         -h|--help to see options

       Executes:
       git commit -m 'file_1: message' file_1
       git commit -m 'file_1, file_2: message' file_1 file_2
       git commit -m 'file_1, file_2, file_3: message' file_1 file_2 file_3
       ...

       NOTE: message is quoted with \", so use \' for quotes in the message.
"""

  parser = OptionParser(usage)
                       
  help="verbose mode."
  parser.add_option("-v", "--verbose",
                    action="store_true", default=False,
                    dest="verbose",
                    help=help)

  help="No operation, just echo commands"
  parser.add_option("-n", "--noOp",
                    action="store_true", 
                    default=False,
                    dest="noOp",
                    help=help)
  help="Pass the 'commit all changed files', -a/--all flag, to git commit"
  parser.add_option("-a", "--all",
                    action="store_true", 
                    default=False,
                    dest="all",
                    help=help)

  help ="Quiet mode.  Do not ask for conformation or echo any information, "
  help+="including the log"
  parser.add_option("-q", "--quiet",
                    action="store_true", 
                    default=False,
                    dest="quiet",
                    help=help)

  help ="Force.  Do not ask for conformation, just execute. "
  help+="Note: Quiet mode forces also"
  parser.add_option("-f", "--force",
                    action="store_true", 
                    default=False,
                    dest="force",
                    help=help)

#  help="Show last log message after commit command is executed"
#  parser.add_option("-l", "--log",
#                    action="store_true", 
#                    default=False,
#                    dest="showLog",
#                    help=help)
  
  (cmdLineOptions, cmdLineArgs) = parser.parse_args(cmdLineArgs)
  clo = cmdLineOptions

  if cmdLineOptions.verbose:
    print ("cmdLineOptions:",cmdLineOptions)
    for index in range(0,len(cmdLineArgs)):
      print ("cmdLineArgs[%s] = '%s'" % (index, cmdLineArgs[index]))

  if len(cmdLineArgs) > 1 and cmdLineOptions.all:
    parser.error("No files can be specified when the -a/-all flag is "+\
    "used")
  elif len(cmdLineArgs) < 2 and not cmdLineOptions.all:
    parser.error("A message and at least one file must be specified on the "+\
    "command line")

  return (cmdLineOptions, cmdLineArgs)

def main(cmdLineArgs):
  (clo, cla) = setupCmdLineArgs(cmdLineArgs)

  message  = cla[0]
  fileList = cla[1:]

  shortNameFileList = []
  for filename in fileList:
    shortNameFileList.append(os.path.basename(filename))

  if clo.verbose:
    print ("message: ", message)
    print ("fileList:", fileList)

  msg = '"' + ", ".join(shortNameFileList) + ": " + message + '"'

  if not clo.all:
    cmdList = ["git","commit","-m"]
  else:
    cmdList = ["git","commit","-a","-m"]
  cmdList.append(msg)
  cmdList += fileList

  cmd = " ".join(cmdList)

  execute = True
  if not clo.quiet:
    print ("Command is:")
    print (cmd)
    if not clo.force:
      answer = raw_input("Execute [y/n]? ")
      if not answer:
        answer = "n"
      if answer[0].lower() != 'y':
        execute = False
  elif clo.verbose:
    print ("Command:")
    print (cmd)

  cmdText = "call(%s)" % cmdList
  if not execute:
    print ("Exiting...")
    return
  else:
    if not clo.noOp:
      if clo.verbose:
        print ("Executing:")
        print (cmdText)
      print ()
      call(cmdList)
      if not clo.quiet:
        print ()
        call(["git","--no-pager","log","--name-only","-1"])
    else:
      print ("Would have made the call:")
      print (cmdText)

if (__name__ == '__main__'):
  main(sys.argv[1:])
