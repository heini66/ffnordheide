#!/bin/bash

# validate_site.sh checks if the site.conf is valid json
GLUON_BRANCH='v2018.1.x'
GLUON_PACKAGES_BRANCH='master'

P="$(pwd)/ffndh-site"
echo "####### validating $P/site.conf ..."
GLUON_SITEDIR="./ffndh-site/" lua5.1 tests/site_config.lua

echo "####### validating $P/make-release.sh ..."
bash -n $P/make-release.sh

echo "####### validating $P/modules ..."
source $P/modules
testpath=/tmp/site-validate
rm -Rf $testpath
mkdir -p $testpath/packages
cd $testpath/packages
for feed in $GLUON_SITE_FEEDS; do
  echo "####### checking PACKAGES_${feed^^}_REPO ..."
  repo_var=$(echo PACKAGES_${feed^^}_REPO)
  commit_var=$(echo PACKAGES_${feed^^}_COMMIT)
  branch_var=$(echo PACKAGES_${feed^^}_BRANCH)
  repo=${!repo_var}
  commit=${!commit_var}
  branch=${!branch_var}
  if [ "$repo" == "" ]; then
    echo "repo $repo_var missing"
    exit 1
  fi
  if [ "$commit" == "" ]; then
    echo "commit $commit_var missing"
    exit 1
  fi
	if [ "$branch" == "" ]; then
    echo "branch $branch_var missing"
    exit 1
  fi
  git clone -b "$branch" --single-branch "$repo" $feed
  if [ "$?" != "0" ]; then exit 1; fi
  cd $feed
  git checkout "$commit"
  if [ "$?" != "0" ]; then exit 1; fi
  cd -
done
git clone -b $GLUON_PACKAGES_BRANCH --single-branch https://github.com/freifunk-gluon/packages
cd $testpath
git init gluon
cd gluon
git remote add origin https://github.com/freifunk-gluon/gluon
git config core.sparsecheckout true
echo "package/*" >> .git/info/sparse-checkout
git pull --depth=1 origin $GLUON_BRANCH
cp -a package/ $testpath/packages
cd $testpath/packages/package

echo "####### validating GLUON_SITE_PACKAGES from $P/site.mk ..."
# ignore non-gluon packages and standard gluon features
sed '/GLUON_RELEASE/,$d' $P/site.mk | egrep -v '(#|G|iwinfo|iptables|haveged|vim|mesh-batman-adv-14|web-advanced|web-wizard)'> $testpath/site.mk.sh
sed -i 's/\s\\$//g;/^$/d' $testpath/site.mk.sh
sed -i 's/gluon-mesh-batman-adv-1[45]/gluon-mesh-batman-adv/g' $testpath/site.mk.sh
cat $testpath/site.mk.sh |
while read packet; do
  if [ "$packet" != "" ]; then
    echo "check $packet ..."
    if [ "$(find $testpath/packages/ -type d -name "$packet")" '!=' '' ]; then
      : find found something
    else
      # check again with prefix gluon-
      if [ "$(find $testpath/packages/ -type d -name "gluon-$packet")" '!=' '' ]; then
        : find found something
      else
        echo "ERROR: $packet missing"
        exit 1
      fi
    fi
  fi
done
