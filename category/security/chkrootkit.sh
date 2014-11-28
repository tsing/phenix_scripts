#! /bin/sh
# -*- Shell-script -*-

# $Id: chkrootkit, v 0.50 2014/05/25
CHKROOTKIT_VERSION='0.50'

# Authors: Nelson Murilo <nelson@pangeia.com.br> (main author) and
#          Klaus Steding-Jessen <jessen@cert.br>
#
# (c)1997-2014 Nelson Murilo, Pangeia Informatica, AMS Foundation and others.
# All rights reserved

# name
# 检查RootKit
# desc
# chkrootkit (Check Rootkit) is a common Unix-based program intended to help system administrators check their system for known rootkits

### workaround for some Bourne shell implementations
unalias login > /dev/null 2>&1
unalias ls > /dev/null 2>&1
unalias netstat > /dev/null 2>&1
unalias ps > /dev/null 2>&1
unalias dirname > /dev/null 2>&1

# Workaround for recent GNU coreutils
_POSIX2_VERSION=199209
export _POSIX2_VERSION

KALLSYMS="/proc/kallsyms" 
[ -f /proc/ksysm ] && KALLSYMS="/proc/$KALLSYMS" 

# Native commands
TROJAN="amd basename biff chfn chsh cron crontab date du dirname echo egrep \
env find fingerd gpm grep hdparm su ifconfig inetd inetdconf identd init \
killall  ldsopreload login ls lsof mail mingetty netstat named passwd pidof \
pop2 pop3 ps pstree rpcinfo rlogind rshd slogin sendmail sshd syslogd tar tcpd \
tcpdump top telnetd timed traceroute vdir w write"

# Tools
TOOLS="aliens asp bindshell lkm rexedcs sniffer w55808 wted scalper slapper z2 chkutmp OSX_RSPLUG"

# Return Codes
INFECTED=0
NOT_INFECTED=1
NOT_TESTED=2
NOT_FOUND=3
INFECTED_BUT_DISABLED=4

# Many trojaned commands have this label
GENERIC_ROOTKIT_LABEL="^/bin/.*sh$|bash|elite$|vejeta|\.ark|iroffer"

######################################################################
# tools functions

#
# 55808.A Worm
#
w55808 (){
   W55808_FILES="${ROOTDIR}tmp/.../a ${ROOTDIR}tmp/.../r"
   STATUS=0

   for i in ${W55808_FILES}; do
      if [ -f ${i} ]; then
         STATUS=1
      fi
   done
   if [ ${STATUS} -eq 1 ] ;then
      echo "Warning: Possible 55808 Worm installed"
   else
      if [ "${QUIET}" != "t" ]; then echo "not infected"; fi
         return ${NOT_INFECTED}
   fi
}

OSX_RSPLUG (){
       SAVEIFS=$IFS
       IFS=';'
       STATUS=0
       OSX_RSPLUG_FILES='/Library/Internet Plug-Ins/QuickTime.xpt;/Library/Internet Plug-Ins/plugins.settings'
       #echo checking ${OSX_RSPLUG_FILES}
       for i in ${OSX_RSPLUG_FILES} ; do
               #echo searching for "${i}"
               if [ -e "${i}" ] ; then
                       STATUS=1
               fi
       done
       IFS=$SAVEIFS

   if [ ${STATUS} -eq 1 ] ;then
      echo "Warning: OSX.RSPlug.A Trojan Horse found"
      return ${INFECTED}
   else
      if [ "${QUIET}" != "t" ]; then echo "not infected"; fi
         return ${NOT_INFECTED}
   fi
}

#
# SLAPPER.{A,B,C,D} and the multi-platform variant
#
slapper (){
   SLAPPER_FILES="${ROOTDIR}tmp/.bugtraq ${ROOTDIR}tmp/.bugtraq.c"
   SLAPPER_FILES="$SLAPPER_FILES ${ROOTDIR}tmp/.unlock ${ROOTDIR}tmp/httpd \
   ${ROOTDIR}tmp/update ${ROOTDIR}tmp/.cinik ${ROOTDIR}tmp/.b"
   SLAPPER_PORT="0.0:2002 |0.0:4156 |0.0:1978 |0.0:1812 |0.0:2015 "
   OPT=-an
   STATUS=0
   file_port=

   if ${netstat} "${OPT}"|${egrep} "^tcp"|${egrep} "${SLAPPER_PORT}"> /dev/null 2>&1
      then
      STATUS=1
      [ "$SYSTEM" = "Linux" ] && file_port=`netstat -p ${OPT} | \
         $egrep ^tcp|$egrep "${SLAPPER_PORT}" | ${awk} '{ print  $7 }' | tr -d :`
   fi
   for i in ${SLAPPER_FILES}; do
      if [ -f ${i} ]; then
   file_port="$file_port $i" 
         STATUS=1
      fi
   done
   if [ ${STATUS} -eq 1 ] ;then
      echo "Warning: Possible Slapper Worm installed ($file_port)"
   else
      if [ "${QUIET}" != "t" ]; then echo "not infected"; fi
         return ${NOT_INFECTED}
   fi
}

scalper (){
   SCALPER_FILES="${ROOTDIR}tmp/.uua ${ROOTDIR}tmp/.a"
   SCALPER_PORT=2001
   OPT=-an
   STATUS=0

   if ${netstat} "${OPT}" | ${egrep} "0.0:${SCALPER_PORT} "> /dev/null 2>&1; then
      STATUS=1
   fi
   for i in ${SCALPER_FILES}; do
      if [ -f ${i} ]; then
         STATUS=1
      fi
   done
   if [ ${STATUS} -eq 1 ] ;then
      echo "Warning: Possible Scalper Worm installed"
   else
      if [ "${QUIET}" != "t" ]; then echo "not infected"; fi
         return ${NOT_INFECTED}
   fi
}

asp (){
    ASP_LABEL="poop"
    STATUS=${NOT_INFECTED}
    CMD=`loc asp asp $pth`

    if [ "${EXPERT}" = "t" ]; then
        expertmode_output "${egrep} ^asp ${ROOTDIR}etc/inetd.conf"
        expertmode_output "${strings} -a ${CMD}"
        return 5
    fi

    if ${egrep} "^asp" ${ROOTDIR}etc/inetd.conf >/dev/null 2>&1; then
        echo "Warning: Possible Ramen Worm installed in inetd.conf"
        STATUS=${INFECTED}
    fi
    if [ ${CMD} = "asp"  -o ${CMD} = "${ROOTDIR}asp" ]; then
        if [ "${QUIET}" != "t" ]; then echo "not infected"; fi
        return ${NOT_INFECTED}
    fi
    if ${strings} -a ${CMD} | ${egrep} "${ASP_LABEL}" >/dev/null 2>&1; then
       echo "INFECTED"
       STATUS=${INFECTED}
    else
        if [ "${QUIET}" != "t" ]; then echo "not infected"; fi
        return ${NOT_INFECTED}
    fi
    return ${STATUS}
}

sniffer () {
    if [ "${ROOTDIR}" != "/" ]; then
      echo "not tested"
      return ${NOT_TESTED}
    fi

    if [ "$SYSTEM" = "SunOS" ]; then
       return ${NOT_TESTED}
    fi

    if [ "${EXPERT}" = "t" ]; then
        expertmode_output "./ifpromisc" -v
        return 5
    fi
    if [ ! -x ./ifpromisc ]; then
      echo "not tested: can't exec ./ifpromisc"
      return ${NOT_TESTED}
    else
      [ "${QUIET}" != "t" ] && ./ifpromisc -v || ./ifpromisc -q
    fi
}

chkutmp() {
    if [ ! -x ./chkutmp ]; then
      echo "not tested: can't exec ./chkutmp"
      return ${NOT_TESTED}
    fi
    if ./chkutmp
    then
      if [ "${QUIET}" != "t" ]; then echo "chkutmp: nothing deleted"; fi
    fi

}

z2 () {
    if [ ! -x ./chklastlog ]; then
      echo "not tested: can't exec ./chklastlog"
      return ${NOT_TESTED}
    fi

    WTMP=`loc wtmp wtmp "${ROOTDIR}var/log ${ROOTDIR}var/adm"`
    LASTLOG=`loc lastlog lastlog "${ROOTDIR}var/log ${ROOTDIR}var/adm"`

    if [ ! -f $WTMP -a ! -f $LASTLOG ]; then
       echo "not tested: not found wtmp and/or lastlog file"
       return ${NOT_TESTED}
    fi

    if [ "${EXPERT}" = "t" ]; then
        expertmode_output "./chklastlog -f ${WTMP} -l ${LASTLOG}"
        return 5
    fi

    if ./chklastlog -f ${WTMP} -l ${LASTLOG}
    then
      if [ "${QUIET}" != "t" ]; then echo "chklastlog: nothing deleted"; fi
    fi
}

wted () {
    if [ ! -x ./chkwtmp ]; then
      echo "not tested: can't exec ./chkwtmp"
      return ${NOT_TESTED}
    fi

   if [ "$SYSTEM" = "SunOS" ]; then
       if [ ! -x ./check_wtmpx ]; then
          echo "not tested: can't exec ./check_wtmpx"
       else
          if [ "${EXPERT}" = "t" ]; then
             expertmode_output "./check_wtmpx"
              return 5
          fi
    if [ -f ${ROOTDIR}var/adm/wtmp ]; then
             if ./check_wtmpx
                then
                if [ "${QUIET}" != "t" ]; then \
                   echo "check_wtmpx: nothing deleted in /var/adm/wtmpx"; fi
             fi
    fi
       fi
   else
       WTMP=`loc wtmp wtmp "${ROOTDIR}var/log ${ROOTDIR}var/adm"`

       if [ "${EXPERT}" = "t" ]; then
          expertmode_output "./chkwtmp -f ${WTMP}"
          return 5
       fi
    fi

    if ./chkwtmp -f ${WTMP}
    then
      if [ "${QUIET}" != "t" ]; then echo "chkwtmp: nothing deleted"; fi
    fi
}
bindshell () {
PORT="114|145|465|511|600|1008|1524|1999|1978|2881|3049|3133|3879|4000|4369|5190|5665|6667|10008|12321|23132|27374|29364|30999|31336|31337|37998|45454|47017|47889|60001|7222"
   OPT="-an"
   PI=""
   if [ "${ROOTDIR}" != "/" ]; then
     echo "not tested"
     return ${NOT_TESTED}
   fi

   if [ "${EXPERT}" = "t" ]; then
       expertmode_output "${netstat} ${OPT}"
       return 5
   fi
   for P in `echo $PORT | ${sed} 's/|/ /g'`; do
      if ${netstat} "${OPT}" | ${egrep} "^tcp.*LIST|^udp" | ${egrep} \
"[.:]${P}[^0-9.:]" >/dev/null 2>&1
      then
         PI="${PI} ${P}"
      fi
   done
   if [ "${PI}" != "" ]
   then
      echo "INFECTED (PORTS: $PI)"
   else
      if [ "${QUIET}" != "t" ]; then echo "not infected"; fi
   fi
}

lkm ()
{
    prog=""
    if [  \( "${SYSTEM}" = "Linux"  -o \( "${SYSTEM}" = "FreeBSD" -a \
       `echo ${V} | ${awk} '{ if ($1 > 4.3 || $1 < 6.0) print 1; else print 0 }'` -eq 1 \) \) -a "${ROOTDIR}" = "/" ]; then
      [  -x ./chkproc -a "`find /proc | wc -l`" -gt 1 ] && prog="./chkproc"
      [  -x ./chkdirs ] && prog="$prog ./chkdirs"
      if [ "$prog" = "" ]; then
         echo "not tested: can't exec $prog"
         return ${NOT_TESTED}
      fi

      if [ "${EXPERT}" = "t" ]; then
         [ -r /proc/$KALLSYMS ] &&  ${egrep} -i "adore|sebek" < /proc/$KALLSYMS 2>/dev/null
         [ -d /proc/knark ] &&  ${ls} -la /proc/knark 2> /dev/null
         PV=`$ps -V 2>/dev/null| $cut -d " " -f 3 |${awk} -F . '{ print $1 "." $2 $3 }' | ${awk} '{ if ($0 > 3.19) print 3; else if ($0 < 2.015) print 1; else print 2 }'`
         [ "$PV" = "" ] &&  PV=2
         [ "${SYSTEM}" = "SunOS" ] && PV=0
         expertmode_output "./chkproc -v -v -p $PV"
         return 5
      fi

      ### adore LKM
      [ -r /proc/$KALLSYMS ] && \
      if `${egrep} -i adore < /proc/$KALLSYMS >/dev/null 2>&1`; then
         echo "Warning: Adore LKM installed"
      fi

      ### sebek LKM (Adore based)
      [ -r /proc/$KALLSYMS ] && \
      if `${egrep} -i sebek < /proc/$KALLSYMS >/dev/null 2>&1`; then
         echo "Warning: Sebek LKM installed"
      fi

      ### knark LKM
      if [ -d /proc/knark ]; then
         echo "Warning: Knark LKM installed"
      fi

      PV=`$ps -V 2>/dev/null| $cut -d " " -f 3 |${awk} -F . '{ print $1 "." $2 $3 }' | ${awk} '{ if ($0 > 3.19) print 3; else if ($0 < 2.11) print 1; else print 2 }'`
      [ "$PV" = "" ] &&  PV=2
      [ "${SYSTEM}" = "SunOS" ] && PV=0
      if [ "${DEBUG}" = "t" ]; then
           ${echo} "*** PV=$PV ***"
      fi
      if ./chkproc -p ${PV}; then
         if [ "${QUIET}" != "t" ]; then echo "chkproc: nothing detected"; fi
      else
         echo "chkproc: Warning: Possible LKM Trojan installed"
      fi
      dirs="/tmp"
      for i in /usr/share /usr/bin /usr/sbin /lib; do
         [ -d $i ] && dirs="$dirs $i"
      done
      if ./chkdirs $dirs;  then
         if [ "${QUIET}" != "t" ]; then echo "chkdirs: nothing detected"; fi
      else
      echo "chkdirs: Warning: Possible LKM Trojan installed"
      fi
   else
         if [ "${QUIET}" != "t" ]; then echo "chkproc: not tested"; fi
   fi
}

