#! /bin/sh
#
# mulle-clang installer
# (c) 2016 Codeon GmbH, coded by Nat!
# BSD-3 License

# compile it like LLVM does (everything all the time)
# only useful if you're creating installers IMO
BY_THE_BOOK="YES"

# our compiler version
MULLE_CLANG_VERSION="5.0.0.0"
MULLE_CLANG_RC="4"
MULLE_LLDB_VERSION="5.0.0.0"
MULLE_LLDB_RC="4"


# required LLVM version
LLVM_VERSION="5.0.0"
#LLVM_RC="3" # leave empty for releases

CMAKE_VERSION_MAJOR="3"
CMAKE_VERSION_MINOR="5"
CMAKE_VERSION_PATCH="2"


if [ -z "${MULLE_CLANG_RC}" ]
then
   MULLE_CLANG_ARCHIVENAME="${MULLE_CLANG_VERSION}"
else
   MULLE_CLANG_ARCHIVENAME="${MULLE_CLANG_VERSION}-RC${MULLE_CLANG_RC}"
fi
MULLE_CLANG_ARCHIVE="https://github.com/Codeon-GmbH/mulle-clang/archive/${MULLE_CLANG_ARCHIVENAME}.tar.gz"
MULLE_CLANG_UNPACKNAME="mulle-clang-${MULLE_CLANG_ARCHIVENAME}"

if [ -z "${MULLE_LLDB_RC}" ]
then
   MULLE_LLDB_ARCHIVENAME="${MULLE_LLDB_VERSION}"
else
   MULLE_LLDB_ARCHIVENAME="${MULLE_LLDB_VERSION}-RC${MULLE_LLDB_RC}"
fi
MULLE_LLDB_ARCHIVE="https://github.com/Codeon-GmbH/mulle-lldb/archive/${MULLE_LLDB_ARCHIVENAME}.tar.gz"
MULLE_LLDB_UNPACKNAME="mulle-lldb-${MULLE_LLDB_ARCHIVENAME}"


if [ -z "${LLVM_RC}" ]
then
   #regular releases
   LLVM_ARCHIVE="http://llvm.org/releases/${LLVM_VERSION}/llvm-${LLVM_VERSION}.src.tar.xz"
   LIBCXX_ARCHIVE="http://llvm.org/releases/${LLVM_VERSION}/libcxx-${LLVM_VERSION}.src.tar.xz"
   LIBCXXABI_ARCHIVE="http://llvm.org/releases/${LLVM_VERSION}/libcxxabi-${LLVM_VERSION}.src.tar.xz"
else
# prereleases
   LLVM_ARCHIVE="http://prereleases.llvm.org/releases/${LLVM_VERSION}/rc${LLVM_RC}/llvm-${LLVM_VERSION}rc${LLVM_RC}.src.tar.xz"
   LIBCXX_ARCHIVE="http://prereleases.llvm.org/releases/${LLVM_VERSION}/rc${LLVM_RC}/libcxx-${LLVM_VERSION}rc${LLVM_RC}.src.tar.xz"
   LIBCXXABI_ARCHIVE="http://prereleases.llvm.org/releases/${LLVM_VERSION}/rc${LLVM_RC}/libcxxabi-${LLVM_VERSION}rc${LLVM_RC}.src.tar.xz"
fi

#
#
#
CMAKE_VERSION="${CMAKE_VERSION_MAJOR}.${CMAKE_VERSION_MINOR}"
CMAKE_PATCH_VERSION="${CMAKE_VERSION}.${CMAKE_VERSION_PATCH}"


environment_initialize()
{
   UNAME="`uname -s`"
   case "${UNAME}" in
      MINGW*)
         CLANG_SUFFIX="-cl"
         EXE_EXTENSION=".exe"
         SYMLINK_PREFIX="~"
         SUDO=
      ;;

      *)
         SYMLINK_PREFIX="/usr/local"
         SUDO="sudo"
      ;;
   esac
}


log_initialize()
{
   if [ -z "${NO_COLOR}" ]
   then
      case "${UNAME}" in
         Darwin|Linux|FreeBSD|MINGW*)
            C_RESET="\033[0m"

            # Useable Foreground colours, for black/white white/black
            C_RED="\033[0;31m"     C_GREEN="\033[0;32m"
            C_BLUE="\033[0;34m"    C_MAGENTA="\033[0;35m"
            C_CYAN="\033[0;36m"

            C_BR_RED="\033[0;91m"
            C_BOLD="\033[1m"
            C_FAINT="\033[2m"

            C_RESET_BOLD="${C_RESET}${C_BOLD}"
            trap 'printf "${C_RESET}"' TERM EXIT
         ;;
      esac
   fi
   C_ERROR="${C_RED}${C_BOLD}"
   C_WARNING="${C_RED}${C_BOLD}"
   C_INFO="${C_MAGENTA}${C_BOLD}"
   C_FLUFF="${C_GREEN}${C_BOLD}"
   C_VERBOSE="${C_CYAN}${C_BOLD}"
}


concat()
{
   local i
   local s

   for i in "$@"
   do
      if [ -z "${i}" ]
      then
         continue
      fi

      if [ -z "${s}" ]
      then
         s="${i}"
      else
         s="${s} ${i}"
      fi
   done

   echo "${s}"
}


log_error()
{
   printf "${C_ERROR}%b${C_RESET}\n" "$*" >&2
}


log_warning()
{
   printf "${C_WARNING}%b${C_RESET}\n" "$*" >&2
}


log_info()
{
   printf "${C_INFO}%b${C_RESET}\n" "$*" >&2
}


log_fluff()
{
   if [ ! -z "${FLUFF}" ]
   then
      printf "${C_FLUFF}%b${C_RESET}\n" "$*" >&2
   fi
}


log_verbose()
{
   if [ ! -z "${VERBOSE}" -a -z "${TERSE}" ]
   then
      printf "${C_VERBOSE}%b${C_RESET}\n" "$*" >&2
   fi
}


fail()
{
   log_error "$@"
   exit 1
}


