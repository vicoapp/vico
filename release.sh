#!/bin/sh

tag=$1
if test -z "$tag"; then
	version=$(date +"%Y%m%d.%H%M")
	tag=HEAD
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
cvs co -r $tag -d $dir vibrant || exit 2

(cd $dir && ./mkdmg $version) || exit 3

#scp $dir/vibrant-$version.dmg vibrant.bzero.se:/var/www/vibrant.bzero.se/download
mv $dir/vibrant-$version.dmg .

