AC_INIT([synapse], [0.2.99])
AC_DEFINE(RELEASE_NAME, "Cholecystokinin", "Codename of this release")

AC_CONFIG_MACRO_DIR([m4])
AC_CONFIG_SRCDIR([.])
AC_CONFIG_HEADERS([config.h])

AM_INIT_AUTOMAKE([1.11 -Wno-portability])

dnl -- Populate top_srcdir variable
top_srcdir=$(readlink -f $0 | sed -e s/configure$//)

dnl ==============================================
dnl Translation support
dnl ==============================================

GETTEXT_PACKAGE=synapse
AC_SUBST(GETTEXT_PACKAGE)
AC_DEFINE_UNQUOTED(GETTEXT_PACKAGE,"$GETTEXT_PACKAGE", [Gettext package])
ALL_LINGUAS=`ls ${top_srcdir}/po/*.po | sed 's/.po$//' | sed 's/.*\///' | tr '\n' ' '`

IT_PROG_INTLTOOL([0.35])
AM_GLIB_GNU_GETTEXT

dnl pkg-config
AC_PATH_PROG(PKG_CONFIG, pkg-config, no)
if test "x$PKG_CONFIG" = "xno"; then
        AC_MSG_ERROR([You need to install pkg-config])
fi

AC_PROG_INSTALL
AC_PROG_CC
AM_PROG_CC_C_O
AC_PROG_LIBTOOL
AC_STDC_HEADERS

dnl ==============================================
dnl Check for Vala
dnl ==============================================
AM_PROG_VALAC([0.16.0])
if test "x$VALAC" = "x"; then
	AC_MSG_ERROR([You need Vala compiler])
fi

AM_SILENT_RULES([yes])

dnl ==============================================
dnl Check that we meet the dependencies
dnl ==============================================
MIN_GLIB_VERSION=2.26.0
MIN_ZEITGEIST_VERSION=0.3.14
MIN_GEE_VERSION=0.5.2
MIN_JSON_VERSION=0.10.0

PKG_CHECK_MODULES(SYNAPSE_MODULES, \
  glib-2.0 >= $MIN_GLIB_VERSION \
  gtk+-3.0 \
  gobject-2.0 \
  gee-1.0 >= $MIN_GEE_VERSION \
  gio-unix-2.0 \
  unique-3.0 \
  keybinder-3.0 \
  json-glib-1.0 >= $MIN_JSON_VERSION \
  libnotify
  )


AC_ARG_ENABLE(librest,
              AS_HELP_STRING([--enable-librest[=@<:@no/auto/yes@:>@]],[Build support for plugins using librest ]),
              [enable_librest=$enableval],
              [enable_librest="auto"])

AC_ARG_ENABLE(indicator,
              AS_HELP_STRING([--enable-indicator[=@<:@no/auto/yes@:>@]],[Build support for application indicators ]),
              [enable_indicator=$enableval],
              [enable_indicator="auto"])

AC_ARG_ENABLE(zeitgeist,
             AS_HELP_STRING([--enable-zeitgeist[=@<:@no/yes@:>@]],[Build with zeitgeist support]),
             [enable_zeitgeist=$enableval],
             [enable_zeitgeist="yes"])

dnl ==============================================
dnl Check that we meet the optional dependencies
dnl ==============================================

if test "x$enable_zeitgeist" = "xyes" ; then
	PKG_CHECK_EXISTS([zeitgeist-1.0 >= $MIN_ZEITGEIST_VERSION],,
	                 AC_MSG_ERROR([zeitgeist-1.0 is not installed]))
	PKG_CHECK_MODULES(ZEITGEIST, zeitgeist-1.0 >= $MIN_ZEITGEIST_VERSION)
	AC_DEFINE(HAVE_ZEITGEIST, 1, [Have Zeitgeist])
fi
AM_CONDITIONAL(HAVE_ZEITGEIST, test "x$enable_zeitgeist" = "xyes")

if test "x$enable_indicator" = "xauto" ; then
	PKG_CHECK_EXISTS([appindicator3-0.1],
	                 enable_indicator="yes",
	                 enable_indicator="no")
fi

if test "x$enable_indicator" = "xyes" ; then
	PKG_CHECK_EXISTS([appindicator3-0.1],,
	                 AC_MSG_ERROR([appindicator3-0.1 is not installed]))
	PKG_CHECK_MODULES(APP_INDICATOR, appindicator3-0.1)
	AC_DEFINE(HAVE_INDICATOR, 1, [Have AppIndicator])
fi
AM_CONDITIONAL(HAVE_INDICATOR, test "x$enable_indicator" = "xyes")

REST_PKG_NAME=rest-0.7
if test "x$enable_librest" = "xauto" ; then
	PKG_CHECK_EXISTS([$REST_PKG_NAME],
	                 enable_librest="yes",
	                 enable_librest="no")
fi

if test "x$enable_librest" = "xyes" ; then
	PKG_CHECK_EXISTS([$REST_PKG_NAME],,
	                 AC_MSG_ERROR([$REST_PKG_NAME is not installed]))
	PKG_CHECK_MODULES(REST, $REST_PKG_NAME)
	AC_DEFINE(HAVE_LIBREST, 1, [Have librest])
fi
AM_CONDITIONAL(HAVE_LIBREST, test "x$enable_librest" = "xyes")

dnl Expansions
AS_AC_EXPAND([PKGDATADIR], [$datadir/$PACKAGE_NAME])
AS_AC_EXPAND([DATADIR], [$datadir])
dnl AS_AC_EXPAND([LIBDIR], [$libdir])
dnl AS_AC_EXPAND([LIBEXECDIR], [$libexecdir])

AC_DEFINE_UNQUOTED(PKGDATADIR, "$PKGDATADIR", [Package base directory])
AC_DEFINE_UNQUOTED(DATADIR, "$DATADIR", [Data directory])

AC_CONFIG_FILES([
Makefile
data/Makefile
src/Makefile
src/core/Makefile
src/plugins/Makefile
src/tile-view/Makefile
src/ui/Makefile
po/Makefile.in
vapi/Makefile
])

AC_OUTPUT

cat <<EOF

${PACKAGE}-${VERSION}

  Build Environment
    Install Prefix:     ${prefix}
    Zeitgeist support:  ${enable_zeitgeist}

  Optional dependencies
    Rest:               ${enable_librest}
    AppIndicator:       ${enable_indicator}

EOF

if test "x$enable_zeitgeist" != "xyes" ; then
	AC_MSG_WARN([Zeitgeist is disabled, building without relevancy backend!])
fi