internal_fail()
{
   fail "$@"
}



tar_fail()
{
   case "${UNAME}" in
      MINGW*)
         log_warning "$@" "ignored, because we're on MinGW and crossing fingers, that just tests are affected"
      ;;

      *)
         fail "$@"
      ;;
   esac
}


exekutor_trace()
{
   if [ "${MULLE_FLAG_EXECUTOR_DRY_RUN}" = "YES" -o "${MULLE_FLAG_LOG_EXECUTOR}" = "YES" ]
   then
      local arrow

      [ -z "${MULLE_EXECUTABLE_PID}" ] && internal_fail "MULLE_EXECUTABLE_PID not set"

      if [ "${PPID}" -ne "${MULLE_EXECUTABLE_PID}" ]
      then
         arrow="=[${PPID}]=>"
      else
         arrow="==>"
      fi

      if [ -z "${MULLE_EXECUTOR_LOG_DEVICE}" ]
      then
         echo "${arrow}" "$@" >&2
      else
         echo "${arrow}" "$@" > "${MULLE_EXECUTOR_LOG_DEVICE}"
      fi
   fi
}


exekutor()
{
   exekutor_trace "$@"

   if [ "${MULLE_FLAG_EXECUTOR_DRY_RUN}" != "YES" ]
   then
      "$@"
   fi
}


is_root()
{
   if [ "$EUID" != "" ]
   then
      [ "$EUID" -eq 0 ]
   else
      [ "`id -u`" -eq 0 ]
   fi
}


sudo_if_needed()
{
   if [ -z "${SUDO}" ] || is_root
   then
      eval exekutor "$@"
   else
      command -v "${SUDO}" > /dev/null 2>&1
      if [ $? -ne 0 ]
      then
         fail "Install ${SUDO} or run as root"
      fi
      eval exekutor ${SUDO} "$@"
   fi
}


emit_llvm_loop_utils_patch()
{
   cat <<EOF
   --- lib/Transforms/Utils/LoopUtils.cpp 2017-09-13 15:16:32.000000000 +0200
+++ /tmp/LoopUtils.cpp  2017-09-13 15:14:27.000000000 +0200
@@ -23,7 +23,6 @@
 #include "llvm/Analysis/ScalarEvolutionExpander.h"
 #include "llvm/Analysis/ScalarEvolutionExpressions.h"
 #include "llvm/Analysis/TargetTransformInfo.h"
-#include "llvm/Analysis/ValueTracking.h" // (nat) added this
 #include "llvm/IR/Dominators.h"
 #include "llvm/IR/Instructions.h"
 #include "llvm/IR/Module.h"
@@ -1118,8 +1117,6 @@

 /// Returns true if the instruction in a loop is guaranteed to execute at least
 /// once.
-/// Returns true if the instruction in a loop is guaranteed to execute at least
-/// once.
 bool llvm::isGuaranteedToExecute(const Instruction &Inst,
                                  const DominatorTree *DT, const Loop *CurLoop,
                                  const LoopSafetyInfo *SafetyInfo) {
@@ -1131,27 +1128,14 @@
   // common), it is always guaranteed to dominate the exit blocks.  Since this
   // is a common case, and can save some work, check it now.
   if (Inst.getParent() == CurLoop->getHeader())
-  {
-    if( ! SafetyInfo->HeaderMayThrow)
-      return true;
-
-    // find the place where we throw in the loop header and everything up till
-    // then is guaranteed to execute. It would be nicer if we could memorize
-    // isGuaranteedToTransferExecutionToSuccessor on a per instruction basis
-
-    BasicBlock *Header = CurLoop->getHeader();
-    for (BasicBlock::const_iterator I = Header->begin(), E = Header->end();
-         (I != E); ++I)
-    {
-      if( ! isGuaranteedToTransferExecutionToSuccessor(&*I))
-        return( false);
-      if( &*I == &Inst)
-        break;
-    }
     // If there's a throw in the header block, we can't guarantee we'll reach
-    // Inst. But all functions until the throw can be collected
-    return( true);
-  }
+    // Inst.
+    return !SafetyInfo->HeaderMayThrow;
+
+  // Somewhere in this loop there is an instruction which may throw and make us
+  // exit the loop.
+  if (SafetyInfo->MayThrow)
+    return false;

   // Get the exit blocks for the current loop.
   SmallVector<BasicBlock *, 8> ExitBlocks;
EOF
}


patch_llvm()
{
   [ -d "${LLVM_DIR}" ] || fail "llvm did not unpack to expected \"${LLVM_DIR}\""
   (
      cd "${LLVM_DIR}"
      emit_llvm_loop_utils_patch | patch -u -R "lib/Transforms/Utils/LoopUtils.cpp"
   )
}


fetch_brew()
{
   case "${UNAME}" in
      Darwin)
         log_fluff "Installing OS X brew"

         exekutor ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)" || fail "ruby"
      ;;

      Linux)
         install_binary_if_missing "curl"
         install_binary_if_missing "python-setuptools"
         install_binary_if_missing "build-essential"
         install_binary_if_missing "ruby"

         log_fluff "Installing Linux brew"
         exekutor ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/linuxbrew/go/install)" || fail "ruby"
      ;;
   esac
}


install_with_brew()
{
   PATH="$PATH:/usr/local/bin" command -v "brew" > /dev/null 2>&1
   if [ $? -ne 0 ]
   then
      command -v "ruby" > /dev/null 2>&1
      if [ $? -ne 0 ]
      then
         fail "You need to install $1 manually from $2"
      fi

      fetch_brew
   fi

   log_info "Download $1 using brew"
   PATH="$PATH:/usr/local/bin" exekutor brew install "$1" || exit 1
}


