ARCH=krypton

# CPP
MACHINECPP :=
CPP        := /lib/cpp -E -traditional

# C
CC      := gcc 
CCFLAGS := -O2 -g  $(MACHINECPP) 

# Fortran
FC := ifort
MYFCFLAGS := -O2 -traceback -g

# Modules
MODNAME = $(shell echo $(*F) | tr "[:upper:]" "[:lower:]")
MODEXT := mod

# Link
LD          := $(FC)
LDFLAGS     := -O2 -traceback -g 
#-Bstatic -static

# AR
AR      := ar
ARFLAGS := rv
MV      := mv
RM      := rm -f
MKDIR   := mkdir
RMDIR   := rmdir

# Flags
FCFLAGS := $(MYFCFLAGS) -I$(ROOTDIR)/inc -module $(ROOTDIR)/$(ARCH)/mod
CPPFLAGS := -I$(ROOTDIR)/inc

# depf90mod.x search extensions ( -f is default )
MODEXTS=-E F90 -E F -E f90 -E -f 