aliens () {
   if [ "${EXPERT}" = "t" ]; then
        ### suspicious files
        FILES="usr/bin/sourcemask usr/bin/ras2xm usr/sbin/in.telnet \
sbin/vobiscum  usr/sbin/jcd usr/sbin/atd2 usr/bin/.etc usr/bin/xstat \
 etc/ld.so.hash"

        expertmode_output "${find} ${ROOTDIR}dev -type f"
        expertmode_output "${find} ${ROOTDIR}var/run/.tmp"
        expertmode_output "${find} ${ROOTDIR}usr/man/man1/lib/.lib"
        expertmode_output "${find} ${ROOTDIR}usr/man/man2/.man8"
        expertmode_output "${find} ${ROOTDIR}usr/man/man1 -name '.. *'"
        expertmode_output "${find} ${ROOTDIR}usr/share/locale/sk"
        expertmode_output "${find} ${ROOTDIR}usr/lib/dy0"
        expertmode_output "${find} ${ROOTDIR}tmp -name 982235016-gtkrc-429249277"
        expertmode_output "${find} ${ROOTDIR}var/spool/lp/admins/.lp/"

        for i in ${FILES}; do
           expertmode_output "${ls} ${ROOTDIR}${i} 2> /dev/null"
        done
        [ -d  ${ROOTDIR}lib/.so ] && expertmode_output "${find} ${ROOTDIR}lib/.so"
        [ -d "${ROOTDIR}usr/include/.. " ] && expertmode_output ${find} "${ROOTDIR}usr/include/.. "
        [ -d ${ROOTDIR}usr/lib/.fx ] && expertmode_output ${find} ${ROOTDIR}usr/lib/.fx
        [ -d ${ROOTDIR}var/local/.lpd ] && expertmode_output ${find} ${ROOTDIR}var/local/.lpd
        [ -d ${ROOTDIR}dev/rd/cdb ] && expertmode_output ${find} ${ROOTDIR}dev/rd/cdb
        [ -d ${ROOTDIR}/usr/lib/lib.so1.so ] && expertmode_output ${find} ${ROOTDIR}/usr/lib/lib.so1.so
        ### sniffer's logs
        expertmode_output "${find} ${ROOTDIR}dev ${ROOTDIR}usr ${ROOTDIR}tmp \
  ${ROOTDIR}lib ${ROOTDIR}etc ${ROOTDIR}var ${findargs} -name tcp.log -o -name \
.linux-sniff -o -name sniff-l0g -o -name core_ -o"
        expertmode_output "${find} ${ROOTDIR}usr/lib -name in.httpd -o \
-name in.pop3d"

        ### t0rn
        expertmode_output "${find} ${ROOTDIR}etc ${ROOTDIR}sbin \
${ROOTDIR}usr/src/.puta ${ROOTDIR}lib ${ROOTDIR}usr/info -name \
ttyhash -o -name xlogin -o -name ldlib.tk -o -name .t?rn"

        LIBS=
        [ -d ${ROOTDIR}lib ] && LIBS="${ROOTDIR}lib"
        [ -d ${ROOTDIR}usr/lib ] && LIBS="${LIBS} ${ROOTDIR}usr/lib"
        [ -d ${ROOTDIR}usr/local/lib ] && \
           LIBS="${LIBS} ${ROOTDIR}usr/local/lib"

        expertmode_output "${find} ${LIBS} -name libproc.a"

        ## Lion Worm
        expertmode_output "${find} ${ROOTDIR}dev/.lib/lib -name 1i0n.sh
2> /dev/null"

        ### ark
        expertmode_output "${find} ${ROOTDIR}dev -name ptyxx"
        expertmode_output "${find} ${ROOTDIR}usr/doc -name '... '"
        expertmode_output "${find} ${ROOTDIR}usr/lib -name '.ark*'"

        ### RK17
        expertmode_output "${find} ${ROOTDIR}bin -name rtty -o -name squit"
        expertmode_output "${find} ${ROOTDIR}sbin -name pback"
        expertmode_output "${find} ${ROOTDIR}usr/man/man3 -name psid 2> /dev/null"
        expertmode_output "${find} ${ROOTDIR}proc -name kset 2> /dev/null"
        expertmode_output "${find} ${ROOTDIR}usr/src/linux/modules -name \
autod.o -o -name soundx.o 2> /dev/null"
        expertmode_output "${find} ${ROOTDIR}usr/bin -name gib -o \
-name ct -o -name snick -o -name kfl"

        CGIDIR=""
        for cgidir in www/httpd/cgi-bin www/cgi-bin var/www/cgi-bin \
var/lib/httpd/cgi-bin usr/local/httpd/cgi-bin usr/local/apache/cgi-bin \
home/httpd/cgi-bin usr/local/apache2 usr/local/www usr/lib;
        do
           [ -d ${ROOTDIR}${cgidir} ] && CGIDIR="${CGIDIR} ${ROOTDIR}${cgidir}"
        done
BACKDOORS="number.cgi void.cgi psid becys.cgi nobody.cgi bash.zk.cgi alya.cgi \
shell.cgi alin.cgi httpd.cgi linux.cgi sh.cgi take.cgi bogus.cgi alia.cgi all4one.cgi \
zxcvbnm.cgi secure.cgi ubb.cgi r57shell.php"
   for j in ${CGIDIR}; do
      for i in ${BACKDOORS}; do
  [ -f ${j}/${i} ] && echo ${j}/${i}
      done
   done

        ### rsha
        expertmode_output "${find} ${ROOTDIR}bin ${ROOTDIR}usr/bin -name kr4p \
-o -name n3tstat -o -name chsh2"
        expertmode_output "${find} ${ROOTDIR}etc/rc.d/rsha"
        expertmode_output "${find} ${ROOTDIR}etc/rc.d/arch/alpha/lib/.lib \
${ROOTDIR}usr/src/linux/arch/alpha/lib/.lib/"

        ### ShitC Worm
        expertmode_output "${find} ${ROOTDIR}bin ${ROOTDIR}sbin -name home \
-o -name frgy -o -name sy"
        expertmode_output "${find} ${ROOTDIR}usr/bin -type d -name dir"
        expertmode_output "${find} ${ROOTDIR}usr/sbin -type d -name in.slogind"

        ### Omega Worm
        expertmode_output "${find} ${ROOTDIR}dev -name chr"

        ### rh-sharpe
        expertmode_output "${find} ${ROOTDIR}bin ${ROOTDIR}usr/bin -name lps \
-o -name .ps -o -name lpstree -o -name .lpstree -o -name lkillall \
-o -name ldu -o -name lnetstat"
        expertmode_output "${find} ${ROOTDIR}usr/include/rpcsvc -name du"

        ### Adore Worm
        expertmode_output "${find} ${ROOTDIR}usr/lib ${ROOTDIR}usr/bin \
-name red.tar -o -name start.sh -o -name klogd.o -o -name 0anacron-bak \
-o -name adore"
        expertmode_output "${find} ${ROOTDIR}usr/lib/lib"
        expertmode_output "${find} ${ROOTDIR}usr/lib/libt"

        ### suspicious files and dirs
        suspects="/usr/lib/pt07 /usr/bin/atm /tmp/.cheese /dev/ptyzx /dev/ptyzg /usr/bin/sourcemask /dev/ida /dev/xdf* /usr/lib/libx?otps /sbin/init.zk"
        DIR=${ROOTDIR}usr/lib
        [ -d ${ROOTDIR}usr/man ] && DIR="${DIR} ${ROOTDIR}usr/man"
        [ -d ${ROOTDIR}lib ] && DIR="${DIR} ${ROOTDIR}lib"
        [ -d ${ROOTDIR}usr/lib ] && DIR="${DIR} ${ROOTDIR}usr/lib"
        expertmode_output "${find} ${DIR} -name '.[A-Za-z]*'"
        expertmode_output "${find} ${DIR} -type d -name '.*'"
        expertmode_output "${find} ${DIR} -name '...*'"
        expertmode_output "${ls} ${suspects}"

        ### Maniac RK
        expertmode_output "${find} ${ROOTDIR}usr/bin -name mailrc"

        ### Ramen Worm
        expertmode_output "${find} ${ROOTDIR}usr/src/.poop \
${ROOTDIR}tmp/ramen.tgz ${ROOTDIR}etc/xinetd.d/asp"

        ### Sadmind/IIS Worm
        expertmode_output "${find} ${ROOTDIR}dev/cuc"

        ### Monkit
        expertmode_output "${find} ${ROOTDIR}lib/defs"

        ### Showtee
       expertmode_output "${ls} ${ROOTDIR}usr/lib/.egcs \
${ROOTDIR}usr/lib/.wormie \
${ROOTDIR}usr/lib/.kinetic ${ROOTDIR}/usr/lib/liblog.o \
${ROOTDIR}/usr/include/addr.h  ${ROOTDIR}usr/include/cron.h \
${ROOTDIR}/usr/include/file.h ${ROOTDIR}usr/include/proc.h \
${ROOTDIR}/usr/include/syslogs.h ${ROOTDIR}/usr/include/chk.h"

       ### Optickit
       expertmode_output "${find} ${ROOTDIR}usr/bin -name xchk -o -name xsf"

       ### T.R.K
       expertmode_output "${find} ${ROOTDIR}usr/bin -name soucemask -o -name ct"
       ### MithRa's Rootkit
       expertmode_output "${find} ${ROOTDIR}usr/lib/locale -name uboot"


       ### OpenBSD rootkit v1
       if [ \( "$SYSTEM" != "SunOS" -a ${SYSTEM} != "Linux" \) -a ! -f /usr/lib/security/libgcj.security ]
          then
          expertmode_output "${find} ${ROOTDIR}usr/lib/security"
       fi

       ### LOC rootkit
       expertmode_output "${find} ${ROOTDIR}tmp -name xp -o -name kidd0.c"

       ### Romanian rootkit
       expertmode_output "${ls} ${ROOTDIR}usr/include/file.h \
${ROOTDIR}usr/include/proc.h ${ROOTDIR}usr/include/addr.h \
${ROOTDIR}usr/include/syslogs.h"

      ## HKRK rootkit
      ${egrep} "\.hk" ${ROOTDIR}etc/rc.d/init.d/network 2>/dev/null

      ## Suckit rootkit
      expertmode_output "${strings} ${ROOTDIR}sbin/init | ${egrep} HOME"
      expertmode_output "cat ${ROOTDIR}proc/1/maps | ${egrep} init."
      expertmode_output "cat ${ROOTDIR}dev/.golf"

      ## Volc rootkit
      expertmode_output "${ls} ${ROOTDIR}usr/bin/volc"
      expertmode_output "${find} ${ROOTDIR}usr/lib/volc"

      ## Gold2 rootkit
      expertmode_output "${ls} ${ROOTDIR}usr/bin/ishit"

      ## TC2 Worm
      expertmode_output "${ls} ${ROOTDIR}usr/bin/util ${ROOTDIR}usr/info \
${ROOTDIR}usr/sbin/initcheck ${ROOTDIR}usr/sbin/ldb"

      ## Anonoiyng rootkit
      expertmode_output "${ls} ${ROOTDIR}usr/sbin/mech* ${ROOTDIR}usr/sbin/kswapd"

      ## ZK rootkit
      expertmode_output "${ls} ${ROOTDIR}etc/sysconfig/console/load*"

      ## ShKit
      expertmode_output "${ls} ${ROOTDIR}lib/security/.config ${ROOTDIR}etc/ld.so.hash"

      ## AjaKit
      expertmode_output "${find} ${ROOTDIR}lib -name .ligh.gh"
      expertmode_output "${find} ${ROOTDIR}dev -name tux"

      ## zaRwT
      expertmode_output "${find} ${ROOTDIR}bin -name imin -o -name imout"

      ## Madalin rootkit
      expertmode_output "${find} ${ROOTDIR}usr/include -name icekey.h -o \
-name iceconf.h -o -name iceseed.h"

      ## Fu rootkit
      expertmode_output "${find} ${ROOTDIR}sbin ${ROOTDIR}bin \
      ${ROOTDIR}usr/include -name xc -o -name .lib -o name ivtype.h"

      ## Kenga3 Rookit
      expertmode_output "${find} ${ROOTDIR}usr/include/. ."

      ## ESRK Rookit
      expertmode_output "${ls} -l ${ROOTDIR}usr/lib/tcl5.3"

      ## rootedoor
      for i in `$echo ${PATH}|tr -s ':' ' '`; do
         expertmode_output "${ls} -l ${ROOTDIR}${i}/rootedoor"
      done
      ## ENYE-LKM
      expertmode_output "${ls} -l ${ROOTDIR}etc/.enyeOCULTAR.ko"

      ## SSJD Operation Windigo  (Linux/Ebury) 
      expertmode_output "${ssh} -G 2>&1  | grep -e illegal -e unknow" 

      ## Common SSH-SCANNERS
      expertmode_output "${find} ${ROOTDIR}/tmp ${ROOTDIR}/var/tmp ${findargs} -name vuln.txt -o -name ssh-scan -o -name pscan2"

      ### shell history file check
      if [ ! -z "${SHELL}" -a ! -z "${HOME}" ]; then
      expertmode_output "${find} ${ROOTDIR}${HOME} ${findargs} -name .*history \
 -size 0"
      expertmode_output "${find} ${ROOTDIR}${HOME} ${findargs} -name .*history \
 \( -links 2 -o -type l \)"
      fi

      return 5
   ### expert mode ends here
   fi

   ###
   ### suspicious files and sniffer's logs
   ###
   suspects="usr/lib/pt07 usr/bin/atm tmp/.cheese dev/ptyzx dev/ptyzy \
usr/bin/sourcemask dev/ida dev/xdf1 dev/xdf2 usr/bin/xstat \
tmp/982235016-gtkrc-429249277 usr/bin/sourcemask /usr/bin/ras2xm \
usr/sbin/in.telnet sbin/vobiscum  usr/sbin/jcd usr/sbin/atd2 usr/bin/.etc .lp \
etc/ld.so.hash sbin/init.zk usr/lib/in.httpd usr/lib/in.pop3d nlsadmin"
   dir="var/run/.tmp lib/.so usr/lib/.fx var/local/.lpd dev/rd/cdb \
   var/spool/lp/admins/.lp var/adm/sa/.adm usr/lib/lib.so1.so"
   files=`${find} ${ROOTDIR}dev -type f -exec ${egrep} -l "^[0-5] " {} \;`
   if [ "${files}" != "" ]; then
      echo
      echo ${files}
   fi
   for i in ${dir}; do
      if [ -d ${ROOTDIR}${i} ]; then
         echo
         echo "Suspect directory ${i} FOUND! Looking for sniffer logs"
            files=`${find} ${ROOTDIR}${i}`
         echo
         echo ${files}
      fi
   done
   for i in ${suspects}; do
      if [ -f ${ROOTDIR}${i} ]; then
         echo "${ROOTDIR}${i} "
         files="INFECTED"
      fi
   done
   if [ "${files}" = "" ]; then
        if [ "${QUIET}" != "t" ]; then echo "no suspect files"; fi
   fi
   if [ "${QUIET}" != "t" ]; then \
      printn "Searching for sniffer's logs, it may take a while... "; fi
   files=`${find} ${ROOTDIR}dev ${ROOTDIR}tmp ${ROOTDIR}lib ${ROOTDIR}etc ${ROOTDIR}var \
   ${findargs} \( -name "tcp.log" -o -name ".linux-sniff" -o -name "sniff-l0g" -o -name "core_" \) \
   2>/dev/null`
   if [ "${files}" = "" ]
   then
      if [ "${QUIET}" != "t" ]; then echo "nothing found"; fi
   else
      echo
      echo ${files}
   fi

   ### HiDrootkit
   if [ "${QUIET}" != "t" ]; then printn \
      "Searching for HiDrootkit's default dir... "; fi
   if [ -d ${ROOTDIR}var/lib/games/.k ]
   then
      echo "Possible HiDrootkit installed"
   else
      if [ "${QUIET}" != "t" ]; then echo "nothing found"; fi
   fi

   ### t0rn
   if [ "${QUIET}" != "t" ]; then printn\
      "Searching for t0rn's default files and dirs... "; fi
   if [ -f ${ROOTDIR}etc/ttyhash -o -f ${ROOTDIR}sbin/xlogin -o \
        -d ${ROOTDIR}usr/src/.puta  -o -r ${ROOTDIR}lib/ldlib.tk -o \
        -d ${ROOTDIR}usr/info/.t0rn ]
   then
      echo "Possible t0rn rootkit installed"
   else
      if [ "${QUIET}" != "t" ]; then echo "nothing found"; fi
   fi

   ### t0rn v8
   if [ "${QUIET}" != "t" ]; then \
      printn "Searching for t0rn's v8 defaults... "; fi
   [ -d ${ROOTDIR}lib ] && LIBS=${ROOTDIR}lib
   [ -d ${ROOTDIR}usr/lib ] && LIBS="${LIBS} ${ROOTDIR}usr/lib"
   [ -d ${ROOTDIR}usr/local/lib ] && LIBS="${LIBS} ${ROOTDIR}usr/local/lib"
   if [ "`find ${LIBS} -name libproc.a 2> /dev/null`" != "" -a \
       "$SYSTEM" != "FreeBSD" ]
   then
      echo "Possible t0rn v8 \(or variation\) rootkit installed"
   else
      if [ "${QUIET}" != "t" ]; then echo "nothing found"; fi
   fi

   ### Lion Worm
   if [ "${QUIET}" != "t" ]; then \
      printn "Searching for Lion Worm default files and dirs... "; fi
   if [ -d ${ROOTDIR}usr/info/.torn -o -d ${ROOTDIR}dev/.lib -o \
        -f ${ROOTDIR}bin/in.telnetd -o -f ${ROOTDIR}bin/mjy ]
   then
         echo "Possible Lion worm installed"
   else
      if [ "${QUIET}" != "t" ]; then echo "nothing found"; fi
   fi

   ### RSHA rootkit
   if [ "${QUIET}" != "t" ]; then \
      printn "Searching for RSHA's default files and dir... "; fi

   if [ -r "${ROOTDIR}bin/kr4p" -o -r "${ROOTDIR}usr/bin/n3tstat" \
-o -r "${ROOTDIR}usr/bin/chsh2" -o -r "${ROOTDIR}usr/bin/slice2" \
-o -r "${ROOTDIR}usr/src/linux/arch/alpha/lib/.lib/.1proc" \
-o -r "${ROOTDIR}etc/rc.d/arch/alpha/lib/.lib/.1addr" \
-o -d "${ROOTDIR}etc/rc.d/rsha" \
-o -d "${ROOTDIR}etc/rc.d/arch/alpha/lib/.lib" ]
   then
      echo "Possible RSHA's rootkit installed"
   else
      if [ "${QUIET}" != "t" ]; then echo "nothing found"; fi
   fi

   ### RH-Sharpe rootkit
   if [ "${QUIET}" != "t" ]; then \
      printn "Searching for RH-Sharpe's default files... "; fi

   if [ -r "${ROOTDIR}bin/lps" -o -r "${ROOTDIR}usr/bin/lpstree" \
-o -r "${ROOTDIR}usr/bin/ltop" -o -r "${ROOTDIR}usr/bin/lkillall" \
-o -r "${ROOTDIR}usr/bin/ldu" -o -r "${ROOTDIR}usr/bin/lnetstat" \
-o -r "${ROOTDIR}usr/bin/wp" -o -r "${ROOTDIR}usr/bin/shad" \
-o -r "${ROOTDIR}usr/bin/vadim" -o -r "${ROOTDIR}usr/bin/slice" \
-o -r "${ROOTDIR}usr/bin/cleaner" -o -r "${ROOTDIR}usr/include/rpcsvc/du" ]
   then
      echo "Possible RH-Sharpe's rootkit installed"
   else
      if [ "${QUIET}" != "t" ]; then echo "nothing found"; fi
   fi

   ### ark rootkit
   if [ "${QUIET}" != "t" ]; then printn \
      "Searching for Ambient's rootkit (ark) default files and dirs... "; fi

   if [ -d ${ROOTDIR}dev/ptyxx -o -r "${ROOTDIR}usr/lib/.ark?" -o \
        -d ${ROOTDIR}usr/doc/"... " ]; then
      echo "Possible Ambient's rootkit \(ark\) installed"
   else
      if [ "${QUIET}" != "t" ]; then echo "nothing found"; fi
   fi

   ### suspicious files and dirs
   DIR="${ROOTDIR}usr/lib"
   [ -d ${ROOTDIR}usr/man ] && DIR="$DIR ${ROOTDIR}usr/man"
   [ -d ${ROOTDIR}lib ] && DIR="$DIR ${ROOTDIR}lib"

   if [ "${QUIET}" != "t" ]; then printn \
      "Searching for suspicious files and dirs, it may take a while... "; fi

   files=`${find} ${DIR} -name ".[A-Za-z]*" -o -name "...*" -o -name ".. *"`
   dirs=`${find} ${DIR} -type d -name ".*"`
   if [ "${files}" = "" -a "${dirs}" = "" ]
      then
      if [ "${QUIET}" != "t" ]; then echo "nothing found"; fi
   else
      echo
      echo ${files}
      echo ${dirs}
   fi

   ### LPD Worm
   if [ "${QUIET}" != "t" ]; then \
      printn "Searching for LPD Worm files and dirs... "; fi

   if ${egrep} "^kork" ${ROOTDIR}etc/passwd > /dev/null 2>&1  || \
 ${egrep} "^ *666 " ${ROOTDIR}etc/inetd.conf > /dev/null 2>&1 ;
      then
         echo "Possible LPD worm installed"
      elif [ -d ${ROOTDIR}dev/.kork -o -f ${ROOTDIR}bin/.ps -o  \
-f ${ROOTDIR}bin/.login ]; then
      echo "Possible LPD worm installed"
      else
      if [ "${QUIET}" != "t" ]; then echo "nothing found"; fi
   fi

   ### Ramem Worm
   if [ "${QUIET}" != "t" ]; then \
      printn "Searching for Ramen Worm files and dirs... "; fi

   if [ -d ${ROOTDIR}usr/src/.poop -o -f \
        ${ROOTDIR}tmp/ramen.tgz -o -f ${ROOTDIR}etc/xinetd.d/asp ]
   then
      echo "Possible Ramen worm installed"
   else
      if [ "${QUIET}" != "t" ]; then echo "nothing found"; fi

   fi

   ### Maniac rootkit
   if [ "${QUIET}" != "t" ]; then \
      printn "Searching for Maniac files and dirs... "; fi

   files=`${find} ${ROOTDIR}usr/bin -name mailrc`
   if [ "${files}" = "" ]; then
      if [ "${QUIET}" != "t" ]; then echo "nothing found"; fi
   else
     echo "${files}"
   fi

   ### RK17 rookit
   if [ "${QUIET}" != "t" ]; then \
      printn "Searching for RK17 files and dirs... "; fi

   CGIDIR=""
   for cgidir in www/httpd/cgi-bin www/cgi-bin var/www/cgi-bin \
var/lib/httpd/cgi-bin usr/local/httpd/cgi-bin usr/local/apache/cgi-bin \
home/httpd/cgi-bin usr/local/apache2  usr/local/www usr/lib;
   do
        [ -d ${ROOTDIR}${cgidir} ] && CGIDIR="$CGIDIR ${ROOTDIR}${cgidir}"
   done
   files=`${find} ${ROOTDIR}bin -name rtty -o -name squit && \
${find} ${ROOTDIR}sbin -name pback && \
${find} ${ROOTDIR}usr/man/man3 -name psid 2>/dev/null && \
${find} ${ROOTDIR}proc -name kset 2> /dev/null && \
${find} ${ROOTDIR}usr/src/linux/modules -name autod.o -o -name soundx.o \
2> /dev/null && \
${find} ${ROOTDIR}usr/bin -name gib -o -name ct -o -name snick -o -name kfl  2> /dev/null`
BACKDOORS="number.cgi void.cgi psid becys.cgi nobody.cgi bash.zk.cgi alya.cgi \
shell.cgi alin.cgi httpd.cgi linux.cgi sh.cgi take.cgi bogus.cgi alia.cgi all4one.cgi \
zxcvbnm.cgi secure.cgi ubb.cgi r57shell.php"
   files=""
   for j in ${CGIDIR}; do
      for i in ${BACKDOORS}; do
  [ -f ${j}/${i} ] && files="${files} ${j}/${i}"
      done
   done
   if [ "${files}" = ""  ]; then
     if [ "${QUIET}" != "t" ]; then echo "nothing found"; fi
   else
     echo "${files}"
   fi

   ### Ducoci rootkit
   if [ "${QUIET}" != "t" ]; then \
      printn "Searching for Ducoci rootkit... "; fi

   files=`${find} ${CGIDIR} -name last.cgi`
   if [ "${files}" = ""  ]; then
      if [ "${QUIET}" != "t" ]; then echo "nothing found"; fi
   else
     echo "${files}"
   fi

   ### Adore Worm
   if [ "${QUIET}" != "t" ]; then printn "Searching for Adore Worm... "; fi

   files=`${find} ${ROOTDIR}usr/lib ${ROOTDIR}usr/bin -name red.tar -o \
-name start.sh -o -name klogd.o -o -name 0anacron-bak -o -name adore`
   if [ "${files}" = "" ]; then
      if [ "${QUIET}" != "t" ]; then echo "nothing found"; fi
   else
     echo "${files}"
     files=`${find} ${ROOTDIR}usr/lib/lib ${ROOTDIR}usr/lib/libt 2>/dev/null`
     [ "${files}" != "" ] && echo ${files}
   fi

   ### ShitC Worm
   if [ "${QUIET}" != "t" ]; then printn "Searching for ShitC Worm... "; fi

   files=`${find} ${ROOTDIR}bin -name homo -o -name frgy -o -name dy || \
${find} ${ROOTDIR}usr/bin -type d -name dir || \
${find} ${ROOTDIR}usr/sbin -name in.slogind`
   if [ "${files}" = "" ]; then
      if [ "${QUIET}" != "t" ]; then echo "nothing found"; fi
   else
     echo "${files}"
   fi

   ### Omega Worm
   if [ "${QUIET}" != "t" ]; then printn "Searching for Omega Worm... "; fi

   files=`${find} ${ROOTDIR}dev -name chr`
   if [ "${files}" = "" ]; then
      if [ "${QUIET}" != "t" ]; then echo "nothing found"; fi
   else
     echo "${files}"
   fi

   ### China Worm (Sadmind/IIS Worm)
   if [ "${QUIET}" != "t" ];then printn "Searching for Sadmind/IIS Worm... "; fi
   files=`${find} ${ROOTDIR}dev/cuc 2> /dev/null`
   if [ "${files}" = "" ]; then
      if [ "${QUIET}" != "t" ]; then echo "nothing found"; fi
   else
     echo "${files}"
   fi

   ### MonKit
   if [ "${QUIET}" != "t" ];then printn "Searching for MonKit... "; fi
   files=`${find} ${ROOTDIR}lib/defs ${ROOTDIR}usr/lib/libpikapp.a \
2> /dev/null`
   if [ "${files}" = "" ]; then
      if [ "${QUIET}" != "t" ]; then echo "nothing found"; fi
   else
     echo "${files}"
   fi

   ### Showtee
   if [ "${QUIET}" != "t" ];then printn "Searching for Showtee... "; fi
   if [ -d ${ROOTDIR}usr/lib/.egcs ] || \
      [ -d ${ROOTDIR}usr/lib/.kinetic ] || [ -d ${ROOTDIR}usr/lib/.wormie ] || \
      [ -f ${ROOTDIR}usr/lib/liblog.o ] || [ -f ${ROOTDIR}usr/include/addr.h ] || \
      [ -f ${ROOTDIR}usr/include/cron.h ] || [ -f ${ROOTDIR}usr/include/file.h ] || \
      [ -f ${ROOTDIR}usr/include/proc.h ] || [ -f ${ROOTDIR}usr/include/syslogs.h ] || \
      [ -f ${ROOTDIR}usr/include/chk.h ]; then
         echo "Warning: Possible Showtee Rootkit installed"
      else
      if  [ "${QUIET}" != "t" ]; then echo "nothing found"; fi
   fi

   ###
   ### OpticKit
   ###
   if [ "${QUIET}" != "t" ];then printn "Searching for OpticKit... "; fi
   files=`${find} ${ROOTDIR}usr/bin/xchk ${ROOTDIR}usr/bin/xsf \
2> /dev/null`
   if [ "${files}" = "" ]; then
      if [ "${QUIET}" != "t" ]; then echo "nothing found"; fi
   else
     echo "${files}"
   fi

   ### T.R.K
   files=""
   if [ "${QUIET}" != "t" ];then printn "Searching for T.R.K... "; fi
   files=`${find} ${ROOTDIR}usr/bin -name xchk -o -name xsf >/dev/null 2>&1`
   if [ "${files}" = "" ]; then
      if [ "${QUIET}" != "t" ]; then echo "nothing found"; fi
   else
     echo "${files}"
   fi

   ### Mithra's Rootkit
   files=""
   if [ "${QUIET}" != "t" ];then printn "Searching for Mithra... "; fi
   files=`${find} ${ROOTDIR}usr/lib/locale -name uboot 2> /dev/null`
   if [ "${files}" = "" ]; then
      if [ "${QUIET}" != "t" ]; then echo "nothing found"; fi
   else
     echo "${files}"
   fi

   ### OpenBSD rootkit v1
   if [ \( "${SYSTEM}" != "SunOS" -a ${SYSTEM} != "Linux" \) -a ! -f ${ROOTDIR}usr/lib/security/libgcj.security ]; then
      files=""
      if [ "${QUIET}" != "t" ];then printn "Searching for OBSD rk v1... "; fi
      files=`${find} ${ROOTDIR}usr/lib/security 2>/dev/null`
      if [ "${files}" = "" -o "${SYSTEM}" = "HP-UX" ]; then
         if [ "${QUIET}" != "t" ]; then echo "nothing found"; fi
      else
        echo "${files}"
      fi
   fi

   ### LOC rootkit
   files=""
   if [ "${QUIET}" != "t" ];then printn "Searching for LOC rootkit... "; fi
   files=`find ${ROOTDIR}tmp -name xp -o -name kidd0.c 2>/dev/null`
   if [ "${files}" = "" ]; then
      if [ "${QUIET}" != "t" ]; then echo "nothing found"; fi
   else
     echo "${files}"
     loc epic epic $pth
   fi

   ### Romanian rootkit
   files=""
   if [ "${QUIET}" != "t" ];then printn "Searching for Romanian rootkit... "; fi
   for i in file.h proc.h addr.h syslogs.h; do
      if [ -f ${ROOTDIR}usr/include/${i} ]; then
         files="$files ${ROOTDIR}usr/include/$i"
      fi
   done
   if [ "${files}" = "" ]; then
      if [ "${QUIET}" != "t" ]; then echo "nothing found"; fi
   else
      echo "${files}"
   fi

   ### HKRK
   if [ -f ${ROOTDIR}etc/rc.d/init.d/network ]; then
      if [ "${QUIET}" != "t" ];then printn "Searching for HKRK rootkit... "; fi
      if ${egrep} "\.hk" ${ROOTDIR}etc/rc.d/init.d/network 2>/dev/null ; then
        echo "Warning: /etc/rc.d/init.d/network INFECTED"
      else
         if [ "${QUIET}" != "t" ]; then echo "nothing found"; fi
      fi
   fi

   ### Suckit
   if [ -f ${ROOTDIR}sbin/init ]; then
      if [ "${QUIET}" != "t" ];then printn "Searching for Suckit rootkit... "; fi
      if [ ${SYSTEM} != "HP-UX" ] && ( ${strings} ${ROOTDIR}sbin/init | ${egrep} 'HOME='   || \
        cat ${ROOTDIR}/proc/1/maps | ${egrep} "init." ) >/dev/null 2>&1
        then
        echo "Warning: ${ROOTDIR}sbin/init INFECTED"
      else
         if [ -d ${ROOTDIR}/dev/.golf ]; then
            echo "Warning: Suspect directory ${ROOTDIR}dev/.golf"
   else
            if [ "${QUIET}" != "t" ]; then echo "nothing found"; fi
   fi
      fi
   fi

   ### Volc
   if [ "${QUIET}" != "t" ];then printn "Searching for Volc rootkit... "; fi
   if [ -f ${ROOTDIR}usr/bin/volc -o -f ${ROOTDIR}usr/lib/volc ] ; then
      echo "Warning: Possible Volc rootkit installed"
   else
      if [ "${QUIET}" != "t" ]; then echo "nothing found"; fi
   fi

   ### Gold2
   if [ "${QUIET}" != "t" ];then printn "Searching for Gold2 rootkit... "; fi
   if [ -f ${ROOTDIR}usr/bin/ishit ] ; then
      echo "Warning: Possible Gold2 rootkit installed"
   else
      if [ "${QUIET}" != "t" ]; then echo "nothing found"; fi
   fi

   ### TC2 Worm
   if [ "${QUIET}" != "t" ]; then \
      printn "Searching for TC2 Worm default files and dirs... "; fi
   if [ -d ${ROOTDIR}usr/info/.tc2k -o -d ${ROOTDIR}usr/bin/util -o \
        -f ${ROOTDIR}usr/sbin/initcheck  -o -f ${ROOTDIR}usr/sbin/ldb ]
   then
         echo "Possible TC2 Worm installed"
   else
      if [ "${QUIET}" != "t" ]; then echo "nothing found"; fi
   fi

   ### ANONOYING Rootkit
   if [ "${QUIET}" != "t" ]; then \
      printn "Searching for Anonoying rootkit default files and dirs... "; fi
   if [ -f ${ROOTDIR}usr/sbin/mech -o -f ${ROOTDIR}usr/sbin/kswapd ]; then
         echo "Possible anonoying rootkit installed"
   else
      if [ "${QUIET}" != "t" ]; then echo "nothing found"; fi
   fi

   ### ZK Rootkit
   if [ "${QUIET}" != "t" ]; then \
      printn "Searching for ZK rootkit default files and dirs... "; fi
   if [ -f ${ROOTDIR}etc/sysconfig/console/load.zk ]; then
         echo "Possible ZK rootkit installed"
   else
      if [ "${QUIET}" != "t" ]; then echo "nothing found"; fi
   fi
   ### ShKit
   if [ "${QUIET}" != "t" ]; then
      printn "Searching for ShKit rootkit default files and dirs... "; fi
   if [ -f ${ROOTDIR}lib/security/.config -o -f ${ROOTDIR}etc/ld.so.hash ]; then
         echo "Possible ShKit rootkit installed"
   else
      if [ "${QUIET}" != "t" ]; then echo "nothing found"; fi
   fi

   ### AjaKit
   if [ "${QUIET}" != "t" ]; then
      printn "Searching for AjaKit rootkit default files and dirs... "; fi
      if [ -d ${ROOTDIR}lib/.ligh.gh -o -d ${ROOTDIR}dev/tux ]; then
         echo "Possible AjaKit rootkit installed"
   else
      if [ "${QUIET}" != "t" ]; then echo "nothing found"; fi
   fi

   ### zaRwT
   if [ "${QUIET}" != "t" ]; then
      printn "Searching for zaRwT rootkit default files and dirs... "; fi
      if [ -f ${ROOTDIR}bin/imin -o -f ${ROOTDIR}bin/imout ]; then
         echo "Possible zaRwT rootkit installed"
   else
      if [ "${QUIET}" != "t" ]; then echo "nothing found"; fi
   fi

   ### Madalin rootkit
   if [ "${QUIET}" != "t" ]; then
      printn "Searching for Madalin rootkit default files... "; fi
   D=${ROOTDIR}usr/include
   if [ -f $D/icekey.h -o -f $D/iceconf.h -o -f $D/iceseed.h ]; then
       echo "Possible Madalin rootkit installed"
   else
      if [ "${QUIET}" != "t" ]; then echo "nothing found"; fi
   fi

   ### Fu rootkit
   if [ "${QUIET}" != "t" ]; then
      printn "Searching for Fu rootkit default files... "; fi
   if [ -f ${ROOTDIR}sbin/xc -o -f ${ROOTDIR}bin/.lib -o \
        -f ${ROOTDIR}usr/include/ivtype.h ]; then
      echo "Possible Fu rootkit installed"
   else
      if [ "${QUIET}" != "t" ]; then echo "nothing found"; fi
   fi

   ### ESRK
   if [ "${QUIET}" != "t" ]; then
      printn "Searching for ESRK rootkit default files... "; fi
   if [ -d "${ROOTDIR}usr/lib/tcl5.3" ]; then
      echo "Possible ESRK rootkit installed"
   else
      if [ "${QUIET}" != "t" ]; then echo "nothing found"; fi
   fi

   ## rootedoor
   if [ "${QUIET}" != "t" ]; then
      printn "Searching for rootedoor... "; fi
   found=0
   for i in `$echo $PATH|tr -s ':' ' '`; do
      if [ -f "${ROOTDIR}${i}/rootedoor" ]; then
         echo "Possible rootedoor installed in ${ROOTDIR}${i}"
   found=1
      fi
   done
   [ "${found}" = "0"  ] &&\
   if [ "${QUIET}" != "t" ]; then echo "nothing found"; fi

   ### ENYELKM
   if [ "${QUIET}" != "t" ]; then
      printn "Searching for ENYELKM rootkit default files... "; fi
   if [ -d "${ROOTDIR}etc/.enyelkmOCULTAR.ko" ]; then
      echo "Possible ENYELKM rootkit installed"
   else
      if [ "${QUIET}" != "t" ]; then echo "nothing found"; fi
   fi

   ## Common SSH-SCANNERS
   if [ "${QUIET}" != "t" ]; then
      printn "Searching for common ssh-scanners default files... "; fi
   files="`${find} ${ROOTDIR}tmp ${ROOTDIR}var/tmp ${findargs} -name vuln.txt -o -name ssh-scan -o -name pscan2 2> /dev/null`"
   if [ "${files}" = "" ]; then
      if [ "${QUIET}" != "t" ]; then echo "nothing found"; fi
   else
     echo "${files}"
   fi

   ## SSJD Operation Windigo  (Linux/Ebury) 
   if [ "${QUIET}" != "t" ]; then
      printn "Searching for Linux/Ebury - Operation Windigo ssh... "; fi
   if $ssh -G 2>&1 | grep -e illegal -e unknow > /dev/null; then 
      if [ "${QUIET}" != "t" ]; then echo "nothing found"; fi
   else
         echo "Possible Linux/Ebury - Operation Windigo installetd" 
   fi  

   ## Linux Rootkit 64 bits 
   if [ "${QUIET}" != "t" ]; then
      printn "Searching for 64-bit Linux Rootkit ... "; fi
   if ${egrep} module_init ${ROOTDIR}etc/rc.local >/dev/null 2>&1 || \
      ${ls} ${ROOTDIR}/usr/local/hide >/dev/null 2>&1; then
      echo "Possible 64-bit Linux Rootkit"
   else
      if [ "${QUIET}" != "t" ]; then echo "nothing found"; fi
   fi
   
   if [ "${QUIET}" != "t" ]; then
      printn "Searching for 64-bit Linux Rootkit modules... "; fi
   files="`${find} ${ROOTDIR}/lib/modules ${findargs} -name module_init.ko 2 2> /dev/null`"
   if [ "${files}" = "" ]; then
      if [ "${QUIET}" != "t" ]; then echo "nothing found"; fi
   else
     echo "${files}"
   fi    



   ###
   ### Suspect PHP files
   ###
   if [ "${QUIET}" != "t" ]; then
      printn "Searching for suspect PHP files... "; fi
      files="`${find} ${ROOTDIR}tmp ${ROOTDIR}var/tmp ${findargs} -name '*.php' 2> /dev/null`"
if [ `echo abc | head -n 1` = "abc" ]; then
      fileshead="`${find} ${ROOTDIR}tmp ${ROOTDIR}var/tmp ${findargs} -type f -exec head -n 1 {} \; | $egrep '#!.*php' 2> /dev/null`"
else
      fileshead="`${find} ${ROOTDIR}tmp ${ROOTDIR}var/tmp ${findargs} -type f -exec head -1 {} \; | grep '#!.*php' 2> /dev/null`"
fi
   if [ "${files}" = "" -a "${fileshead}" = "" ]; then
      if [ "${QUIET}" != "t" ]; then echo "nothing found"; fi
   else
     echo
     echo "${files}"
     echo "${fileshead}"
   fi

   ###
   ### shell history anomalies
   ###
   if [ "${QUIET}" != "t" ]; then \
      printn "Searching for anomalies in shell history files... "; fi
   files=""
   if [ ! -z "${SHELL}" -a ! -z "${HOME}" ]; then
      files=`${find} ${ROOTDIR}${HOME} ${findargs} -name '.*history' -size 0`
      [ ! -z "${files}" ] && \
        echo "Warning: \`${files}' file size is zero"
      files1=`${find} ${ROOTDIR}${HOME} ${findargs} -name '.*history' \( -links 2 -o -type l \)`
      [ ! -z "${files1}" ] && \
        echo "Warning: \`${files1}' is linked to another file"
   fi
   if [ -z "${files}" -a -z "${files1}" ]; then
      if [ "${QUIET}" != "t" ]; then echo "nothing found"; fi
   fi
}