install_library_if_missing()
{
   # we just install if there is no sudo needed
   case "${UNAME}" in
      Darwin)
         install_with_brew "$@" || exit 1
      ;;

      Linux)
         if command -v "brew" > /dev/null 2>&1
         then
            install_with_brew "$@" || exit 1
         else
            if command -v "apt-get" > /dev/null 2>&1
            then
               if ! dpkg -s "$1" > /dev/null 2>&1
               then
                  log_info "You may get asked for your password to install $1"
                  sudo_if_needed apt-get install "$1" || exit 1
               fi
            else
               if command -v "yum" > /dev/null 2>&1
               then
                  if ! yum list installed "$1" > /dev/null 2>&1
                  then
                     log_info "You may get asked for your password to install $1"
                     sudo_if_needed yum install "$1" || exit 1
                  fi
               else
                  log_warning "You may need to install $1 manually from $2"
               fi
            fi
         fi
      ;;

      FreeBSD)
         if command -v "pkg" > /dev/null 2>&1
         then
            if ! pkg info"$1" > /dev/null 2>&1
            then
               log_info "You may get asked for your password to install $1"
               sudo_if_needed pkg install "$1" || exit 1
            fi
         else
            if command -v "pkg_add" > /dev/null 2>&1
            then
               if ! pkg_info "$1" > /dev/null 2>&1
               then
                  log_info "You may get asked for your password to install $1"
                  sudo_if_needed pkg_add -r "$1" || exit 1
               fi
            else
               fail "You need to install $1 manually from $2"
            fi
         fi
      ;;

      *)
         fail "You need to install $1 manually from $2"
      ;;
   esac
}


install_binary_if_missing()
{
   if command -v "$1" > /dev/null 2>&1
   then
      return
   fi

   case "${UNAME}" in
      Darwin)
         install_with_brew "$@" || exit 1
      ;;

      Linux)
         if command -v "brew" > /dev/null 2>&1
         then
            install_with_brew "$@" || exit 1
         else
            if command -v "apt-get" > /dev/null 2>&1
            then
               log_info "You may get asked for your password to install $1"
               sudo_if_needed apt-get install "$1" || exit 1
            else
               if command -v "yum" > /dev/null 2>&1
               then
                  log_info "You may get asked for your password to install $1"
                  sudo_if_needed yum install "$1" || exit 1
               else
                  fail "You need to install $1 manually from $2"
               fi
            fi
         fi
      ;;

      FreeBSD)
         if command -v "pkg" > /dev/null 2>&1
         then
            log_info "You may get asked for your password to install $1"
            sudo_if_needed pkg install "$1" || exit 1
         else
            if command -v "pkg_add" > /dev/null 2>&1
            then
               log_info "You may get asked for your password to install $1"
               sudo_if_needed pkg_add -r "$1" || exit 1
            else
               fail "You need to install $1 manually from $2"
            fi
         fi
      ;;

      *)
         fail "You need to install $1 manually from $2"
      ;;
   esac
}


build_cmake()
{
   log_fluff "Build cmake..."

   install_binary_if_missing "curl" "https://curl.haxx.se/"
   install_binary_if_missing "${CXX_COMPILER}" "https://gcc.gnu.org/install/download.html"
   install_binary_if_missing "tar" "from somewhere"
   install_binary_if_missing "make" "from somewhere"

   exekutor mkdir "${SRC_DIR}" 2> /dev/null
   set -e
      exekutor cd "${SRC_DIR}"

         if [ -d "cmake-${CMAKE_PATCH_VERSION}" ]
         then
            exekutor rm -rf "cmake-${CMAKE_PATCH_VERSION}"
         fi
         if [ ! -f "cmake-${CMAKE_PATCH_VERSION}.tar.gz" ]
         then
            exekutor curl -k -L -O "https://cmake.org/files/v${CMAKE_VERSION}/cmake-${CMAKE_PATCH_VERSION}.tar.gz"
         fi

         exekutor tar xfz "cmake-${CMAKE_PATCH_VERSION}.tar.gz"
         exekutor cd "cmake-${CMAKE_PATCH_VERSION}"
         exekutor ./configure "--prefix=${PREFIX}"
         exekutor ${MAKE} install || exit 1

         hash -r  # apparently needed...
      exekutor cd "${OWD}"
   set +e
}


check_cmake_version()
{
   local major
   local minor
   local version

   version="`cmake -version 2> /dev/null | awk '{ print $3 }'`"
   if [ -z "${version}" ]
   then
      log_fluff "The cmake is not installed."
      return 2
   fi

   major="`echo "${version}" | head -1 | cut -d. -f1`"
   if [ -z "${major}" ]
   then
      fail "Could not figure out where cmake is and what version it is."
   fi

   minor="`echo "${version}" | head -1 | cut -d. -f2`"
   if [ "${major}" -lt "${CMAKE_VERSION_MAJOR}" ] || [ "${major}" -eq "${CMAKE_VERSION_MAJOR}" -a "${minor}" -lt "${CMAKE_VERSION_MINOR}" ]
   then
      return 1
   fi

   return 0
}


check_and_build_cmake()
{
   if [ -z "${BUILD_CMAKE}" ]
   then
      install_binary_if_missing "cmake" "https://cmake.org/download/"
   fi

   check_cmake_version
   case $? in
      0)
         return
      ;;

      1)
         log_fluff "The cmake version is too old. cmake version ${CMAKE_VERSION} or better is required."
      ;;

      2)
         :
      ;;
   esac

   log_fluff "Let's build cmake from scratch"
   build_cmake || fail "build_cmake failed"
}


get_core_count()
{
   local count

   command -v "nproc" > /dev/null 2>&1
   if [ $? -ne 0 ]
   then
      command -v "sysctl" > /dev/null 2>&1
      if [ $? -ne 0 ]
      then
         log_fluff "can't figure out core count, assume 4"
      else
         count="`sysctl -n hw.ncpu`"
      fi
   else
      count="`nproc`"
   fi

   if [ -z "$count" ]
   then
      count=4
   fi
   echo $count
}


