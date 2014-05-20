#!/bin/sh

test_description='checkout long paths on Windows

Ensures that Git for Windows can deal with long paths (>260) enabled via core.longpaths'

. ./test-lib.sh

if test_have_prereq NOT_MINGW
then
	skip_all='skipping MINGW specific long paths test'
	test_done
fi

test_expect_success setup '
	p=longpathxx && # -> 10
	p=$p$p$p$p$p && # -> 50
	p=$p$p$p$p$p && # -> 250

	path=${p}/longtestfile && # -> 263 (MAX_PATH = 260)

	blob=$(echo foobar | git hash-object -w --stdin) &&

	printf "100644 %s 0\t%s\n" "$blob" "$path" |
	git update-index --add --index-info &&
	git commit -m initial -q
'

test_expect_success 'checkout of long paths without core.longpaths fails' '
	git config core.longpaths false &&
	test_must_fail git checkout -f 2>error &&
	grep -q "Filename too long" error &&
	test_path_is_missing longpa~1/longtestfile
'

test_expect_success 'checkout of long paths with core.longpaths works' '
	git config core.longpaths true &&
	git checkout -f &&
	test_path_is_file longpa~1/longtestfile
'

test_expect_success 'update of long paths' '
	echo frotz >> longpa~1/longtestfile &&
	echo $path > expect &&
	git ls-files -m > actual &&
	test_cmp expect actual &&
	git add $path &&
	git commit -m second &&
	git grep "frotz" HEAD -- $path
'

test_expect_success cleanup '
	# bash cannot delete the trash dir if it contains a long path
	# lets help cleaning up (unless in debug mode)
	test ! -z "$debug" || rm -rf longpa~1
'

ABSPATH=$(pwd -W)
test ${#ABSPATH} -le 209 &&
	test_set_prereq SHORTABSPATH

test_expect_success SHORTABSPATH 'clean up path close to MAX_PATH' '
  (
	set -e

	SUB0=C:/smiths/workspace/ATM-hourly/SLAVE/build-win7-32
	SUB1=data/data/gui/html/common/jwe/node_modules/lodash.merge/node_modules
	SUB2=lodash._basecreatecallback/node_modules/lodash.bind/node_modules
	SUB3=lodash._createwrapper/node_modules
	SUB4=lodash._basecreatewrapper/node_modules
	SUB5=lodash._basecreate/node_modules/lodash._isnative

	DEEP_ABS=$SUB0/$SUB1/$SUB2/$SUB3
	# $DEEP_ABS/$SUB4 is 258 chars long and would trigger the bug.

	TESTDIR=testdir
	PREFIX=x
	PREFIX_ABS=$(pwd -W)/$TESTDIR/$PREFIX

	# Overwrite the beginning of DEEP_ABS by PREFIX_ABS:
	TO_CUT=$PREFIX_ABS
	SUFFIX=$DEEP_ABS

	while test -n "$TO_CUT"; do
		TO_CUT=${TO_CUT#?}
		SUFFIX=${SUFFIX#?}
	done
	# Now $PREFIX_ABS$SUFFIX/$SUB4 is also 258 chars long and is a subdirectory
	# of current dir.

	# (Note the missing slash: SUFFIX may start with a slash a we do not want
	# to have two successive slashes.)
	DEEP=$PREFIX$SUFFIX

	mkdir "$TESTDIR"
	cd "$TESTDIR"
	git init

	mkdir -p $DEEP
	# Now create the critical $SUB4 that, moved under DEEP, triggers the bug.
	# Moreover, take also variants with length +-2, to check values near MAX_PATH:
	for SUB4A in "${SUB4}xx" "${SUB4}x" "${SUB4}" "${SUB4%?}" "${SUB4%??}"
	do
		# $SUB4A now represents the problem directory:
		# create it, and populate it witha subtree and a regular file
		# also create a regular file whose name is the same length as $SUB4A
		mkdir -p "$SUB4A/$SUB5"
		touch "$SUB4A/$SUB5/package.json" "$SUB4A/a_file" "${SUB4A%??}.c"
	done
	# move the whole tree under DEEP
	mv "${SUB4%%/*}" "$DEEP"

	git config core.longpaths yes
	git clean -fdx
  )
'

test_done