######################################################################
# util functions

# our which(1)
loc () {
    ### usage: loc filename filename_to_return_if_nothing_was_found path
    thing=$1
    shift
    dflt=$1
    shift
    for dir in $*; do
            case "$thing" in
            .)
            if test -d $dir/$thing; then
                    echo $dir
                    exit 0
            fi
            ;;
            *)
            for thisthing in $dir/$thing; do
                    :
            done
            if test -f $thisthing; then
                    echo $thisthing
                    exit 0
            fi
            ;;
            esac
    done
    if [ "${ROOTDIR}" = "/" ]; then
      echo ${dflt}
    else
      echo "${ROOTDIR}${dflt}"
    fi
    exit 1
}

getCMD() {

   RUNNING=`${ps} ${ps_cmd} | ${egrep} "${L_REGEXP}${1}${R_REGEXP}" | \
            ${egrep} -v grep | ${egrep} -v chkrootkit | _head -1 | \
            ${awk} '{ print $5 }'`

   for i in ${ROOTDIR}${RUNNING} ${ROOTDIR}usr/sbin/${1} `loc ${1} ${1} $pth`
   do
      CMD="${i}"
      if [ -r "${i}" ]
        then
        return 0
      fi
   done
   return 1
}

expertmode_output() {
    echo "###"
    echo "### Output of: $1"
    echo "###"
    eval $1 2>&1
#    cat <<EOF
#`$1 2>&1`
#EOF
    return 0
}