#
# but isn't that the same as MULLE_CLANG_VERSION ?
# not neccessarily, if the script was curled and the
# clone version differs
#
get_mulle_clang_version()
{
   local src="$1"
   local fallback="$2"

   if [ ! -d "${src}" ]
   then
      fail "mulle-clang not downloaded yet"
   fi

   if [ ! -f "${src}/install-mulle-clang.sh" ]
   then
      fail "No MULLE_CLANG_VERSION version found in \"${src}\""
   fi

   local version
   local rc

   version="`head -50 "${src}/install-mulle-clang.sh" \
      | egrep '^MULLE_CLANG_VERSION=' \
      | head -1 \
      | sed 's/.*\"\(.*\)\".*/\1/'`"

   rc="`head -50 "${src}/install-mulle-clang.sh" \
      | egrep '^MULLE_CLANG_RC=' \
      | head -1 \
      | sed 's/.*\"\(.*\)\".*/\1/'`"

   if [ -z "${version}" ]
   then
      log_warning "Could not find MULLE_CLANG_VERSION in download, using default"
      echo "${fallback}"
   else
      if [ -z "${rc}" ]
      then
         echo "${version}"
      else
         echo "${version}-RC${rc}"
      fi
   fi
}


get_runtime_load_version()
{
   local src="$1"

   grep COMPATIBLE_MULLE_OBJC_RUNTIME_LOAD_VERSION "${src}/lib/CodeGen/CGObjCMulleRuntime.cpp" \
    | head -1 \
    | awk '{ print $3 }'
}


get_clang_vendor()
{
   local src="$1"
   local compiler_version="$2"

   local compiler_version
   local runtime_load_version

   runtime_load_version="`get_runtime_load_version "${src}"`"
   if [ -z "${runtime_load_version}" ]
   then
      fail "Could not determine runtime load version"
   fi

   echo "mulle-clang ${compiler_version} (runtime-load-version: `eval echo ${runtime_load_version}`)"
}


#
# Setup environment
#
setup_build_environment()
{
   local version
   local minor
   local major

   #
   # Ninja is probably preferable if installed
   # Should configure this though somewhere
   # Unfortunately on mingw, compile errors in libcxx
   # as ninja picks up the wrong c.
   #
   if [ "${OPTION_NINJA}" = "YES" -a ! -z "`command -v ninja`" ]
   then
      CMAKE_GENERATOR="Ninja"
      MAKE=ninja
   fi

   #
   # make sure cmake and git and gcc are present (and in the path)
   # should check version
   # Set some defaults so stuff possibly just magically works.
   #
   case "${UNAME}" in
      MINGW*)
         log_fluff "Detected MinGW on Windows"
         PATH="$PATH:/c/Program Files/CMake/bin/cmake:/c/Program Files (x86)/Microsoft Visual Studio 14.0/VC/bin"

         install_binary_if_missing "xz" "https://tukaani.org/xz and then add the directory containing xz to your %PATH%"

         if [ -z "${MAKE}" ]
         then
            install_binary_if_missing "nmake" "https://www.visualstudio.com/de-de/downloads/download-visual-studio-vs.aspx and then add the directory containing nmake to your %PATH%"

            CMAKE_GENERATOR="NMake Makefiles"
            MAKE=nmake.exe
         fi

         CXX_COMPILER=cl.exe
         C_COMPILER=cl.exe
      ;;

      #
      # FreeBSD needs rpath set for c++ libraries
      #
      FreeBSD)
         CMAKE_FLAGS="${CMAKE_FLAGS} -DCMAKE_SHARED_LINKER_FLAGS=-Wl,-rpath,\\\$ORIGIN/../lib"
      ;;

      *)
         log_fluff "Detected ${UNAME}"
         install_binary_if_missing "python" "https://www.python.org/downloads/release"

         if [ -z "${MAKE}" ]
         then
            install_binary_if_missing "make" "somewhere"

            CMAKE_GENERATOR="Unix Makefiles"
            MAKE="make"
            MAKE_FLAGS="${MAKE_FLAGS} -j `get_core_count`"
         fi
      ;;
   esac

   check_and_build_cmake

   if [ "${CXX_COMPILER}" = "g++" ]
   then
      install_binary_if_missing "g++" "https://gcc.gnu.org/install/download.html"
   else
      if [ "${CXX_COMPILER}" = "clang++" ]
      then
         install_binary_if_missing "clang++" "http://clang.llvm.org/get_started.html"
      else
         install_binary_if_missing "${CXX_COMPILER}" "somewhere (cpp compiler)"
      fi
   fi

   if [ "${C_COMPILER}" = "gcc" ]
   then
      install_binary_if_missing "gcc" "https://gcc.gnu.org/install/download.html"
   else
      if [ "${C_COMPILER}" = "clang" ]
      then
         install_binary_if_missing "clang" "http://clang.llvm.org/get_started.html"
      else
         install_binary_if_missing "${C_COMPILER}" "somewhere (c compiler)"
      fi
   fi

   if [ "${BUILD_LLDB}" = "YES" ]
   then
      install_binary_if_missing "swig" "http://swig.org/download.html"

      case "${UNAME}" in
         Darwin)
         ;;

         Linux)
            install_library_if_missing "python-dev" "https://www.python.org/downloads/release"
            install_library_if_missing "libncurses5-dev" "https://www.gnu.org/software/ncurses"
            install_library_if_missing "libxml2-dev" "http://xmlsoft.org"
            install_library_if_missing "libedit-dev" "http://thrysoee.dk/editline"
         ;;

         *)
         ;;
      esac
   fi
}


is_kosher_download()
{
   if [ ! -f "${1}" ]
   then
      return 0
   fi

   local size

   size="`du -k "${1}" | awk '{ print $1}'`"
   [ "${size}" -gt 16 ]
}


incremental_download()
{
   local filename="$1"
   local url="$2"
   local name="$3"

   if [ ! -f "${filename}" ]
   then
      local partialfilename

      partialfilename="_${filename}"
      if ! is_kosher_download "${filename}"
      then
         exekutor rm "${partialfilename}"
      fi

      log_verbose "Downloading \"${name}\" from \"${url}\" ..."
      exekutor curl -L -C- -o "${partialfilename}" "${url}"  || fail "curl failed"
      case "${filename}" in
         *gz)
            exekutor tar tfz "${partialfilename}" > /dev/null || tar_fail "tar archive corrupt"
         ;;

         *xz)
            exekutor tar tfJ "${partialfilename}" > /dev/null || tar_fail "tar archive corrupt"
         ;;
      esac
      exekutor mv "${partialfilename}" "${filename}"  || exit 1
   fi
}


