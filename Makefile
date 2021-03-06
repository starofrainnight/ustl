-include Config.mk

################ Source files ##########################################

SRCS	:= $(wildcard *.cc)
INCS	:= $(wildcard *.h)
OBJS	:= $(addprefix $O,$(SRCS:.cc=.o))
DEPS	:= ${OBJS:.o=.d}
MKDEPS	:= Makefile Config.mk config.h $O.d
ONAME	:= $(notdir $(abspath $O))

SLIBL	:= $O$(call slib_lnk,${NAME})
SLIBS	:= $O$(call slib_son,${NAME})
SLIBT	:= $O$(call slib_tgt,${NAME})
SLINKS	:= ${SLIBL}
ifneq (${SLIBS},${SLIBT})
SLINKS	+= ${SLIBS}
endif

LIBA	:= $Olib${NAME}.a

################ Compilation ###########################################

.PHONY: all clean html check distclean maintainer-clean

ALLTGTS	:= ${MKDEPS}
all:	${ALLTGTS}

ifdef BUILD_SHARED
ALLTGTS	+= ${SLIBT} ${SLINKS}

all:	${SLIBT} ${SLINKS}
${SLIBT}:	${OBJS}
	@echo "Linking $(notdir $@) ..."
	@${LD} -fPIC ${LDFLAGS} $(call slib_flags,$(subst $O,,${SLIBS})) -o $@ $^ ${LIBS}
${SLINKS}:	${SLIBT}
	@(cd $(dir $@); rm -f $(notdir $@); ln -s $(notdir $<) $(notdir $@))

endif
ifdef BUILD_STATIC
ALLTGTS	+= ${LIBA}

all:	${LIBA}
${LIBA}:	${OBJS}
	@echo "Linking $(notdir $@) ..."
	@rm -f $@
	@${AR} qc $@ ${OBJS}
	@${RANLIB} $@
endif

$O%.o:	%.cc
	@echo "    Compiling $< ..."
	@${CXX} ${CXXFLAGS} -MMD -MT "$(<:.cc=.s) $@" -o $@ -c $<

%.s:	%.cc
	@echo "    Compiling $< to assembly ..."
	@${CXX} ${CXXFLAGS} -S -o $@ -c $<

include test/Module.mk

################ Installation ##########################################

.PHONY:	install uninstall install-incs uninstall-incs

####### Install headers

ifdef INCDIR	# These ifdefs allow cold bootstrap to work correctly
LIDIR	:= ${INCDIR}/${NAME}
INCSI	:= $(addprefix ${LIDIR}/,$(filter-out ${NAME}.h,${INCS}))
RINCI	:= ${LIDIR}.h

install:	install-incs
install-incs: ${INCSI} ${RINCI}
${LIDIR}:
	@echo "Creating $@ ..."
	@mkdir -p $@
${INCSI}: ${LIDIR}/%.h: %.h |${LIDIR}
	@echo "Installing $@ ..."
	@${INSTALLDATA} $< $@
${RINCI}: ${NAME}.h |${LIDIR}
	@echo "Installing $@ ..."
	@${INSTALLDATA} $< $@
uninstall:	uninstall-incs
uninstall-incs:
	@if [ -d ${LIDIR} -o -f ${RINCI} ]; then\
	    echo "Removing ${LIDIR}/ and ${RINCI} ...";\
	    rm -f ${INCSI} ${RINCI};\
	    ${RMPATH} ${LIDIR};\
	fi
endif

####### Install libraries (shared and/or static)

ifdef LIBDIR
LIBTI	:= ${LIBDIR}/$(notdir ${SLIBT})
LIBLI	:= $(addprefix ${LIBDIR}/,$(notdir ${SLINKS}))
LIBAI	:= ${LIBDIR}/$(notdir ${LIBA})

${LIBDIR}:
	@echo "Creating $@ ..."
	@mkdir -p $@

ifdef BUILD_SHARED
install:	${LIBTI} ${LIBLI}
${LIBTI}:	${SLIBT} |${LIBDIR}
	@echo "Installing $@ ..."
	@${INSTALLLIB} $< $@
${LIBLI}: ${LIBTI}
	@(cd ${LIBDIR}; rm -f $@; ln -s $(notdir $<) $(notdir $@))
endif

ifdef BUILD_STATIC
install:	${LIBAI}
${LIBAI}:	${LIBA} |${LIBDIR}
	@echo "Installing $@ ..."
	@${INSTALLLIB} $< $@
endif

uninstall:
	@echo "Removing library from ${LIBDIR} ..."
	@rm -f ${LIBTI} ${LIBLI} ${LIBSI} ${LIBAI}
endif
ifdef PKGCONFIGDIR
PCI	:= ${PKGCONFIGDIR}/ustl.pc
install:	${PCI}
${PKGCONFIGDIR}:
	@echo "Creating $@ ..."
	@mkdir -p $@
${PCI}:	ustl.pc |${PKGCONFIGDIR}
	@echo "Installing $@ ..."
	@${INSTALLDATA} $< $@

uninstall:	uninstall-pc
uninstall-pc:
	@if [ -f ${PCI} ]; then echo "Removing ${PCI} ..."; rm -f ${PCI}; fi
endif

################ Maintenance ###########################################

clean:
	@if [ -h ${ONAME} ]; then\
	    rm -f ${OBJS} ${DEPS} ${SLIBT} ${SLINKS} ${LIBA} $O.d ${ONAME};\
	    ${RMPATH} ${BUILDDIR} > /dev/null 2>&1 || true;\
	fi

distclean:	clean
	@rm -f Config.mk config.h config.status

maintainer-clean: distclean
	@if [ -d docs/html ]; then rm -f docs/html/*; rmdir docs/html; fi

$O.d:	${BUILDDIR}/.d
	@[ -h ${ONAME} ] || ln -sf ${BUILDDIR} ${ONAME}
${BUILDDIR}/.d:	Makefile
	@mkdir -p ${BUILDDIR} && touch ${BUILDDIR}/.d

${OBJS}:		${MKDEPS}
Config.mk:		Config.mk.in
config.h:		config.h.in
ustl.pc:		ustl.pc.in
Config.mk config.h ustl.pc:	configure
	@if [ -x config.status ]; then			\
	    echo "Reconfiguring ..."; ./config.status;	\
	else						\
	    echo "Running configure ..."; ./configure;	\
	fi

-include ${DEPS}
