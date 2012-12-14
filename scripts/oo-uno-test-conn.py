#!/usr/bin/python

import uno, sys

from unohelper import Base, systemPathToFileUrl, absolutize
from os import getcwd
from os.path import splitext
from com.sun.star.beans import PropertyValue

def establish_connection(port):
  local_ctx = uno.getComponentContext()
  local_smgr = local_ctx.ServiceManager

  resolver = local_smgr.createInstanceWithContext("com.sun.star.bridge.UnoUrlResolver", local_ctx)
  ctx = resolver.resolve("uno:socket,host=localhost,port=%s;urp;StarOffice.ComponentContext" % port)
  smgr = ctx.ServiceManager

  desktop = smgr.createInstanceWithContext("com.sun.star.frame.Desktop", ctx)

  return desktop

def main():
  if len(sys.argv) <= 1:
    sys.exit(1)

  try:
    desktop = establish_connection(sys.argv[1])
  except:
    print("0")
    sys.exit(2)

  print("1")
  sys.exit(0)

main()