extract_tar_gz_archive()
{
   local filename="$1"
   local dst="$2"
   local name="$3"

   [ -d "${dst}" ] && fail "${dst} already exists"

   log_verbose "Unpacking into \"${dst}\" ..."

   local extractname

   extractname="`basename -- "${filename}" ".tar.gz"`"

   exekutor tar xfz "${filename}" || tar_fail ".tar.gz"
   exekutor mkdir -p "`dirname -- "${dst}"`" 2> /dev/null
   exekutor mv "${extractname}" "${dst}" || exit 1
}


extract_tar_xz_archive()
{
   local filename="$1"
   local dst="$2"
   local name="$3"

   [ -d "${dst}" ] && fail "${dst} already exists"

   log_verbose "Unpacking into \"${dst}\" ..."

   local extractname

   extractname="`basename -- "${filename}" ".tar.xz"`"

   exekutor tar xfJ "${filename}" || tar_fail ".tar.xz"
   exekutor mkdir -p "`dirname -- "${dst}"`" 2> /dev/null
   exekutor mv "${extractname}" "${dst}" || exit 1
}


_llvm_module_download()
{
   local name="$1"
   local archive="$2"
   local dst="$3"

   local filename

   filename="`basename -- "${archive}"`"

   incremental_download "${filename}" "${archive}" "${name}" &&
   extract_tar_xz_archive "${filename}" "${dst}" "${name}"
}


download_llvm()
{
   if [ ! -d "${LLVM_DIR}" ]
   then
      log_info "mulle-llvm ${LLVM_VERSION}"

      exekutor mkdir -p "`dirname -- "${SRC_DIR}"`" 2> /dev/null || exit 1

      _llvm_module_download "llvm" "${LLVM_ARCHIVE}" "${SRC_DIR}/llvm"

      if [ "${OPTION_PATCH_LLVM}" = "YES" ]
      then
         patch_llvm "${LLVM_DIR}"
      fi
   fi

   if [ -z "${NO_LIBCXX}" ]
   then
      if [ ! -d "${LLVM_DIR}/projects/libcxx" ]
      then
         _llvm_module_download "libcxx" "${LIBCXX_ARCHIVE}" "${LLVM_DIR}/projects/libcxx"
      else
         log_fluff "\"${LLVM_DIR}/projects/libcxx\" already exists"
      fi

      if [ ! -d "${LLVM_DIR}/projects/libcxxabi" ]
      then
         _llvm_module_download "libcxxabi" "${LIBCXXABI_ARCHIVE}" "${LLVM_DIR}/projects/libcxxabi"
      else
         log_fluff "\"${LLVM_DIR}/projects/libcxxabi\" already exists"
      fi
   else
      log_fluff "Skipped libcxx"
   fi
}


download_clang()
{
   if [ ! -d "${MULLE_CLANG_DIR}" ]
   then
      log_info "mulle-clang ${MULLE_CLANG_ARCHIVENAME}"

      incremental_download "${MULLE_CLANG_UNPACKNAME}.tar.gz" "${MULLE_CLANG_ARCHIVE}" "mulle-clang" &&
      extract_tar_gz_archive "${MULLE_CLANG_UNPACKNAME}.tar.gz" "${MULLE_CLANG_DIR}" "mulle-clang"
   else
      log_fluff "\"${MULLE_CLANG_DIR}\" already exists"
   fi
}


download_lldb()
{
   if [ ! -d "${MULLE_LLDB_DIR}" ]
   then
      log_info "mulle-lldb ${MULLE_LLDB_ARCHIVENAME}"

      incremental_download "${MULLE_LLDB_UNPACKNAME}.tar.gz" "${MULLE_LLDB_ARCHIVE}" "mulle-lldb" &&
      extract_tar_gz_archive "${MULLE_LLDB_UNPACKNAME}.tar.gz" "${MULLE_LLDB_DIR}" "mulle-lldb"
   else
      log_fluff "\"${MULLE_LLDB_DIR}\" already exists"
   fi
}

#
# on Debian, llvm doesn't build properly with clang
# use gcc, which is the default compiler for cmake
#
_build_llvm()
{
   #
   # Build llvm
   #
   if [ ! -f "${LLVM_BUILD_DIR}/Makefile" -o "${RUN_LLVM_CMAKE}" = "YES" ]
   then
      exekutor mkdir -p "${LLVM_BUILD_DIR}" 2> /dev/null

      set -e
         exekutor cd "${LLVM_BUILD_DIR}"
            CC="${C_COMPILER}" CXX="${CXX_COMPILER}" exekutor cmake \
               -Wno-dev \
               -G "${CMAKE_GENERATOR}" \
               -DCLANG_VENDOR="${CLANG_VENDOR}" \
               -DCLANG_LINKS_TO_CREATE="mulle-clang;mulle-clang-cl;mulle-clang-cpp" \
               -DCMAKE_BUILD_TYPE="${LLVM_BUILD_TYPE}" \
               -DCMAKE_INSTALL_PREFIX="${MULLE_LLVM_INSTALL_PREFIX}" \
               -DLLVM_ENABLE_CXX1Y:BOOL=OFF \
               ${CMAKE_FLAGS} \
               "${BUILD_RELATIVE}/../${LLVM_DIR}"
         exekutor cd "${OWD}"
      set +e
   fi

   exekutor cd "${LLVM_BUILD_DIR}" || fail "build_llvm: ${LLVM_BUILD_DIR} missing"
   # hmm
   CC="${C_COMPILER}" CXX="${CXX_COMPILER}" exekutor ${MAKE} ${MAKE_FLAGS} "$@" || fail "build_llvm: ${MAKE} failed"
   exekutor cd "${OWD}"
}