tnfs ()
{
   ## Check if -fstype nfs works
   findargs=""
   if find /etc -maxdepth 0 >/dev/null 2>&1; then
        find /etc ! -fstype nfs -maxdepth 0 >/dev/null 2>&1 && \
           findargs="! -fstype nfs "
   elif find /etc -prune > /dev/null 2>&1; then
        find /etc ! -fstype nfs -prune > /dev/null 2>&1 && \
           findargs="! -fstype nfs "
   fi
}

######################################################################
# trojan functions

chk_chfn () {
    STATUS=${NOT_INFECTED}
    CMD=`loc chfn chfn $pth`
    [ ${?} -ne 0 ] &&  return ${NOT_FOUND}

    if [ "${EXPERT}" = "t" ]; then
        expertmode_output "${strings} -a ${CMD}"
        return 5
    fi

    case "${SYSTEM}" in
       Linux)
          if ${strings} -a ${CMD} | ${egrep} "${GENERIC_ROOTKIT_LABEL}" \
             >/dev/null 2>&1
          then
             STATUS=${INFECTED}
          fi;;
       FreeBSD)
          [ `echo $V | ${awk} '{ if ( $1 >= 5.0) print 1; else print 0 }'` -eq 1 ] && n=1 || n=2
          if [ `${strings} -a ${CMD} | \
                ${egrep} -c "${GENERIC_ROOTKIT_LABEL}"` -ne $n ]
          then
             STATUS=${INFECTED}
          fi;;
    esac
    return ${STATUS}
}

