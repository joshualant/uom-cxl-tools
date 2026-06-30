# Setup for Multi-Guest VCS testing

-------------------------
## 0. Note (Important)

I will make heavy reference here to the README.md file, as much of the setup
is overlapping but with seccom specific files.

-------------------------
## 1. Quickstart

Like the Quickstart in README.md, except this time run multi-vcs-install.sh.

This will give you three nodes, (FM, and 2 compute). By default these will be
set up with all the cli tools needed. 

Keep an eye on the install  since it requires sudo for the mod install if you 
build the kernel...

by default:

FM      = port 33000-33004
Node 1  = port 34000-34004
Node 2  = port 35000-35004

-------------------------
## 2. Testing

In the shared directory (see the README.md) there are some scripts which do 
some basic FM functions. You can use these to test the functionality of the 
VCS switch. Read them to get an idea of the sorts of commands you could run... 
note that it is best to use these tests as a guide to your own commands manually,
since there is no coordination betweeen the guests to run them automatically.
They are only slightly adapted from the single guest case...
