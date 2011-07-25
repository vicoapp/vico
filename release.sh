#!/bin/sh

tag=$1
if test -z "$tag"; then
	version="r$(hg id -n -r tip)"
	tag=tip
else
	version=$2
	if test -z "$version"; then
		echo "missing version"
		exit 1
	fi
fi

echo tag is $tag
echo version is $version

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

(cd $dir && ./mkdmg $version) || exit 3

mv $dir/vico-$version.dmg .
mv $dir/vico-$version.xml .

echo removing build directory
rm -rf "$dir"