chk_chsh () {
    STATUS=${NOT_INFECTED}
    CMD=`loc chsh chsh $pth`
    [ ${?} -ne 0 ] && return ${NOT_FOUND}

    REDHAT_PAM_LABEL="*NOT*"

    if [ "${EXPERT}" = "t" ]; then
        expertmode_output "${strings} -a ${CMD}"
        return 5
    fi

    case "${SYSTEM}" in
       Linux)
          if ${strings} -a ${CMD} | ${egrep} "${GENERIC_ROOTKIT_LABEL}" \
          >/dev/null 2>&1
             then
             if ${strings} -a ${CMD} | ${egrep} "${REDHAT_PAM_LABEL}" \
             >/dev/null 2>&1
                then
                :
             else
                STATUS=${INFECTED}
             fi
          fi;;
       FreeBSD)
          [ `echo $V | ${awk} '{ if ($1 >= 5.0) print 1; else print 0}'` -eq 1 ] && n=1 || n=2
          if [ `${strings} -a ${CMD} | ${egrep} -c "${GENERIC_ROOTKIT_LABEL}"` -ne $n ]
             then
             STATUS=${INFECTED}
          fi;;
    esac
    return ${STATUS}
}

chk_login () {
    STATUS=${NOT_INFECTED}
    CMD=`loc login login $pth`

    if [ "${EXPERT}" = "t" ]; then
        expertmode_output "${strings} -a ${CMD}"
        return 5
    fi

    if [ "$SYSTEM" = "SunOS" ]; then
      TROJED_L_L="porcao|/bin/xstat"
      if ${strings} -a ${CMD} | ${egrep} "${TROJED_L_L}" >/dev/null 2>&1 ]; then
          return ${INFECTED}
       else
          return ${NOT_TESTED}
       fi
    fi
    GENERAL="^root$"
    TROJED_L_L="vejeta|^xlogin|^@\(#\)klogin\.c|lets_log|sukasuka|/usr/lib/.ark?|SucKIT|cocola"
    ret=`${strings} -a ${CMD} | ${egrep} -c "${GENERAL}"`
    if [ ${ret} -gt 0 ]; then
        case ${ret} in
        1) [ "${SYSTEM}" = "OpenBSD" -a `echo $V | ${awk} '{ if ($1 < 2.7 ||
$1 >= 3.0) print 1; else print 0}'` -eq 1 ] && \
             STATUS=${NOT_INFECTED} || STATUS=${INFECTED};;
        2) [ "${SYSTEM}" = "FreeBSD"  -o ${SYSTEM} = "NetBSD" -o ${SYSTEM} = \
"OpenBSD" -a `echo ${V} | ${awk} '{ if ($1 >= 2.8) print 1; else print 0 }'` -eq 1 ] && STATUS=${NOT_INFECTED} || STATUS=${INFECTED};;
        6|7) [ "${SYSTEM}" = "HP-UX" ] && STATUS=${NOT_INFECTED} || STATUS=${INFECTED};;
        *) STATUS=${INFECTED};;
        esac
    fi
    if ${strings} -a ${CMD} | ${egrep} "${TROJED_L_L}" 2>&1 >/dev/null
       then
        STATUS=${INFECTED}
    fi
    return ${STATUS}
}

chk_passwd () {
    STATUS=${NOT_INFECTED}
    CMD=`loc passwd passwd $pth`

    if [ ! -x ${CMD} -a -x ${ROOTDIR}usr/bin/passwd ]; then
       CMD="${ROOTDIR}usr/bin/passwd"
    fi

    if [ "${EXPERT}" = "t" ]; then
       expertmode_output "${strings} -a ${CMD}"
    fi

    if [ "${SYSTEM}" = "OpenBSD" -o "${SYSTEM}" = "SunOS" -o "${SYSTEM}" \
        = "HP-UX" ]
    then
       return ${NOT_TESTED}
    fi
    if ${strings} -a ${CMD} | ${egrep} "${GENERIC_ROOTKIT_LABEL}|/lib/security" \
    >/dev/null 2>&1
    then
       STATUS=${INFECTED}
    fi
    return ${STATUS}
}

chk_inetd () {
    STATUS=${NOT_INFECTED}
    getCMD 'inetd'

    if [ ! -r ${CMD} -o ${CMD} = '/' ]
    then
       return ${NOT_TESTED}
    fi

    if [ "${EXPERT}" = "t" ]; then
        expertmode_output "${strings} -a ${CMD}"
        return 5
    fi

    if ${strings} -a ${CMD} | ${egrep} "${GENERIC_ROOTKIT_LABEL}" \
    >/dev/null 2>&1
    then
       STATUS=${INFECTED}
    fi
    return ${STATUS}
}

chk_syslogd () {
    STATUS=${NOT_INFECTED}
SYSLOG_I_L="/usr/lib/pt07|/dev/pty[pqrs]|/dev/hd[als][0-7]|/dev/ddtz1|/dev/ptyxx|/dev/tux|syslogs\.h"
    CMD=`loc syslogd syslogd $pth`

    if [ ! -r ${CMD} ]
    then
       return ${NOT_TESTED}
    fi

    if [ "${EXPERT}" = "t" ]; then
        expertmode_output "${strings} -a ${CMD}"
        return 5
    fi

    if ${strings} -a ${CMD} | ${egrep} "${SYSLOG_I_L}" >/dev/null 2>&1
    then
       STATUS=${INFECTED}
    fi
    return ${STATUS}
}

chk_hdparm () {
    STATUS=${NOT_INFECTED}
    HDPARM_INFECTED_LABEL="/dev/ida"
    CMD=`loc hdparm hdparm $pth`
    if [ ! -r ${CMD} ]
    then
       return ${NOT_FOUND}
    fi

    if [ "${EXPERT}" = "t" ]; then
        expertmode_output "${strings} -a ${CMD}"
        return 5
    fi

    if ${strings} -a ${CMD} | ${egrep} "${HDPARM_INFECTED_LABEL}" \
       >/dev/null 2>&1
    then
       STATUS=${INFECTED}
    fi
    return ${STATUS}
}

chk_gpm () {
    STATUS=${NOT_INFECTED}
    GPM_INFECTED_LABEL="mingetty"
    CMD=`loc gpm gpm $pth`
    if [ ! -r ${CMD} ]
    then
       return ${NOT_FOUND}
    fi

    if [ "${EXPERT}" = "t" ]; then
        expertmode_output "${strings} -a ${CMD}"
        return 5
    fi

    if ${strings} -a ${CMD} | ${egrep} "${GPM_INFECTED_LABEL}" \
       >/dev/null 2>&1
    then
       STATUS=${INFECTED}
    fi
    return ${STATUS}
}

chk_mingetty () {
    STATUS=${NOT_INFECTED}
    MINGETTY_INFECTED_LABEL="Dimensioni|pacchetto"
    CMD=`loc mingetty mingetty $pth`
    if [ ! -r ${CMD} ]
    then
       return ${NOT_FOUND}
    fi

    if [ "${EXPERT}" = "t" ]; then
        expertmode_output "${strings} -a ${CMD}"
        return 5
    fi

    if ${strings} -a ${CMD} | ${egrep} "${MINGETTY_INFECTED_LABEL}" \
       >/dev/null 2>&1
    then
       STATUS=${INFECTED}
    fi
    return ${STATUS}
}