build_llvm()
{
   log_info "Building llvm ${LLVM_VERSION} ..."

   _build_llvm "$@"
}


#
# on Debian, clang doesn't build properly with gcc
# use clang, if available (as CXX_COMPILER)
#
_build_clang()
{
   #
   # Build mulle-clang
   #
   if [ ! -f "${MULLE_CLANG_BUILD_DIR}/Makefile" ]
   then
      exekutor mkdir -p "${MULLE_CLANG_BUILD_DIR}" 2> /dev/null

      set -e
         exekutor cd "${MULLE_CLANG_BUILD_DIR}"

            PATH="${LLVM_BIN_DIR}:$PATH"


            # cmake -DCMAKE_BUILD_TYPE=Debug "../${MULLE_CLANG_DIR}"
            # try to build cmake with cmake
            CC="${C_COMPILER}" CXX="${CXX_COMPILER}" \
               exekutor cmake \
                  -Wno-dev \
                  -G "${CMAKE_GENERATOR}" \
                  -DCLANG_VENDOR="${CLANG_VENDOR}" \
                  -DCLANG_LINKS_TO_CREATE="mulle-clang;mulle-clang-cl;mulle-clang-cpp" \
                  -DCMAKE_BUILD_TYPE="${MULLE_CLANG_BUILD_TYPE}" \
                  -DCMAKE_INSTALL_PREFIX="${MULLE_CLANG_INSTALL_PREFIX}" \
                  ${CMAKE_FLAGS} \
                  "${BUILD_RELATIVE}/../${MULLE_CLANG_DIR}"
         exekutor cd "${OWD}"
      set +e
   fi

   exekutor cd "${MULLE_CLANG_BUILD_DIR}" || fail "build_clang: ${MULLE_CLANG_BUILD_DIR} missing"
   CC="${C_COMPILER}" CXX="${CXX_COMPILER}" exekutor ${MAKE} ${MAKE_FLAGS} "$@" || fail "build_clang: ${MAKE} failed"
   exekutor cd "${OWD}"
}


build_clang()
{
   log_fluff "Build clang..."

   _build_clang "$@"
}



download()
{
#
# try to download most problematic first
# instead of downloading llvm first for an hour...
# but this won't work if we are doing it by the book
#
   if [ "${BUILD_LLVM}" = "YES" -a "${BY_THE_BOOK}" = "YES" ]
   then
      download_llvm
   fi

   if [ "${BUILD_CLANG}" = "YES" ]
   then
      download_clang

      #
      # now we can derive some more values
      #
      MULLE_CLANG_VERSION="`get_mulle_clang_version "${MULLE_CLANG_DIR}" "${MULLE_CLANG_VERSION}"`" || exit 1
      CLANG_VENDOR="`get_clang_vendor "${MULLE_CLANG_DIR}" "${MULLE_CLANG_VERSION}"`" || exit 1

      log_verbose "CLANG_VENDOR=${CLANG_VENDOR}"
      log_verbose "MULLE_CLANG_VERSION=${MULLE_CLANG_VERSION}"
   fi

   if [ "${BUILD_LLDB}" = "YES" ]
   then
      download_lldb

      #
      # now we can derive some more values
      #
#      MULLE_LLDB_VERSION="`get_mulle_lldb_version "${MULLE_LLDB_DIR}" "${MULLE_LLDB_VERSION}"`" || exit 1
#      LLDB_VENDOR="`get_lldb_vendor "${MULLE_LLDB_DIR}" "${MULLE_LLDB_VERSION}"`" || exit 1

#      log_verbose "LLDB_VENDOR=${LLDB_VENDOR}"
   fi

# should check if llvm is installed, if yes
# check proper version and then use it
   if [ "${BUILD_LLVM}" = "YES" -a "${BY_THE_BOOK}" = "NO" ]
   then
      download_llvm
   fi
}


build()
{
   log_info "Building mulle-clang ${MULLE_CLANG_VERSION} ..."

   if [ "${OPTION_WARN}" = "YES" ]
   then
      if [ -d ${PREFIX}/lib -o \
           -d ${PREFIX}/include -o \
           -d ${PREFIX}/bin -o \
           -d ${PREFIX}/libexec -o \
           -d ${PREFIX}/share ]
      then
         log_warning "There are artifacts left over from a previous run.
If you are upgrading to a new version of llvm, you
should [CTRL]-[C] now and do:
   ${C_RESET}${C_BOLD}sudo rm -rf ${PREFIX}/bin ${BUILD_DIR} ${PREFIX}/include ${PREFIX}/lib ${PREFIX}/libexec ${PREFIX}/share"
         sleep 8
      else
         if [ -d "${BUILD_DIR}" ]
         then
            log_warning "As there is an old ${BUILD_DIR} folder here, the previous build
is likely to get reused. If this is not what you want, [CTRL]-[C] now and do:
   ${C_RESET}${C_BOLD}sudo rm -rf ${BUILD_DIR}"
            sleep 4
         fi
      fi
   fi

# should check if llvm is installed, if yes
# check proper version and then use it
   if [ "${BUILD_LLVM}" = "YES" ]
   then
      if [ "${INSTALL_LLVM}" = "YES" ]
      then
         build_llvm install
      else
         build_llvm
      fi
   fi

   if [ "${BUILD_CLANG}" = "YES" -a "${BY_THE_BOOK}" = "NO" ]
   then
      build_clang install
   fi

   if [ "${BUILD_LLDB}" = "YES" -a "${BY_THE_BOOK}" = "NO" ]
   then
      build_lldb install
   fi
}


_build()
{
# should check if llvm is installed, if yes
# check proper version and then use it
   if [ "${BUILD_LLVM}" = "YES" ]
   then
      if [ "${INSTALL_LLVM}" = "YES" ]
      then
         _build_llvm install
      else
         _build_llvm
      fi
   fi

   if [ "${BUILD_CLANG}" = "YES" -a "${BY_THE_BOOK}" = "NO" ]
   then
      _build_clang install
   fi

   if [ "${BUILD_LLDB}" = "YES" -a "${BY_THE_BOOK}" = "NO" ]
   then
      _build_lldb install
   fi
}


