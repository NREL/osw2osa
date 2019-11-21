#!/usr/bin/env sh

echo $0

# ARGUMENTS:
# First argument is the name of the gem (openstudio-standards)
# Second argument is the name of the github repo (NREL/openstudio-standards)
# Third is the name of the branch (master)

# First check if there is a file that
# indicates the gem has already been updated.
# We only need to update the bundle once / worker,
# not every time a data point is initialized.
GEMFILEUPDATE="/var/oscli/analysis_$SCRIPT_ANALYSIS_ID.lock"
if [ -e $GEMFILEUPDATE ]
then
    echo "***The gem bundle has already been updated"
    exit
fi

# Gemfile for OpenStudio
GEMFILE='/var/oscli/Gemfile'
GEMFILEDIR='/var/oscli'

# Update gem definition in OpenStudio Gemfile
# Replace:
# gem 'openstudio-standards', '= 0.1.15'
OLDGEM="gem '$1'"
echo "***Replacing gem:"
echo "$OLDGEM"

# With this:
# gem 'openstudio-standards', github: 'NREL/openstudio-standards', branch: 'PNNL'
NEWGEM="gem '$1', github: '$2', branch: '$3'"
echo "***With gem:"
echo "$NEWGEM"

# Modify the reference Gemfile in place
cp /usr/local/openstudio-2.8.1/Ruby/Gemfile /var/oscli/
sed -i -e "s|$OLDGEM.*|$NEWGEM|g" $GEMFILE

# Modify the gemspec in place3
sed -i '/openstudio-standards/d' /var/oscli/openstudio-gems.gemspec

# Show the modified Gemfile contents in the log
cd $GEMFILEDIR
dos2unix $GEMFILE
echo "***Here is the modified Gemfile:"
cat $GEMFILE

# Set & unset the required env vars
for evar in $(env | cut -d '=' -f 1 | grep ^BUNDLE); do unset $evar; done
for evar in $(env | cut -d '=' -f 1 | grep ^GEM); do unset $evar; done
for evar in $(env | cut -d '=' -f 1 | grep ^RUBY); do unset $evar; done
export HOME=/root
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export RUBYLIB=/usr/local/openstudio-2.8.1/Ruby:/usr/Ruby

# Update the specified gem in the bundle
echo "***Updating the specified gem:"
rm Gemfile.lock
bundle _1.17.1_ install --path gems

# Note that the bundle has been updated
echo >> $GEMFILEUPDATE