chk_sendmail () {
    STATUS=${NOT_INFECTED}
    SENDMAIL_INFECTED_LABEL="fuck"
    CMD=`loc sendmail sendmail $pth`
    if [ ! -r ${CMD} ]
    then
       return ${NOT_FOUND}
    fi

    if [ "${EXPERT}" = "t" ]; then
        expertmode_output "${strings} -a ${CMD}"
        return 5
    fi

    if ${strings} -a ${CMD} | ${egrep} "${SENDMAIL_INFECTED_LABEL}" \
       >/dev/null 2>&1
    then
       STATUS=${INFECTED}
    fi
    return ${STATUS}
}

chk_ls () {
    STATUS=${NOT_INFECTED}
LS_INFECTED_LABEL="/dev/ttyof|/dev/pty[pqrs]|/dev/hdl0|\.tmp/lsfile|/dev/hdcc|/dev/ptyxx|duarawkz|^/prof|/dev/tux|/security|file\.h"
    CMD=`loc ls ls $pth`

    if [ "${EXPERT}" = "t" ]; then
        expertmode_output "${strings} -a ${CMD}"
        return 5
    fi

    if ${strings} -a ${CMD} | ${egrep} "${LS_INFECTED_LABEL}" >/dev/null 2>&1
    then
       STATUS=${INFECTED}
    fi
    return ${STATUS}
}

chk_du () {
    STATUS=${NOT_INFECTED}
    DU_INFECTED_LABEL="/dev/ttyof|/dev/pty[pqrsx]|w0rm|^/prof|/dev/tux|file\.h"
    CMD=`loc du du $pth`

    if [ "${EXPERT}" = "t" ]; then
        expertmode_output "${strings} -a ${CMD}"
        return 5
    fi

    if ${strings} -a ${CMD} | ${egrep} "${DU_INFECTED_LABEL}" >/dev/null 2>&1
    then
       STATUS=${INFECTED}
    fi
    return ${STATUS}
}

chk_named () {
    STATUS=${NOT_INFECTED}
    NAMED_I_L="blah|bye"
    CMD=`loc named named $pth`

    if [ ! -r "${CMD}" ]; then
       CMD=`loc in.named in.named $pth`
       if [ ! -r "${CMD}" ]; then
          return ${NOT_FOUND}
       fi
    fi

    if [ "${EXPERT}" = "t" ]; then
        expertmode_output "${strings} -a ${CMD}"
        return 5
    fi

    if ${strings} -a ${CMD} | ${egrep} "${NAMED_I_L}" \
    >/dev/null 2>&1
    then
       STATUS=${INFECTED}
    fi
    return ${STATUS}
}

chk_netstat () {
    STATUS=${NOT_INFECTED}
NETSTAT_I_L="/dev/hdl0/dev/xdta|/dev/ttyoa|/dev/pty[pqrsx]|/dev/cui|/dev/hdn0|/dev/cui221|/dev/dszy|/dev/ddth3|/dev/caca|^/prof|/dev/tux|grep|addr\.h|__bzero"
    CMD=`loc netstat netstat $pth`

    if [ "${EXPERT}" = "t" ]; then
        expertmode_output "${strings} -a ${CMD}"
        return 5
    fi

    if ${strings} -a ${CMD} | ${egrep} "${NETSTAT_I_L}" \
    >/dev/null 2>&1
    then
       STATUS=${INFECTED}
    fi
    return ${STATUS}
}

chk_ps () {
   STATUS=${NOT_INFECTED}
PS_I_L="/dev/xmx|\.1proc|/dev/ttyop|/dev/pty[pqrsx]|/dev/cui|/dev/hda[0-7]|\
/dev/hdp|/dev/cui220|/dev/dsx|w0rm|/dev/hdaa|duarawkz|/dev/tux|/security|^proc\.h|ARRRGH\.so"
   CMD=`loc ps ps $pth`

    if [ "${EXPERT}" = "t" ]; then
        expertmode_output "${strings} -a ${CMD}"
        return 5
    fi

    if ${strings} -a ${CMD} | ${egrep} "${PS_I_L}" >/dev/null 2>&1
    then
       STATUS=${INFECTED}
    fi
    return ${STATUS}
}

chk_pstree () {
    STATUS=${NOT_INFECTED}
    PSTREE_INFECTED_LABEL="/dev/ttyof|/dev/hda01|/dev/cui220|/dev/ptyxx|^/prof|/dev/tux|proc\.h"

    CMD=`loc pstree pstree $pth`
    if [ ! -r "${CMD}" ]
    then
       return ${NOT_FOUND}
    fi

    if [ "${EXPERT}" = "t" ]; then
        expertmode_output "${strings} -a ${CMD}"
        return 5
    fi

    if ${strings} -a ${CMD} | ${egrep} "${PSTREE_INFECTED_LABEL}" >/dev/null 2>&1
    then
       STATUS=${INFECTED}
    fi
    return ${STATUS}
}

chk_crontab () {
    STATUS=${NOT_INFECTED}
    CRONTAB_I_L="crontab.*666"

    CMD=`loc crontab crontab $pth`

    if [ ! -r ${CMD} ]
       then
        return ${NOT_FOUND}
    fi

    if [ "${EXPERT}" = "t" ]; then
        expertmode_output "${CMD} -l -u nobody"
        return 5
    fi
    # slackware's crontab have a bug
    if  ( ${CMD} -l -u nobody | $egrep [0-9] ) >/dev/null 2>&1 ; then
        ${echo} "Warning: crontab for nobody found, possible Lupper.Worm... "
  if ${CMD} -l -u nobody 2>/dev/null  | ${egrep} $CRONTAB_I_L >/dev/null 2>&1
     then
           STATUS=${INFECTED}
  fi
    fi
    return ${STATUS}
}

chk_top () {
    STATUS=${NOT_INFECTED}
    TOP_INFECTED_LABEL="/dev/xmx|/dev/ttyop|/dev/pty[pqrsx]|/dev/hdp|/dev/dsx|^/prof/|/dev/tux|^/proc\.h|proc_hackinit"

    CMD=`loc top top $pth`

    if [ ! -r ${CMD} ]
       then
        return ${NOT_FOUND}
    fi

    if [ "${EXPERT}" = "t" ]; then
        expertmode_output "${strings} -a ${CMD}"
        return 5
    fi

    if ${strings} -a ${CMD} | ${egrep} "${TOP_INFECTED_LABEL}" >/dev/null 2>&1
    then
       STATUS=${INFECTED}
    fi
    return ${STATUS}
}

chk_pidof () {
    STATUS=${NOT_INFECTED}
    TOP_INFECTED_LABEL="/dev/pty[pqrs]"
    CMD=`loc pidof pidof $pth`

    if [ "${?}" -ne 0 ]
    then
        return ${NOT_FOUND}
    fi

    if [ "${EXPERT}" = "t" ]; then
        expertmode_output "${strings} -a ${CMD}"
        return 5
    fi

    if ${strings} -a ${CMD} | ${egrep} "${TOP_INFECTED_LABEL}" >/dev/null 2>&1
    then
       STATUS=${INFECTED}
    fi
    return ${STATUS}
}

chk_killall () {
    STATUS=${NOT_INFECTED}
    TOP_INFECTED_LABEL="/dev/ttyop|/dev/pty[pqrs]|/dev/hda[0-7]|/dev/hdp|/dev/ptyxx|/dev/tux|proc\.h"
    CMD=`loc killall killall $pth`

    if [ "${?}" -ne 0 ]
       then
        return ${NOT_FOUND}
    fi

    if [ "${EXPERT}" = "t" ]; then
        expertmode_output "${strings} -a ${CMD}"
        return 5
    fi

    if ${strings} -a ${CMD} | ${egrep} "${TOP_INFECTED_LABEL}" >/dev/null 2>&1
    then
       STATUS=${INFECTED}
    fi
    return ${STATUS}
}

chk_ldsopreload() {
   STATUS=${NOT_INFECTED}
   CMD="${ROOTDIR}lib/libshow.so ${ROOTDIR}lib/libproc.a"

   if [ "${SYSTEM}" = "Linux" ]
   then
      if [ ! -x ./strings-static ]; then
        printn "can't exec ./strings-static, "
        return ${NOT_TESTED}
      fi

      if [ "${EXPERT}" = "t" ]; then
          expertmode_output "./strings-static -a ${CMD}"
          return 5
      fi

      ### strings must be a statically linked binary.
      if ./strings-static -a ${CMD} > /dev/null 2>&1
      then
         STATUS=${INFECTED}
      fi
   else
     STATUS=${NOT_TESTED}
   fi
   return ${STATUS}
}

chk_basename () {
   STATUS=${NOT_INFECTED}
   CMD=`loc basename basename $pth`

   if [ "${EXPERT}" = "t" ]; then
       expertmode_output "${strings} -a ${CMD}"
       expertmode_output "${ls} -l ${CMD}"
       return 5
   fi
   if ${strings} -a ${CMD} | ${egrep} "${GENERIC_ROOTKIT_LABEL}" > /dev/null 2>&1
   then
       STATUS=${INFECTED}
   fi

   [ "$SYSTEM" != "OSF1" ] &&
   {
      if ${ls} -l ${CMD} | ${egrep} "^...s" > /dev/null 2>&1
      then
         STATUS=${INFECTED}
      fi
   }
   return ${STATUS}
}

chk_dirname () {
    STATUS=${NOT_INFECTED}
    CMD=`loc dirname dirname $pth`

    if [ "${EXPERT}" = "t" ]; then
        expertmode_output "${strings} -a ${CMD}"
        expertmode_output "${ls} -l ${CMD}"
        return 5
    fi
    if ${strings} -a ${CMD} | ${egrep} "${GENERIC_ROOTKIT_LABEL}" > /dev/null 2>&1
    then
        STATUS=${INFECTED}
    fi
    if ${ls} -l ${MD} | ${egrep} "^...s" > /dev/null 2>&1
    then
        STATUS=${INFECTED}
    fi
    return ${STATUS}
}

chk_traceroute () {
    STATUS=${NOT_INFECTED}
    CMD=`loc traceroute traceroute $pth`

    if [ ! -r "${CMD}" ]
    then
       return ${NOT_FOUND}
    fi

    if [ "${EXPERT}" = "t" ]; then
        expertmode_output "${strings} -a ${CMD}"
        return 5
    fi

    if ${strings} -a ${CMD} | ${egrep} "${GENERIC_ROOTKIT_LABEL}" > /dev/null 2>&1
    then
        STATUS=${INFECTED}
    fi
    return ${STATUS}
}

chk_rpcinfo () {
    STATUS=${NOT_INFECTED}
    CMD=`loc rpcinfo rpcinfo $pth`

    if [ ! -r "${CMD}" ]
    then
       return ${NOT_FOUND}
    fi

    if [ "${EXPERT}" = "t" ]; then
        expertmode_output "${strings} -a ${CMD}"
        expertmode_output "${ls} -l ${CMD}"
        return 5
    fi

    if ${strings} -a ${CMD} | ${egrep} "${GENERIC_ROOTKIT_LABEL}" > /dev/null 2>&1
    then
        STATUS=${INFECTED}
    fi
    if ${ls} -l ${CMD} | ${egrep} "^...s" > /dev/null 2>&1
    then
        STATUS=${INFECTED}
    fi
    return ${STATUS}
}

chk_date () {
    STATUS=${NOT_INFECTED}
    S_L="/bin/.*sh"
    CMD=`loc date date $pth`

    if [ "${EXPERT}" = "t" ]; then
        expertmode_output "${strings} -a ${CMD}"
        expertmode_output "${ls} -l ${CMD}"
        return 5
    fi
    [ "${SYSTEM}" = "FreeBSD" -a `echo $V | ${awk} '{ if ($1 > 4.9) print 1; else print 0 }'` -eq 1 ] &&
    {
       N=`${strings} -a ${CMD} | ${egrep} "${GENERIC_ROOTKIT_LABEL}" | \
          ${egrep} -c "$S_L"`
       if [ ${N} -ne 2 -a ${N} -ne 0 ]; then
          STATUS=${INFECTED}
       fi
    } ||
    {
       if ${strings} -a ${CMD} | ${egrep} "${GENERIC_ROOTKIT_LABEL}" 2>&1
          then
          STATUS=${INFECTED}
       fi
    }
    if ${ls} -l ${CMD} | ${egrep} "^...s" > /dev/null 2>&1
    then
        STATUS=${INFECTED}
    fi
    return ${STATUS}
}

chk_echo () {
    STATUS=${NOT_INFECTED}
    CMD=`loc echo echo $pth`

    if [ "${EXPERT}" = "t" ]; then
        expertmode_output "${strings} -a ${CMD}"
        expertmode_output "${ls} -l ${CMD}"
        return 5
    fi

    if ${strings} -a ${CMD} | ${egrep} "${GENERIC_ROOTKIT_LABEL}" > /dev/null 2>&1
    then
        STATUS=${INFECTED}
    fi
    if ${ls} -l ${CMD} | ${egrep} "^...s" > /dev/null 2>&1
    then
        STATUS=${INFECTED}
    fi
    return ${STATUS}
}

chk_env () {
    STATUS=${NOT_INFECTED}
    CMD=`loc env env $pth`

    if [ "${EXPERT}" = "t" ]; then
        expertmode_output "${strings} -a ${CMD}"
        expertmode_output "${ls} -l ${CMD}"
        return 5
    fi

    if ${strings} -a ${CMD} | ${egrep} "${GENERIC_ROOTKIT_LABEL}" > /dev/null 2>&1
    then
        STATUS=${INFECTED}
    fi
    if ${ls} -l ${CMD} | ${egrep} "^...s" > /dev/null 2>&1
    then
        STATUS=${INFECTED}
    fi

    return ${STATUS}
}