install_executable()
{
   local  src
   local  dst
   local  dstname

   src="$1"
   dstname="$2"
   dstdir="${3:-${SYMLINK_PREFIX}/bin}"

   log_fluff "Create symbolic link ${dstdir}/${dstname}"

   if [ ! -w "${dstdir}" ]
   then
      exekutor sudo_if_needed mkdir -p "${dstdir}"
      exekutor sudo_if_needed ln -s -f "${src}" "${dstdir}/${dstname}"
   else
      exekutor ln -s -f "${src}" "${dstdir}/${dstname}"
   fi
}


install_mulle_clang_link()
{
   log_info "Installing mulle-clang (and mulle-scan-build) link ..."

   if [ ! -f "${MULLE_CLANG_INSTALL_PREFIX}/bin/clang${EXE_EXTENSION}" ]
   then
      fail "download and build mulle-clang with
   ./install-mulle-clang.sh
before you can install"
   fi

   if [ -z "${CLANG_SUFFIX}" ]
   then
      install_executable "${MULLE_CLANG_INSTALL_PREFIX}/bin/mulle-clang${CLANG_SUFFIX}${EXE_EXTENSION}" \
                         "mulle-clang${CLANG_SUFFIX}${EXE_EXTENSION}"
      install_executable "${MULLE_CLANG_INSTALL_PREFIX}/bin/scan-build${CLANG_SUFFIX}${EXE_EXTENSION}" \
                         "mulle-scan-build${CLANG_SUFFIX}${EXE_EXTENSION}"
   fi
   install_executable "${MULLE_CLANG_INSTALL_PREFIX}/bin/mulle-clang${CLANG_SUFFIX}${EXE_EXTENSION}" \
                      "mulle-clang${EXE_EXTENSION}"
   install_executable "${MULLE_CLANG_INSTALL_PREFIX}/bin/scan-build${CLANG_SUFFIX}${EXE_EXTENSION}" \
                      "mulle-scan-build${EXE_EXTENSION}"
}


install_mulle_lldb_link()
{
   log_info "Installing mulle-lldb link ..."

   if [ ! -f "${MULLE_CLANG_INSTALL_PREFIX}/bin/lldb${EXE_EXTENSION}" ]
   then
      fail "download and build mulle-lldb with
   ./install-mulle-clang.sh
before you can install"
   fi

   install_executable "${MULLE_LLDB_INSTALL_PREFIX}/bin/lldb${CLANG_SUFFIX}${EXE_EXTENSION}" \
                      mulle-lldb${CLANG_SUFFIX}${EXE_EXTENSION}
   install_executable "${MULLE_LLDB_INSTALL_PREFIX}/bin/lldb-mi${CLANG_SUFFIX}${EXE_EXTENSION}" \
                      mulle-lldb-mi${CLANG_SUFFIX}${EXE_EXTENSION}
}



uninstall_executable()
{
   local path

   path="${1}${EXE_EXTENSION}"

   if [ -e "${path}" ]
   then
      log_fluff "remove ${path}"

      if [ ! -w "${path}" ]
      then
         exekutor sudo_if_needed rm "${path}"
      else
         exekutor rm "${path}"
      fi
   else
      log_fluff "${path} is already gone"
   fi
}


uninstall_mulle_clang_link()
{
   local prefix

   log_info "Uninstalling mulle-clang (and mulle-scan-build) link ..."

   prefix="${1:-${MULLE_CLANG_INSTALL_PREFIX}}"

   if [ -z "${CLANG_SUFFIX}" ]
   then
      uninstall_executable "${prefix}/bin/mulle-clang${CLANG_SUFFIX}${EXE_EXTENSION}"
      uninstall_executable "${prefix}/bin/scan-build${CLANG_SUFFIX}${EXE_EXTENSION}"
   fi
   uninstall_executable "${prefix}/bin/mulle-clang${CLANG_SUFFIX}${EXE_EXTENSION}"
   uninstall_executable "${prefix}/bin/scan-build${CLANG_SUFFIX}${EXE_EXTENSION}"
}



uninstall_mulle_lldb_link()
{
   local prefix

   log_info "Uninstalling mulle-lldb link ..."

   prefix="${1:-${MULLE_CLANG_INSTALL_PREFIX}}"

   uninstall_executable "${prefix}/bin/mulle-lldb${CLANG_SUFFIX}"
   uninstall_executable "${prefix}/bin/mulle-lldb-mi${CLANG_SUFFIX}"
}


install_links()
{
   install_mulle_clang_link
   install_mulle_lldb_link
}


uninstall_links()
{
   uninstall_mulle_clang_link
   uninstall_mulle_lldb_link
}



