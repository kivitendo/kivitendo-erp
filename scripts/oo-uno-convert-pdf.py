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

def load_file(desktop, path):
  cwd = systemPathToFileUrl(getcwd())
  file_url = absolutize(cwd, systemPathToFileUrl(path))
  sys.stderr.write(file_url + "\n")

  in_props = (
    #   PropertyValue("Hidden", 0 , True, 0),
    )
  return desktop.loadComponentFromURL(file_url, "_blank", 0, in_props)


def write_pdf(doc, path):
  out_props = (
    PropertyValue("FilterName", 0, "writer_pdf_Export", 0),
    PropertyValue("Overwrite", 0, True, 0),
    )

  (dest, ext) = splitext(path)
  dest = dest + ".pdf"
  dest_url = absolutize(systemPathToFileUrl(getcwd()), systemPathToFileUrl(dest))
  sys.stderr.write(dest_url + "\n")
  doc.storeToURL(dest_url, out_props)
  doc.dispose()

def main():
  if len(sys.argv) <= 2:
    sys.exit(1)

  try:
    desktop = establish_connection(sys.argv[1])
  except:
    sys.exit(2)

  try:
    doc = load_file(desktop, sys.argv[2])
    if not doc:
      sys.exit(3)
  except:
    sys.exit(3)

  try:
    write_pdf(doc, sys.argv[2])
  except:
    sys.exit(4)

  sys.exit(0)

main()