chk_timed () {
    STATUS=${NOT_INFECTED}
    CMD=`loc timed timed $pth`
    if [ ${?} -ne 0 ]; then
       CMD=`loc in.timed in.timed $pth`
       if [ ${?} -ne 0 ]; then
          return ${NOT_FOUND}
       fi
    fi
    if [ "${EXPERT}" = "t" ]; then
        expertmode_output "${strings} -a ${CMD}"
        return 5
    fi

    if ${strings} -a ${CMD} | ${egrep} "${GENERIC_ROOTKIT_LABEL}" > /dev/null 2>&1
    then
        STATUS=${INFECTED}
    fi
    return ${STATUS}
}

chk_identd () {
    STATUS=${NOT_INFECTED}
    CMD=`loc in.identd in.identd $pth`
    if [ ${?} -ne 0 ]; then
       return ${NOT_FOUND}
    fi
    if [ "${EXPERT}" = "t" ]; then
        expertmode_output "${strings} -a ${CMD}"
        return 5
    fi

    if ${strings} -a ${CMD} | ${egrep} "${GENERIC_ROOTKIT_LABEL}" > /dev/null 2>&1
    then
        STATUS=${INFECTED}
    fi
    return ${STATUS}
}

chk_init () {
    STATUS=${NOT_INFECTED}
    INIT_INFECTED_LABEL="UPX"
    CMD=`loc init init $pth`
    if [ ${?} -ne 0 ]; then
       return ${NOT_FOUND}
    fi
    if [ "${EXPERT}" = "t" ]; then
        expertmode_output "${strings} -a ${CMD}"
        return 5
    fi

    if ${strings} -a ${CMD} | ${egrep} "${INIT_INFECTED_LABEL}" > /dev/null 2>&1
    then
        STATUS=${INFECTED}
    fi
    return ${STATUS}
}

chk_pop2 () {
    STATUS=${NOT_INFECTED}
    CMD=`loc in.pop2d in.pop2d $pth`
    if [ ${?} -ne 0 ]; then
       return ${NOT_FOUND}
    fi
    if [ "${EXPERT}" = "t" ]; then
        expertmode_output "${strings} -a ${CMD}"
        return 5
    fi

    if ${strings} -a ${CMD} | ${egrep} "${GENERIC_ROOTKIT_LABEL}" > /dev/null 2>&1
    then
        STATUS=${INFECTED}
    fi
    return ${STATUS}
}

chk_pop3 () {
    STATUS=${NOT_INFECTED}
    CMD=`loc in.pop3d in.pop3d $pth`
    if [ ${?} -ne 0 ]; then
        return ${NOT_FOUND}
    fi
    if [ "${EXPERT}" = "t" ]; then
        expertmode_output "${strings} -a ${CMD}"
        return 5
    fi

    if ${strings} -a ${CMD} | ${egrep} "${GENERIC_ROOTKIT_LABEL}" > /dev/null 2>&1
    then
        STATUS=${INFECTED}
    fi
    return ${STATUS}
}

chk_write () {
    STATUS=${NOT_INFECTED}
    CMD=`loc write write $pth`
    WRITE_ROOTKIT_LABEL="bash|elite$|vejeta|\.ark"
    if [ "${EXPERT}" = "t" ]; then
        expertmode_output "${strings} -a ${CMD}"
        expertmode_output "${ls} -l ${CMD}"
        return 5
    fi

    if ${strings} -a ${CMD} | ${egrep} "${WRITE_ROOTKIT_LABEL}" | grep -v locale > /dev/null 2>&1
    then
        STATUS=${INFECTED}
    fi
    if ${ls} -l ${CMD} | ${egrep} "^...s" > /dev/null 2>&1
    then
        STATUS=${INFECTED}
    fi
    return ${STATUS}
}

chk_w () {
    STATUS=${NOT_INFECTED}
    CMD=`loc w w $pth`
    W_INFECTED_LABEL="uname -a"

    if [ "${EXPERT}" = "t" ]; then
        expertmode_output "${strings} -a ${CMD}"
        expertmode_output "${ls} -l ${CMD}"
        return 5
    fi
    if ${strings} -a ${CMD} | ${egrep} "${W_INFECTED_LABEL}" > /dev/null 2>&1
    then
        STATUS=${INFECTED}
    fi
    return ${STATUS}
}

chk_vdir () {
    STATUS=${NOT_INFECTED}
    CMD=`loc vdir vdir $pth`
    VDIR_INFECTED_LABEL="/lib/volc"
    if [ ! -r ${CMD} ]; then
        return ${NOT_FOUND}
    fi

    if [ "${EXPERT}" = "t" ]; then
        expertmode_output "${strings} -a ${CMD}"
        expertmode_output "${ls} -l ${CMD}"
        return 5
    fi
    if ${strings} -a ${CMD} | ${egrep} "${VDIR_INFECTED_LABEL}" > /dev/null 2>&1
    then
        STATUS=${INFECTED}
    fi
    return ${STATUS}
}

chk_tar () {
    STATUS=${NOT_INFECTED}
    CMD=`loc tar tar $pth`

    if [ "${EXPERT}" = "t" ]; then
        expertmode_output "${ls} -l ${CMD}"
        return 5
    fi
    if ${ls} -l ${CMD} | ${egrep} "^...s" > /dev/null 2>&1
    then
        STATUS=${INFECTED}
    fi
    return ${STATUS}
}

rexedcs () {
    STATUS=${NOT_INFECTED}
    CMD=`loc in.rexedcs in.rexedcs $pth`
    if [ "${?}" -ne 0 ]
       then
        if [ "${QUIET}" != "t" ]; then echo "not found"; fi
        return ${NOT_FOUND}
    fi

    if [ "${EXPERT}" = "t" ]; then
        expertmode_output "${strings} -a ${CMD}"
        return 5
    fi
    STATUS=${INFECTED}
    return ${STATUS}
}

chk_mail () {
    STATUS=${NOT_INFECTED}
    CMD=`loc mail mail $pth`
    if [ "${?}" -ne 0 ]
       then
        return ${NOT_FOUND}
    fi

    [ "${SYSTEM}" = "HP-UX" ] && return $NOT_TESTED

    MAIL_INFECTED_LABEL="sh -i"

    if [ "${EXPERT}" = "t" ]; then
        expertmode_output "${strings} -a ${CMD}"
        expertmode_output "${ls} -l ${CMD}"
        return 5
    fi

    if ${strings} -a ${CMD} | ${egrep} "${MAIL_INFECTED_LABEL}" > /dev/null 2>&1
    then
        STATUS=${INFECTED}
    fi
    if ${ls} -l ${CMD} | ${egrep} "^...s" > /dev/null 2>&1
    then
        STATUS=${INFECTED}
    fi
    return ${STATUS}
}

chk_biff () {
    STATUS=${NOT_INFECTED}
    CMD=`loc biff biff $pth`
    if [ "${?}" -ne 0 ]
       then
        return ${NOT_FOUND}
    fi

    if [ "${EXPERT}" = "t" ]; then
        expertmode_output "${strings} -a ${CMD}"
        expertmode_output "${ls} -l ${CMD}"
        return 5
    fi

    if ${strings} -a ${CMD} | ${egrep} "${GENERIC_ROOTKIT_LABEL}" > /dev/null 2>&1
    then
        STATUS=${INFECTED}
    fi
    if ${ls} -l ${CMD} | ${egrep} "^...s" > /dev/null 2>&1
    then
        STATUS=${INFECTED}
    fi
    return ${STATUS}
}

chk_egrep () {
    STATUS=${NOT_INFECTED}
    EGREP_INFECTED_LABEL="blah"
    CMD=`loc egrep egrep $pth`

    if [ "${EXPERT}" = "t" ]; then
        expertmode_output "${strings} -a ${CMD}"
        expertmode_output "${ls} -l ${CMD}"
        return 5
    fi
    if ${strings} -a ${CMD} | ${egrep} "${EGREP_INFECTED_LABEL}" > /dev/null 2>&1
    then
        STATUS=${INFECTED}
    fi
    return ${STATUS}
}

chk_grep () {
    STATUS=${NOT_INFECTED}
    GREP_INFECTED_LABEL="givemer"
    CMD=`loc grep grep $pth`

    if [ "${EXPERT}" = "t" ]; then
        expertmode_output "${strings} -a ${CMD}"
        expertmode_output "${ls} -l ${CMD}"
        return 5
    fi

    if ${strings} -a ${CMD} | ${egrep} "${GREP_INFECTED_LABEL}" > /dev/null 2>&1
    then
        STATUS=${INFECTED}
    fi
    if ${ls} -l ${CMD} | ${egrep} "^...s" > /dev/null 2>&1
    then
        STATUS=${INFECTED}
    fi
    return ${STATUS}
}

chk_find () {
    STATUS=${NOT_INFECTED}
    FIND_INFECTED_LABEL="/dev/ttyof|/dev/pty[pqrs]|^/prof|/home/virus|/security|file\.h"
    CMD=`loc find find $pth`

    if [ "${?}" -ne 0 ]
       then
        return ${NOT_FOUND}
    fi

    if [ "${EXPERT}" = "t" ]; then
        expertmode_output "${strings} -a ${CMD}"
        return 5
    fi

    if ${strings} -a ${CMD} | ${egrep} "${FIND_INFECTED_LABEL}" >/dev/null 2>&1
    then
       STATUS=${INFECTED}
    fi
    return ${STATUS}
}

chk_rlogind () {
    STATUS=${NOT_INFECTED}
    RLOGIN_INFECTED_LABEL="p1r0c4|r00t"
    CMD=`loc in.rlogind in.rlogind $pth`
    if [ ! -x "${CMD}" ]; then
          CMD=`loc rlogind rlogind $pth`
       if [ ! -x "${CMD}" ]; then
           return ${NOT_FOUND}
       fi
    fi
    if [ "${EXPERT}" = "t" ]; then
        expertmode_output "${strings} -a ${CMD}"
        return 5
    fi
    if ${strings} -a ${CMD} | ${egrep} "${RLOGIN_INFECTED_LABEL}" >/dev/null 2>&1
    then
       STATUS=${INFECTED}
    fi
    return ${STATUS}
}

chk_lsof () {
    STATUS=${NOT_INFECTED}
    LSOF_INFECTED_LABEL="^/prof"
    CMD=`loc lsof lsof $pth`
    if [ ! -x "${CMD}" ]; then
         return ${NOT_FOUND}
    fi
    if [ "${EXPERT}" = "t" ]; then
        expertmode_output "${strings} -a ${CMD}"
        return 5
    fi
    if ${strings} -a ${CMD} | ${egrep} "${LSOF_INFECTED_LABEL}" >/dev/null 2>&1
    then
       STATUS=${INFECTED}
    fi
    return ${STATUS}
}

chk_amd () {
    STATUS=${NOT_INFECTED}
    AMD_INFECTED_LABEL="blah"
    CMD=`loc amd amd $pth`
    if [ ! -x "${CMD}" ]; then
         return ${NOT_FOUND}
    fi
    if [ "${EXPERT}" = "t" ]; then
        expertmode_output "${strings} -a ${CMD}"
        return 5
    fi
    if ${strings} -a ${CMD} | ${egrep} "${AMD_INFECTED_LABEL}" >/dev/null 2>&1
    then
       STATUS=${INFECTED}
    fi
    return ${STATUS}
}

chk_slogin () {
    STATUS=${NOT_INFECTED}
    SLOGIN_INFECTED_LABEL="homo"
    CMD=`loc slogin slogin $pth`
    if [ ! -x "${CMD}" ]; then
         return ${NOT_FOUND}
    fi
    if [ "${EXPERT}" = "t" ]; then
        expertmode_output "${strings} -a ${CMD}"
        return 5
    fi
    if ${strings} -a ${CMD} | ${egrep} "${SLOGIN_INFECTED_LABEL}" >/dev/null 2>&1
    then
       STATUS=${INFECTED}
    fi
    return ${STATUS}
}

chk_cron () {
    STATUS=${NOT_INFECTED}
    CRON_INFECTED_LABEL="/dev/hda|/dev/hda[0-7]|/dev/hdc0"
    CMD=`loc cron cron $pth`
    if [ "${?}" -ne 0 ]; then
          CMD=`loc crond crond $pth`
    fi
    if [ "${?}" -ne 0 ]
       then
        return ${NOT_FOUND}
    fi
    if [ "${EXPERT}" = "t" ]; then
        expertmode_output "${strings} -a ${CMD}"
        return 5
    fi
    if ${strings} -a ${CMD} | ${egrep} "${CRON_INFECTED_LABEL}" >/dev/null 2>&1
    then
       STATUS=${INFECTED}
    fi
    return ${STATUS}
}

