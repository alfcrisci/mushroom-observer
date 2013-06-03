namespace :cache do
  desc "Refresh all the caches"
  task :all => [
    :refresh_contributions,
    :refresh_votes
  ]

  desc "Recalculate user contributions"
  task(:refresh_contributions => :environment) do
    print "Refreshing user.contribution...\n"
    SiteData.new.get_all_user_data
  end

  desc "Recalculate vote caches for observations and namings"
  task(:refresh_votes => [:refresh_namings, :refresh_observations]) do
    print "Refreshed both namings and observations"
  end
  
  desc "Recalcuate vote cache for namings"
  task(:refresh_namings => :environment) do
    print "Refreshing naming.vote_cache...\n"
    for n in Naming.find(:all)
      print "##{n.id}\r"
      n.calc_vote_table
    end
  end
  
  desc "Recalculate vote cache for observations"
  task(:refresh_observations => :environment) do
    print "Refreshing observation.vote_cache...\n"
    min_oid = ENV["MIN_OBSERVATION"]
    max_oid = ENV["MAX_OBSERVATION"]
    conditions = ["user_id != 0"]
    conditions.push("id >= #{min_oid}") if min_oid
    conditions.push("id <= #{max_oid}") if max_oid
    for o in Observation.find(:all, :conditions => conditions.join(" and "))
      print "##{o.id}\r"
      o.calc_consensus
    end
  end
  
  task(:test_observation_consensus => :environment) do
    print "Comparing old algorithm with the new algorithm...\n"
    min_oid = ENV["MIN_OBSERVATION"]
    max_oid = ENV["MAX_OBSERVATION"]
    conditions = ["user_id != 0"]
    conditions.push("id >= #{min_oid}") if min_oid
    conditions.push("id <= #{max_oid}") if max_oid
    try_count = 1
    count = 0
    for o in Observation.find(:all, :conditions => conditions.join(" and "))
      print "##{o.id}\r"
      count = count + 1
      if count > try_count
        print "\n"
        try_count += try_count
      end
      o.calc_consensus
      name = o.name
      oc = ObservationConsensus.new()
      for n in o.namings
        oc.add_naming(n)
      end
      oc_naming = oc.consensus
      oc_name = oc_naming ? oc_naming.name : Name.unknown
      if oc_name != name
        print "#{o.id}: #{name.text_name} != #{oc_name.text_name}\n"
      end
    end
  end
  
  desc "Report namings for observations"
  task(:report_observations => :environment) do
    min_oid = ENV["MIN_OBSERVATION"]
    max_oid = ENV["MAX_OBSERVATION"]
    conditions = ["user_id != 0"]
    conditions.push("id >= #{min_oid}") if min_oid
    conditions.push("id <= #{max_oid}") if max_oid
    for o in Observation.find(:all, :conditions => conditions.join(" and "))
      print "#{o.id}\t#{o.name_id}\t#{o.name.search_name}\n"
    end
  end
  
  desc "Reset the queued_emails flavor enum"
  task(:refresh_queued_emails => :environment) do
    print "Refreshing flavor enum for queued_emails...\n"
    ActiveRecord::Migration.add_column :queued_emails, :flavor_tmp, :enum, :limit => QueuedEmail.all_flavors
    QueuedEmail.connection.update("update queued_emails set flavor_tmp=flavor+0")
    ActiveRecord::Migration.remove_column :queued_emails, :flavor
    ActiveRecord::Migration.add_column :queued_emails, :flavor, :enum, :limit => QueuedEmail.all_flavors
    QueuedEmail.connection.update("update queued_emails set flavor=flavor_tmp")
    ActiveRecord::Migration.remove_column :queued_emails, :flavor_tmp
  end
  
  desc "Reset the ranks"
  task(:refresh_ranks => :environment) do
    print "Refreshing the list of ranks...\n"
    ActiveRecord::Migration.add_column :names, :rank_tmp, :enum, :limit => Name.all_ranks
    Name.connection.update("update names set rank_tmp=rank+0")
    ActiveRecord::Migration.remove_column :names, :rank
    ActiveRecord::Migration.add_column :names, :rank, :enum, :limit => Name.all_ranks
    Name.connection.update("update names set rank=rank_tmp")
    ActiveRecord::Migration.remove_column :names, :rank_tmp
  end
  
  desc "Reset the search_states query_type enum"
  task(:refresh_search_states => :environment) do
    print "Refreshing query_type enum for search_states...\n"
    ActiveRecord::Migration.add_column :search_states, :query_type_tmp, :enum, :limit => SearchState.all_query_types
    SearchState.connection.update("update search_states set query_type_tmp=query_type+0")
    ActiveRecord::Migration.remove_column :search_states, :query_type
    ActiveRecord::Migration.add_column :search_states, :query_type, :enum, :limit => SearchState.all_query_types
    SearchState.connection.update("update search_states set query_type=query_type_tmp")
    ActiveRecord::Migration.remove_column :search_states, :query_type_tmp
  end
  
  desc "Reset the name review_status enum"
  task(:refresh_name_review_status => :environment) do
    print "Refreshing review_status enum for names and past_names...\n"
    ActiveRecord::Migration.add_column :names, :review_status_tmp, :enum, :limit => Name.all_review_statuses
    ActiveRecord::Migration.add_column :past_names, :review_status_tmp, :enum, :limit => Name.all_review_statuses
    Name.connection.update("update names set review_status_tmp=review_status+0")
    Name.connection.update("update past_names set review_status_tmp=review_status+0")
    ActiveRecord::Migration.remove_column :names, :review_status
    ActiveRecord::Migration.remove_column :past_names, :review_status
    ActiveRecord::Migration.add_column :names, :review_status, :enum, :limit => Name.all_review_statuses
    ActiveRecord::Migration.add_column :past_names, :review_status, :enum, :limit => Name.all_review_statuses
    Name.connection.update("update names set review_status=review_status_tmp")
    Name.connection.update("update past_names set review_status=review_status_tmp")
    ActiveRecord::Migration.remove_column :names, :review_status_tmp
    ActiveRecord::Migration.remove_column :past_names, :review_status_tmp
  end
  
  desc "Add reviewers"
  task(:add_reviewers => :environment) do
    group = UserGroup.find_by_name('reviewers')
    for login in [] # Should be a list of logins for users you want to add to reviewers list
      user = User.find_by_login(login)
      unless user.user_groups.member?(group)
        user.user_groups << group
        user.save
        print "Added #{login} to the reviewers group\n"
      else
        print "#{login} is already in the reviewers group\n"
      end
    end
  end
  
  desc "Update authors and editors"
  task(:update_authors => :environment) do
    Name.connection.update %(
      UPDATE names
      SET user_id = 1
      WHERE user_id = 0
    )

    Name.connection.update %(
      UPDATE past_names
      SET user_id = 1
      WHERE user_id = 0
    )

    users = {}
    for n in Name.find(:all)
      user_ids = []
      author_id = nil
      last_version = 0
      for v in n.versions
        if last_version > v.version
          print "Expected version numbers to be strictly increasing\n"
          print "#{n.search_name}: #{last_version} > #{v.version}\n"
        end
        last_version = v.version
        id = v.user_id
        users[id] = User.find(v.user_id) unless users.keys().member?(id)
        user_ids.push(id) unless user_ids.member?(id)
        unless v.gen_desc.nil? or v.gen_desc == '' or author_id
          author_id = v.user_id
        end
      end
      authors = Set.new()
      if n.gen_desc and n.gen_desc != ''
        if n.authors # If there are already authors then make sure they are a set
          authors.merge(n.authors)
        else
          if author_id
            authors.add(users[author_id])
          end
        end
      end
      n.authors = authors.entries
      editors = Set.new(n.editors) # Make sure the editors are a set
      for id in user_ids
        editors.add(users[id])
      end
      n.editors = (editors - authors).entries
      n.save
    end
  end
  
end
