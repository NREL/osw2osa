echo "finalizing..." > "$ANALYSIS_DIRECTORY/finalize_ran.txt"
echo "finalize running"

echo $SCRIPT_PATH
echo $ANALYSIS_ID
echo $RUBY_BIN
echo $HOST_URL
whoami

# Run a script in the context of rails to access models
echo $SCRIPT_PATH/access_database.rb
cd $RAILS_ROOT && bundle exec rails runner "$SCRIPT_PATH/access_database.rb" --analysis_id $ANALYSIS_ID --host $HOST_URL