chk_ifconfig () {
    STATUS=${INFECTED}
    CMD=`loc ifconfig ifconfig $pth`
    if [ "${?}" -ne 0 ]; then
        return ${NOT_FOUND}
    fi

    if [ "${EXPERT}" = "t" ]; then
        expertmode_output "${strings} -a ${CMD}"
        return 5
    fi

    IFCONFIG_NOT_INFECTED_LABEL="PROMISC"
    IFCONFIG_INFECTED_LABEL="/dev/tux|/session.null"
    if ${strings} -a ${CMD} | ${egrep} "${IFCONFIG_NOT_INFECTED_LABEL}" \
    >/dev/null 2>&1
    then
       STATUS=${NOT_INFECTED}
    fi
    if ${strings} -a ${CMD} | ${egrep} "${IFCONFIG_INFECTED_LABEL}" \
    >/dev/null 2>&1
    then
       STATUS=${INFECTED}
    fi
    return ${STATUS}
}

chk_rshd () {
    STATUS=${NOT_INFECTED}
    case "${SYSTEM}" in
       Linux) CMD="${ROOTDIR}usr/sbin/in.rshd";;
       FreeBSD) CMD="${ROOTDIR}usr/libexec/rshd";;
       *) CMD=`loc rshd rshd $pth`;;
    esac

    if [ ! -x ${CMD} ] ;then
       return ${NOT_FOUND}
    fi
    if [ "${EXPERT}" = "t" ]; then
        expertmode_output "${strings} -a ${CMD}"
        return 5
    fi

    RSHD_INFECTED_LABEL="HISTFILE"
    if ${strings} -a ${CMD} | ${egrep} "${RSHD_INFECTED_LABEL}" > /dev/null 2>&1
    then
        STATUS=${INFECTED}
        if ${egrep} "^#.*rshd" ${ROOTDIR}etc/inetd.conf >/dev/null 2>&1 -o \
            ${ls} ${ROOTDIR}etc/xinetd.d/rshd >/dev/null 2>&1 ; then
           STATUS=${INFECTED_BUT_DISABLED}
        fi
    fi
    return ${STATUS}
}

chk_tcpdump () {
   STATUS=${NOT_INFECTED}
   TCPDUMP_I_L="212.146.0.34:1963";
   OPT=-an
   if ${netstat} "${OPT}" | ${egrep} "${TCPDUMP_I_L}"> /dev/null 2>&1; then
      STATUS=${INFECTED}
   fi
   return ${STATUS}
}

chk_tcpd () {
    STATUS=${NOT_INFECTED}
    TCPD_INFECTED_LABEL="p1r0c4|hack|/dev/xmx|/dev/hdn0|/dev/xdta|/dev/tux"

    [ -r ${ROOTDIR}etc/inetd.conf ] &&
    CMD=`${egrep} '^[^#].*tcpd' ${ROOTDIR}etc/inetd.conf | _head -1 | \
         ${awk} '{ print $6 }'`
    if ${ps} auwx | ${egrep} xinetd | ${egrep} -v grep >/dev/null 2>&1;  then
       CMD=`loc tcpd tcpd $pth`
    fi
    [ -z "${CMD}" ] && CMD=`loc tcpd tcpd $pth`

    [ "tcpd" = "${CMD}" ] && return ${NOT_FOUND};

    if [ "${EXPERT}" = "t" ]; then
        expertmode_output "${strings} -a ${CMD}"
        return 5
    fi

    if ${strings} -a ${CMD} | ${egrep} "${TCPD_INFECTED_LABEL}" > /dev/null 2>&1
    then
        STATUS=${INFECTED}
    fi
    return ${STATUS}
}

chk_sshd () {
    STATUS=${NOT_INFECTED}
    SSHD2_INFECTED_LABEL="check_global_passwd|panasonic|satori|vejeta|\.ark|/hash\.zk"
    getCMD 'sshd'

    if [ ${?} -ne 0 ]; then
       return ${NOT_FOUND}
    fi

    if [ "${EXPERT}" = "t" ]; then
        expertmode_output "${strings} -a ${CMD}"
        return 5
    fi

    if ${strings} -a ${CMD} | ${egrep} "${SSHD2_INFECTED_LABEL}" \
       > /dev/null 2>&1
    then
        STATUS=${INFECTED}
        if ${ps} ${ps_cmd} | ${egrep} sshd >/dev/null 2>&1; then
           STATUS=${INFECTED_BUT_DISABLED}
        fi
    fi
    return ${STATUS}
}

chk_su () {
    STATUS=${NOT_INFECTED}
    SU_INFECTED_LABEL="satori|vejeta|conf\.inv"
    CMD=`loc su su $pth`

    if [ "${EXPERT}" = "t" ]; then
        expertmode_output "${strings} -a ${CMD}"
        return 5
    fi

    if ${strings} -a ${CMD} | ${egrep} "${SU_INFECTED_LABEL}" > /dev/null 2>&1
    then
        STATUS=${INFECTED}
    fi
    return ${STATUS}
}

chk_fingerd () {
    STATUS=${NOT_INFECTED}
    FINGER_INFECTED_LABEL="cterm100|${GENERIC_ROOTKIT_LABEL}"
    CMD=`loc fingerd fingerd $pth`

    if [ ${?} -ne 0 ]; then
        CMD=`loc in.fingerd in.fingerd $pth`
        if [ ${?} -ne 0 ]; then
           return ${NOT_FOUND}
        fi
    fi

    if [ "${EXPERT}" = "t" ]; then
        expertmode_output "${strings} -a ${CMD}"
        return 5
    fi

    if ${strings} -a ${CMD} | ${egrep} "${FINGER_INFECTED_LABEL}" \
> /dev/null 2>&1
    then
        STATUS=${INFECTED}
    fi
    return ${STATUS}
}


chk_inetdconf () {
    STATUS=${NOT_INFECTED}
    SHELLS="${ROOTDIR}bin/sh ${ROOTDIR}bin/bash"

    if [ -r ${ROOTDIR}etc/shells ]; then
        SHELLS="`cat ${ROOTDIR}etc/shells | ${egrep} -v '^#'`";
    fi

    if [ -r ${ROOTDIR}etc/inetd.conf ]; then
  for CHK_SHELL in ${SHELLS}; do
    cat ${ROOTDIR}etc/inetd.conf | ${egrep} -v "^#" | ${egrep} "^.*stream.*tcp.*nowait.*$CHK_SHELL.*" > /dev/null
    if [ ${?} -ne 1 ]; then
      if [ "${EXPERT}" = "t" ]; then
        echo "Backdoor shell record(s) in /etc/inetd.conf: "
        cat ${ROOTDIR}etc/inetd.conf | ${egrep} -v "^#" | ${egrep} "^.*stream.*tcp.*nowait.*$CHK_SHELL.*"
      fi
      STATUS=${INFECTED}
    fi
  done
  return ${STATUS}
    else
      return ${NOT_FOUND}
    fi

}

chk_telnetd () {
    STATUS=${NOT_INFECTED}
    TELNETD_INFECTED_LABEL='cterm100|vt350|VT100|ansi-term|/dev/hda[0-7]'
    CMD=`loc telnetd telnetd $pth`

    if [ ${?} -ne 0 ]; then
        CMD=`loc in.telnetd in.telnetd $pth`
        if [ ${?} -ne 0 ]; then
           return ${NOT_FOUND}
        fi
    fi

    if [ "${EXPERT}" = "t" ]; then
        expertmode_output "${strings} -a ${CMD}"
        return 5
    fi

    if ${strings} -a ${CMD} | ${egrep} "${TELNETD_INFECTED_LABEL}" \
       >/dev/null 2>&1
    then
        STATUS=${INFECTED}
    fi
    return ${STATUS}
}

printn () {
    if `${echo} "a\c" | ${egrep} c >/dev/null 2>&1` ; then
        ${echo} -n "$1" 
    else
        ${echo} "${1}\c"  
    fi
}

# main
#


### using regexps, as the `-w' option to grep/egrep is not portable.
L_REGEXP='(^|[^A-Za-z0-9_])'
R_REGEXP='([^A-Za-z0-9_]|$)'

### default ROOTDIR is "/"
ROOTDIR='/'

while :
do
        case $1 in
        -r)     shift
                ROOTDIR=$1;;

        -p)     shift
                CHKRKPATH=$1;;

        -d)     DEBUG=t;;

        -x)     EXPERT=t;;

        -q)     QUIET=t;;

        -V)     echo >&2 "chkrootkit version ${CHKROOTKIT_VERSION}"
                exit 1;;

        -l)     echo >&2 "$0: tests: ${TOOLS} ${TROJAN}"
                exit 1;;

        -n)     tnfs;;

        -h | -*) echo >&2 "Usage: $0 [options] [test ...]
Options:
        -h                show this help and exit
        -V                show version information and exit
        -l                show available tests and exit
        -d                debug
        -q                quiet mode
        -x                expert mode
        -r dir            use dir as the root directory
        -p dir1:dir2:dirN path for the external commands used by chkrootkit
        -n                skip NFS mounted dirs"
                exit 1;;
        *)      break
        esac

        shift
done

### check the external commands needed

cmdlist="
awk
cut
echo
egrep
find
head
id
ls
netstat
ps
sed
ssh
strings
uname
"

### PATH used by loc
pth=`echo $PATH | sed -e "s/:/ /g"`
pth="$pth /sbin /usr/sbin /lib /usr/lib /usr/libexec ."

### external command's PATH
if [ "${CHKRKPATH}" = "" ]; then
  chkrkpth=${pth}
else
  ### use the path provided with the -p option
  chkrkpth=`echo ${CHKRKPATH} | sed -e "s/:/ /g"`
fi
echo=echo
for file in $cmdlist; do
        xxx=`loc $file $file $chkrkpth`
        eval $file=$xxx
        case "$xxx" in
        /* | ./* | ../*)

                if [ ! -x "${xxx}" ]
                then
                    echo >&2 "chkrootkit: can't exec \`$xxx'."
                    exit 1
                fi
                ;;
        *)
                echo >&2 "chkrootkit: can't find \`$file'."
                exit 1
                ;;
        esac
done


SYSTEM=`${uname} -s`
VERSION=`${uname} -r`
if [ "${SYSTEM}" != "FreeBSD" -a ${SYSTEM} != "OpenBSD" ] ; then
   V=4.4
else
   V=`echo $VERSION| ${sed} -e 's/[-_@].*//'| ${awk} -F . '{ print $1 "." $2 $3 }'`
fi

# head command
_head()
{
   if `$echo a | $head -n 1 >/dev/null 2>&1` ; then
      $head -n `echo $1 | tr -d "-"`
   else
      $head $1
   fi
}
# ps command
ps_cmd="ax"
if [ "$SYSTEM" = "SunOS" ]; then
  if [ "${CHKRKPATH}" = "" ]; then
    if [ -x /usr/ucb/ps ]; then
       ps="/usr/ucb/ps"
    else
       ps_cmd="-fe"
    fi
  else
    ### -p is in place: use `-fe' as ps options
    ps_cmd="-fe"
  fi
fi
# Check if ps command is ok
if ${ps} ax >/dev/null 2>&1 ; then
   ps_cmd="ax"
else
   ps_cmd="-fe"
fi

if [ `${id} | ${cut} -d= -f2 | ${cut} -d\( -f1` -ne 0 ]; then
   echo "$0 need root privileges"
   exit 1
fi

if [ $# -gt 0 ]
then
    ### perform only tests supplied as arguments
    for arg in $*
    do
        ### check if is a valid test name
        if echo "${TROJAN} ${TOOLS}"| \
           ${egrep} -v "${L_REGEXP}$arg${R_REGEXP}" > /dev/null 2>&1
        then
            echo >&2 "$0: \`$arg': not a known test"
            exit 1
        fi
    done
    LIST=$*
else
    ### this is the default: perform all tests
    LIST="${TROJAN} ${TOOLS}"
fi

if [ "${DEBUG}" = "t" ]; then
    set -x
fi

if [ "${ROOTDIR}" != "/" ]; then

    ### remove trailing `/'
    ROOTDIR=`echo ${ROOTDIR} | ${sed} -e 's/\/*$//g'`

    for dir in ${pth}
    do
      if echo ${dir} | ${egrep} '^/' > /dev/null 2>&1
      then
        newpth="${newpth} ${ROOTDIR}${dir}"
      else
        newpth="${newpth} ${ROOTDIR}/${dir}"
      fi
    done
    pth=${newpth}
   ROOTDIR="${ROOTDIR}/"
fi

if [ "${QUIET}" != "t" ]; then
    echo "ROOTDIR is \`${ROOTDIR}'"
fi


for cmd in ${LIST}
do

    if echo "${TROJAN}" | \
    ${egrep} "${L_REGEXP}$cmd${R_REGEXP}" > /dev/null 2>&1
    then
        if [ "${EXPERT}" != "t" -a "${QUIET}" != "t" ]; then
           printn "Checking \`${cmd}'... "
        fi
        chk_${cmd}
        STATUS=$?

        ### quiet mode
        if [ "${QUIET}" = "t" ]; then
            ### show only INFECTED status
            if [ ${STATUS} -eq 0 ]; then
                echo "Checking \`${cmd}'... INFECTED"
            fi
            continue
        fi

        case $STATUS in
        0) echo "INFECTED";;
        1) echo "not infected";;
        2) echo "not tested";;
        3) echo "not found";;
        4) echo "infected but disabled";;
        5) ;;   ### expert mode
        esac
    else
        ### external tool
        if [ "${EXPERT}" != "t" -a "${QUIET}" != "t" ]; then
            printn "Checking \`$cmd'... "
        fi
        ${cmd}

    fi
done

### chkrootkit ends here.
