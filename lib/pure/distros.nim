#
#
#            Nim's Runtime Library
#        (c) Copyright 2016 Andreas Rumpf
#
#    See the file "copying.txt", included in this
#    distribution, for details about the copyright.
#

## This module implements the basics for Linux distribution ("distro")
## detection and the OS's native package manager. Its primary purpose is to
## produce output for Nimble packages like::
##
##  To complete the installation, run:
##
##  sudo apt-get libblas-dev
##  sudo apt-get libvoodoo
##
## The above output could be the result of a code snippet like:
##
## .. code-block:: nim
##
##   if detectOs(Ubuntu):
##     foreignDep "lbiblas-dev"
##     foreignDep "libvoodoo"
##

from strutils import contains, toLowerAscii

when not defined(nimscript):
  from osproc import execProcess
  from os import existsEnv

type
  Distribution* {.pure.} = enum ## the list of known distributions
    Windows                     ## some version of Windows
    Posix                       ## some Posix system
    MacOSX                      ## some version of OSX
    Linux                       ## some version of Linux
    Ubuntu
    Debian
    Gentoo
    Fedora
    RedHat

    OpenSUSE
    Manjaro
    Elementary
    Zorin
    CentOS
    Deepin
    ArchLinux
    Antergos
    PCLinuxOS
    Mageia
    LXLE
    Solus
    Lite
    Slackware
    Androidx86
    Puppy
    Peppermint
    Tails
    AntiX
    Kali
    SparkyLinux
    Apricity
    BlackLab
    Bodhi
    TrueOS
    ArchBang
    KaOS
    WattOS
    Korora
    Simplicity
    RemixOS
    OpenMandriva
    Netrunner
    Alpine
    BlackArch
    Ultimate
    Gecko
    Parrot
    KNOPPIX
    GhostBSD
    Sabayon
    Salix
    Q4OS
    ClearOS
    Container
    ROSA
    Zenwalk
    Parabola
    ChaletOS
    BackBox
    MXLinux
    Vector
    Maui
    Qubes
    RancherOS
    Oracle
    TinyCore
    Robolinux
    Trisquel
    Voyager
    Clonezilla
    SteamOS
    Absolute
    NixOS ## NixOS or a Nix build environment
    AUSTRUMI
    Arya
    Porteus
    AVLinux
    Elive
    Bluestar
    SliTaz
    Solaris
    Chakra
    Wifislax
    Scientific
    ExTiX
    Rockstor
    GoboLinux

    BSD
    FreeBSD
    OpenBSD
    DragonFlyBSD

    Haiku


const
  LacksDevPackages* = {Distribution.Gentoo, Distribution.Slackware,
    Distribution.ArchLinux}

# we cache the result of the 'cmdRelease'
# execution for faster platform detections.
var unameRes, osRes, releaseRes, hostnamectlRes: string

template cmdRelease(cmd, cache): untyped =
  if cache.len == 0:
    cache = (when defined(nimscript): gorge(cmd) else: execProcess(cmd))
  cache

template uname(): untyped = cmdRelease("uname -a", unameRes)
template osrelease(): untyped = cmdRelease("cat /etc/os-release", osRes)
template release(): untyped = cmdRelease("lsb_release -d", releaseRes)
template hostnamectl(): untyped = cmdRelease("hostnamectl", hostnamectlRes)

proc detectOsWithAllCmd(d: Distribution): bool =
  let dd = toLowerAscii($d)
  result = dd in toLowerAscii(osrelease()) or dd in toLowerAscii(release()) or
            dd in toLowerAscii(uname()) or ("operating system: " & dd) in toLowerAscii(hostnamectl())