main()
{
   OWD="`pwd -P`"
   PREFIX="${OWD}"

   local BUILD_CLANG="${BUILD_CLANG:-YES}"
   local BUILD_LLVM="${BUILD_LLVM:-YES}"
   local BUILD_LLDB="${BUILD_LLDB:-YES}"
   local INSTALL_LLVM="${INSTALL_LLVM:-YES}"
   local OPTION_NINJA="YES"
   local OPTION_PATCH_LLVM="YES"
   local OPTION_WARN="YES"

   while [ $# -ne 0 ]
   do
      case "$1" in
         -t|--trace)
            set -x
         ;;

         -n)
            MULLE_FLAG_EXECUTOR_DRY_RUN="YES"
         ;;

         -V)
            MULLE_FLAG_LOG_EXECUTOR="YES"
         ;;

         -v|--verbose)
            FLUFF=
            VERBOSE="YES"
         ;;

         -vv|--very-verbose)
            FLUFF="YES"
            VERBOSE="YES"
            MULLE_FLAG_LOG_EXECUTOR="YES"
         ;;

         --all-in-one)
            BY_THE_BOOK="YES"
         ;;

         --separate)
            BY_THE_BOOK="NO"
         ;;

         --build-cmake)
            BUILD_CMAKE="YES"
         ;;

         --with-lldb|--build-lldb)
            BUILD_LLDB="YES"
         ;;

         --debug)
            LLVM_BUILD_TYPE="Debug"
            MULLE_CLANG_BUILD_TYPE="Debug"
         ;;

         --llvm-debug)
            LLVM_BUILD_TYPE="Debug"
         ;;

         --clang-debug)
            MULLE_CLANG_BUILD_TYPE="Debug"
         ;;

         --lldb-debug)
            LLDB_BUILD_TYPE="Debug"
         ;;

         --no-patch-llvm)
            OPTION_PATCH_LLVM="NO"
         ;;

         --prefix)
            [ $# -eq 1 ] && fail "missing argument to $1"
            shift
            PREFIX="$1"
         ;;

         --clang-prefix)
            [ $# -eq 1 ] && fail "missing argument to $1"
            shift
            MULLE_CLANG_INSTALL_PREFIX="$1"
         ;;

         --llvm-prefix)
            [ $# -eq 1 ] && fail "missing argument to $1"
            shift
            MULLE_LLVM_INSTALL_PREFIX="$1"
         ;;

         --lldb-prefix)
            [ $# -eq 1 ] && fail "missing argument to $1"
            shift
            MULLE_LLDB_INSTALL_PREFIX="$1"
         ;;

         --symlink-prefix)
            [ $# -eq 1 ] && fail "missing argument to $1"
            shift
            SYMLINK_PREFIX="$1"
         ;;


         --no-ninja)
            OPTION_NINJA="NO"
         ;;

         --no-libcxx)
            NO_LIBCXX="YES"
         ;;

         --no-warn)
            OPTION_WARN="NO"
         ;;

         -*)
            echo "unknown option $1" >&2
            exit 1
         ;;

         *)
            break
         ;;
      esac

      shift
   done

   COMMAND="${1:-default}"
   [ $# -eq 0 ] || shift

   # shouldn't thsis be CC /CXX ?
   C_COMPILER="${CC}"
   if [ -z "${C_COMPILER}" ]
   then
      C_COMPILER="`command -v "clang"`"
      if [ -z "${C_COMPILER}" ]
      then
         C_COMPILER="`command -v "gcc"`"
         if [ -z "${C_COMPILER}" ]
         then
            C_COMPILER="gcc"
         fi
      fi
      C_COMPILER="`basename "${C_COMPILER}"`"
   fi

   CXX_COMPILER="${CXX}"
   CXX_COMPILER="${CXX_COMPILER:-${C_COMPILER}++}"

   if [ "${CXX_COMPILER}" = "gcc++" ]
   then
      CXX_COMPILER="g++"
   fi

   #
   # it makes little sense to change these
   #
   SRC_DIR="src"

   LLVM_BUILD_TYPE="${LLVM_BUILD_TYPE:-Release}"
   LLDB_BUILD_TYPE="${LLDB_BUILD_TYPE:-Release}"
   MULLE_CLANG_BUILD_TYPE="${MULLE_CLANG_BUILD_TYPE:-Release}"

   LLVM_DIR="${SRC_DIR}/llvm"
   if [ "${BY_THE_BOOK}" = "YES" ]
   then
      # must use "clang" as name, because lldb will expect it there
      # and then use lldb also for consistency
      MULLE_CLANG_DIR="${LLVM_DIR}/tools/clang"
      MULLE_LLDB_DIR="${LLVM_DIR}/tools/lldb"
   else
      MULLE_CLANG_DIR="${SRC_DIR}/mulle-clang"
      MULLE_LLDB_DIR="${SRC_DIR}/mulle-lldb"
   fi

   BUILD_DIR="build"
   BUILD_RELATIVE=".."

   # different builds for OS Versions on OS X
   case "${UNAME}" in
      Darwin)
         osxversion="`sw_vers -productVersion | cut -d. -f 1-2`"
         BUILD_DIR="build-${osxversion}"
         if [ "${PREFIX}" = "${OWD}" ]
         then
            PREFIX="${OWD}/${osxversion}"
         fi
      ;;
   esac

   #
   # Now with prefix set...
   #
   PATH="${PREFIX}/bin:$PATH"; export PATH

   [ -z "${PREFIX}" ] && fail "PREFIX is empty"

   MULLE_LLVM_INSTALL_PREFIX="${MULLE_LLVM_INSTALL_PREFIX:-${PREFIX}}"
   MULLE_CLANG_INSTALL_PREFIX="${MULLE_CLANG_INSTALL_PREFIX:-${PREFIX}}"
   MULLE_LLDB_INSTALL_PREFIX="${MULLE_LLDB_INSTALL_PREFIX:-${PREFIX}}"

   [ -z "${MULLE_LLVM_INSTALL_PREFIX}" ] && fail "MULLE_LLVM_INSTALL_PREFIX is empty"

   LLVM_BUILD_DIR="${BUILD_DIR}/llvm.d"
   MULLE_CLANG_BUILD_DIR="${BUILD_DIR}/mulle-clang.d"
   MULLE_LLDB_BUILD_DIR="${BUILD_DIR}/mulle-lldb.d"

   # override this to use pre-installed llvm

   LLVM_BIN_DIR="${LLVM_BIN_DIR:-${LLVM_BUILD_DIR}/bin}"

   # if manually changed rerun cmake even if Makefile exists
   if [ "${LLVM_BUILD_TYPE}" != "Release" ]
   then
      RUN_LLVM_CMAKE="YES"
   fi

   # blurb a little, this has some advantages

   log_verbose "SYMLINK_PREFIX=${SYMLINK_PREFIX}"

   setup_build_environment

   case "$COMMAND" in
      install)
         install_links "$@"
      ;;

      default)
         download
         build
      ;;

      download)
         download
      ;;

      build)
         build
      ;;

      _build)
         _build
      ;;

      uninstall)
         uninstall_links
      ;;
   esac
}

MULLE_EXECUTABLE_PID="$$"

environment_initialize
log_initialize
main "$@"
