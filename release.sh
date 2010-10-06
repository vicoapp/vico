#!/bin/sh

tag=$1
if test -z "$tag"; then
	version=$(date +"%Y%m%d.%H%M")
	tag=tip
else
	version=$(echo $tag | sed -e 's/^V//' -e 's/_/./g' )
fi

echo tag is $tag
echo version = $version

dir=build.vibrant-$version
echo build directory is $dir
if test -d "$dir"; then
	echo "build dir already exists: $dir"
	exit 1
fi

echo checking out sources
hg clone -u $tag . "$dir" || exit 2

(cd $dir && ./mkdmg $version) || exit 3

mv $dir/vibrant-$version.dmg .
mv $dir/vibrant-$version.xml .