proc detectOsImpl(d: Distribution): bool =
  case d
  of Distribution.Windows: ## some version of Windows
    result = defined(windows)
  of Distribution.Posix: result = defined(posix)
  of Distribution.MacOSX: result = defined(macosx)
  of Distribution.Linux: result = defined(linux)
  of Distribution.BSD: result = defined(bsd)
  else:
    when defined(linux):
      case d
      of Distribution.Ubuntu, Distribution.Gentoo, Distribution.FreeBSD,
        Distribution.OpenBSD, Distribution.Debian, Distribution.Fedora,
        Distribution.OpenMandriva, Distribution.CentOS:
        result = $d in osrelease()
      of Distribution.RedHat:
        result = "Red Hat" in osrelease()
      of Distribution.Elementary:
        result = "elementary OS" in toLowerAscii(osrelease())
      of Distribution.ArchLinux:
        result = "arch" in toLowerAscii(uname())
      of Distribution.NixOS:
        result = existsEnv("NIX_BUILD_TOP") or existsEnv("__NIXOS_SET_ENVIRONMENT_DONE")
        # Check if this is a Nix build or NixOS environment
      of Distribution.OpenSUSE:
        result = "suse" in toLowerAscii(uname()) or "suse" in toLowerAscii(release())
      of Distribution.GoboLinux:
        result = "-Gobo " in uname()
      of Distribution.Solaris:
        let uname = toLowerAscii(uname())
        result = ("sun" in uname) or ("solaris" in uname)
      of Distribution.Haiku:
        result = defined(haiku)
      else:
          result = detectOsWithAllCmd(d)
    else:
      result = detectOsWithAllCmd(d)

template detectOs*(d: untyped): bool =
  ## Distro/OS detection. For convenience the
  ## required ``Distribution.`` qualifier is added to the
  ## enum value.
  detectOsImpl(Distribution.d)

when not defined(nimble):
  var foreignDeps: seq[string] = @[]

proc foreignCmd*(cmd: string; requiresSudo = false) =
  ## Registers a foreign command to the intern list of commands
  ## that can be queried later.
  let c = (if requiresSudo: "sudo " else: "") & cmd
  when defined(nimble):
    nimscriptapi.foreignDeps.add(c)
  else:
    foreignDeps.add(c)

proc foreignDepInstallCmd*(foreignPackageName: string): (string, bool) =
  ## Returns the distro's native command line to install 'foreignPackageName'
  ## and whether it requires root/admin rights.
  let p = foreignPackageName
  when defined(windows):
    result = ("Chocolatey install " & p, false)
  elif defined(bsd):
    result = ("ports install " & p, true)
  elif defined(linux):
    if detectOs(Ubuntu) or detectOs(Elementary) or detectOs(Debian) or
        detectOs(KNOPPIX) or detectOs(SteamOS):
      result = ("apt-get install " & p, true)
    elif detectOs(Gentoo):
      result = ("emerge install " & p, true)
    elif detectOs(Fedora):
      result = ("yum install " & p, true)
    elif detectOs(RedHat):
      result = ("rpm install " & p, true)
    elif detectOs(OpenSUSE):
      result = ("yast -i " & p, true)
    elif detectOs(Slackware):
      result = ("installpkg " & p, true)
    elif detectOs(OpenMandriva):
      result = ("urpmi " & p, true)
    elif detectOs(ZenWalk):
      result = ("netpkg install " & p, true)
    elif detectOs(NixOS):
      result = ("nix-env -i " & p, false)
    elif detectOs(Solaris):
      result = ("pkg install " & p, true)
    elif detectOs(PCLinuxOS):
      result = ("rpm -ivh " & p, true)
    elif detectOs(ArchLinux) or detectOs(Manjaro):
      result = ("pacman -S " & p, true)
    else:
      result = ("<your package manager here> install " & p, true)
  elif defined(haiku):
    result = ("pkgman install " & p, true)
  else:
    result = ("brew install " & p, false)

proc foreignDep*(foreignPackageName: string) =
  ## Registers 'foreignPackageName' to the internal list of foreign deps.
  ## It is your job to ensure the package name
  let (installCmd, sudo) = foreignDepInstallCmd(foreignPackageName)
  foreignCmd installCmd, sudo

proc echoForeignDeps*() =
  ## Writes the list of registered foreign deps to stdout.
  for d in foreignDeps:
    echo d

when false:
  foreignDep("libblas-dev")
  foreignDep "libfoo"
  echoForeignDeps()
