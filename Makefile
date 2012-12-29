# dumb Makefile that documents/advertises "we can create it"
#  root on gdrom0a version

KERNEL_BIN?=netbsd-GENERIC.bin

FTP_HOST?=ftp.NetBSD.org
#FTP_PATH?=pub/NetBSD-daily/HEAD/201010090000Z
FTP_PATH=pub/NetBSD/misc/tsutsui/dreamcast/20101010

SETS=kern-GENERIC base etc
SETS+=comp games man misc text
SETS+=xbase xcomp xetc xfont xserver

SETSDIR=sets
TARGETROOT=targetroot

SCRAMBLE_C_URL?=http://mc.pp.se/dc/files/scramble.c
MAKEIP_TAR_GZ_URL?=http://mc.pp.se/dc/files/makeip.tar.gz

CC?=	cc
FTP?=	ftp
#FTP=	tnftp
#FTP=	wget
GZIP?=	gzip
PAX?=	pax
SH?=	sh
TAR?=	tar

CDRDEV?= /dev/rcd0d
#CDRDEV= /dev/rcd1d
#CDRDEV= /dev/rcd0c
CDRSPEED?= 16
#CDRSPEED= 4

CDRECORD?= cdrecord
CDRECORD_OPT?= -dev=${CDRDEV} -speed=${CDRSPEED} driveropts=burnfree
MKISOFS?= mkisofs

all:	bootcd

makeip.tar.gz:
	${FTP} ${MAKEIP_TAR_GZ_URL}

makeip:	makeip.tar.gz
	${TAR} -zxf makeip.tar.gz
	${CC} -O -o makeip makeip.c

IP.BIN:	makeip
	./makeip ip.txt IP.BIN

scramble.c:
	${FTP} ${SCRAMBLE_C_URL}

scramble: scramble.c
	${CC} -O -o ${.TARGET} scramble.c

DONE_DOWNLOAD=		.done_download

${DONE_DOWNLOAD}:
	mkdir -p ${SETSDIR}
	( for set in ${SETS}; do \
	    if [ ! -f ${SETSDIR}/$${set}.tgz ]; then \
	      ${FTP} -o ${SETSDIR}/$${set}.tgz \
	      ftp://${FTP_HOST}/${FTP_PATH}/dreamcast/binary/sets/$${set}.tgz; \
	    fi; \
	  done; \
	)
	touch ${DONE_DOWNLOAD}

${KERNEL_BIN}.gz:
	${FTP} ftp://${FTP_HOST}/${FTP_PATH}/dreamcast/binary/kernel/${.TARGET}

${KERNEL_BIN}: ${KERNEL_BIN}.gz
	${GZIP} -dc ${KERNEL_BIN}.gz > ${KERNEL_BIN}

1ST_READ.BIN: scramble ${KERNEL_BIN}
	./scramble ${KERNEL_BIN} ${.TARGET}

DONE_FILESYSTEM=	.done_filesystem

${DONE_FILESYSTEM}:	${DONE_DOWNLOAD} 1ST_READ.BIN
	mkdir -p ${TARGETROOT}
	cp 1ST_READ.BIN ${TARGETROOT}
	chown root.wheel ${TARGETROOT}/1ST_READ.BIN
	( for set in ${SETS}; do \
	    echo extracting $${set}; \
	    ${TAR} -C ${TARGETROOT} -zxpf ${SETSDIR}/$${set}.tgz; \
	  done; \
	)
	(cd files/etc; ${PAX} -rw -pe * ../../${TARGETROOT}/etc)
	# (cd ${TARGETROOT}/dev; ${SH} MAKEDEV all)
	(cd ${TARGETROOT}/etc; mv motd motd.tmpl)
	(cd ${TARGETROOT}; mv var altvar; mkdir var)
	(cd ${TARGETROOT}; mkdir home)
	touch ${DONE_FILESYSTEM}

data.iso: ${DONE_FILESYSTEM}
	${MKISOFS} -R -l -C 0,11702 -o ${.TARGET} ${TARGETROOT}

data.raw: IP.BIN data.iso
	( cat IP.BIN ; dd if=data.iso bs=2048 skip=16 ) > ${.TARGET}

audio.raw:
	dd if=/dev/zero bs=2352 count=300 of=${.TARGET}

bootcd:	data.raw audio.raw
	${CDRECORD} ${CDRECORD_OPT} -multi -audio audio.raw
	${CDRECORD} ${CDRECORD_OPT} -multi -xa data.raw
	# see cdrecord(1) man page about -xa vs -xa1 options

clean:
	rm -f data.raw data.iso audio.raw 1ST_READ.BIN ${KERNEL_BIN}
	rm -f ${DONE_FILESYSTEM}
	rm -rf ${TARGETROOT}
	rm -f IP.BIN
	rm -f makeip scramble
	rm -f IP.TMPL ip.txt makeip.c

cleandir:
	${MAKE} clean
	rm -f ${DONE_DOWNLOAD}
	rm -rf ${SETSDIR}
	rm -f ${KERNEL_BIN}.gz
