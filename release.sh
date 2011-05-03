#!/bin/sh

tag=$1
if test -z "$tag"; then
	version="r$(hg id -n -r tip)"
	tag=tip
else
	version=$(echo $tag | sed -e 's/^V//' -e 's/_/./g' )
fi

echo tag is $tag
echo version = $version

dir=build.vico-$version
echo build directory is $dir
if test -d "$dir"; then
	echo "build dir already exists: $dir"
	exit 1
fi

echo checking out sources
hg clone -u $tag . "$dir" || exit 2

# HACK!
ln -s ../Nu.framework "$dir"
ln -s ../Sparkle.framework "$dir"

(cd $dir && ./mkdmg $version) || exit 3

mv $dir/vico-$version.dmg .

#echo removing build directory
#rm -rf "$dir"
