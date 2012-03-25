# encoding: utf-8
#
#  = Species List Model
#
#  A SpeciesList is a list of Observations (*not* Names's).  Various User's
#  have used them -- among other things -- to:
#
#  1. Gather all the Observation's at a given Location or region.
#  2. Gather all the Observation's of a loose taxonomic group.
#  3. Bulk-post Observation's from a mushroom foray.
#
#  Since no specific purpose was intended, SpeciesList's have a number of
#  attributes with no set meaning: +when+, +where+, +title+, +notes+.  The User
#  can choose any value for any of these.  The only ones that has any use are
#  +when+ and +where+, which are used as the defaults for new Observation's
#  created specifically for this SpeciesList.
#
#  *NOTE*: Observation's may belong to more than one SpeciesList.  Also note
#  that Observation's created by a SpeciesList are fairly minimal: they are all
#  created with the same date, location, and (optionally) notes, and they all
#  get a single Naming without any Vote's.
#
#  == Location
#
#  A SpeciesList can belong to either a defined Location (+location+, a
#  Location instance) or an undefined one (+where+, just a String), but not
#  both.  To make this a little easier, you can refer to +place_name+ instead,
#  which returns the name of whichever is present. 
#
#  == Attributes
#
#  id::                    Locally unique numerical id, starting at 1.
#  sync_id::               Globally unique alphanumeric id, used to sync with remote servers.
#  created::               Date/time it was first created.
#  modified::              Date/time it was last modified.
#  user::                  User that created it.
#  when::                  Date -- meaning is up to User.
#  where::                 Location name -- meaning is up to User.
#  title::                 Title.
#  notes::                 Random notes.
#
#  ==== "Fake" attributes
#  file::                  Upload text file into +data+.
#  data::                  Internal temporary data field.
#  place_name::            Wrapper on top of +where+ and +location+.  Handles location_format.
#
#  == Class methods
#
#  None.
#
#  == Instance methods
#
#  text_name::             Return plain text title.
#  format_name::           Return formatted title.
#  unique_text_name::      (same thing, with id tacked on to make unique)
#  unique_format_name::    (same thing, with id tacked on to make unique)
#  ---
#  observations::          List of Observation's attached to it.
#  names::                 Get sorted list of Names used by its Observation's.
#  name_included::         Does this list include the given Name?
#  ---
#  process_file_data::     Process uploaded file according to one of the following two methods.
#  process_simple_list::   Process simple lists.
#  process_name_list::     Process lists generated by name list program(??)
#  construct_observation:: Create and add Observation to list.
#
#  == Callbacks
#
#  add_obs_callback::      Update User contribution when adding Observation's.
#  remove_obs_callback::   Update User contribution when removing Observation's.
#  log_destruction::       Log destruction after destroy.
#
################################################################################

class SpeciesList < AbstractModel
  belongs_to :location
  belongs_to :rss_log
  belongs_to :user

  has_and_belongs_to_many :observations, :after_add => :add_obs_callback,
                                         :before_remove => :remove_obs_callback

  attr_accessor :data

  # Automatically (but silently) log destruction.
  self.autolog_events = [:destroyed]

  # Callback that updates User contribution when adding Observation's.
  def add_obs_callback(o)
    SiteData.update_contribution(:add, :species_list_entries, user_id)
  end

  # Callback that updates User contribution when removing Observation's.
  def remove_obs_callback(o)
    SiteData.update_contribution(:del, :species_list_entries, user_id)
  end

  # Abstraction over +where+ and +location.display_name+.  Returns Location
  # name as a string, preferring +location+ over +where+ wherever both exist.
  # Also applies the location_format of the current user (defaults to :postal).
  def place_name
    if location
      location.display_name
    elsif User.current_location_format == :scientific
      Location.reverse_name(self.where)
    else
      self.where
    end
  end

  # Set +where+ or +location+, depending on whether a Location is defined with
  # the given +display_name+.  (Fills the other in with +nil+.)
  # Adjusts for the current user's location_format as well.
  def place_name=(place_name)
    where = if User.current_location_format == :scientific
      Location.reverse_name(place_name)
    else
      place_name
    end
    if loc = Location.find_by_name(where)
      self.where = nil
      self.location = loc
    else
      self.where = where
      self.location = nil
    end
  end

  # Return title in plain text for debugging.
  def text_name
    title.t.html_to_ascii
  end

  # Alias for title.
  def format_name
    title
  end

  # Return formatted title with id appended to make in unique.
  def unique_format_name
    title = self.title
    if title
      sprintf("%s (%d)", title, self.id)
    else
      sprintf("Species List #%d", self.id)
    end
  end

  # Return plaint ASCII title with id appended to make unique.
  def unique_text_name
    unique_format_name.t.html_to_ascii
  end

  # Get list of Names, sorted by text_name, for this list's Observation's.
  def names
    # Takes 0.07 seconds on Sebastopol Observations.
    # (Methods that call this don't need the description, review status, etc.)
    Name.find_by_sql %(
      SELECT DISTINCT n.id, n.rank, n.deprecated, n.text_name, n.search_name,
             n.author, n.observation_name, n.display_name, n.synonym_id,
             n.correct_spelling_id, n.citation
      FROM names n, observations o, observations_species_lists os
      WHERE n.id = o.name_id
        AND os.observation_id = o.id
        AND os.species_list_id = #{id}
      ORDER BY n.text_name ASC, n.author ASC
    )

    # Takes 0.10 seconds on Sebastopol Observations.
    # Name.find_by_sql %(
    #   SELECT DISTINCT n.*
    #   FROM names n, observations o, observations_species_lists os
    #   WHERE n.id = o.name_id
    #     AND os.observation_id = o.id
    #     AND os.species_list_id = #{id}
    #   ORDER BY n.text_name ASC, n.author ASC
    # )

    # Takes 0.25 seconds on Sebastopol Observations.
    # ids = observations.map(&:name_id).uniq
    # Name.find(:all, :conditions => ['id IN (?)', ids], :order => 'text_name ASC')

    # Takes 0.71 seconds on Sebastopol Observations.
    # self.observations.map {|o| o.name_id}.
    #   uniq.map {|id| Name.find(id)}.sort_by {|n| n.text_name}

    # Takes 1.00 seconds on Sebastopol Observations.
    # Name.all(:conditions => ['observations_species_lists.species_list_id = ?', id],
    #          :include => {:observations => :species_lists},
    #          :order => 'names.text_name ASC, names.author ASC')
  end

  # Tests to see if the species list includes an Observation with the given
  # Name (checks consensus only).  Primarily used by functional tests.
  def name_included(name)
    self.observations.map(&:name_id).include?(name.id)
  end

################################################################################

  # Upload file into internal "data" attribute.
  #
  #   spl = SpeciesList.new(args)
  #   spl.file = params[:file_upload]
  #   spl.process_file_data(sorter = NameSorter.new)
  #   names = sorter.xxx
  #
  def file=(file_field)
    if file_field.respond_to?(:read) and
       file_field.respond_to?(:content_type)
      content_type = file_field.content_type.chomp
      case content_type
      when 'text/plain',
           'application/text',
           'application/octet-stream'
        self.data = file_field.read
      else
        raise sprintf("Unrecognized content_type: %s\n", content_type)
      end
    else
      raise sprintf("Unrecognized file_field class: %s\n", file_field.class)
    end
  end

  # Process uploaded file.
  #
  #   spl = SpeciesList.new(args)
  #   spl.data = File.read('species_list.txt')
  #   spl.process_file_data(sorter = NameSorter.new)
  #   names = sorter.xxx
  #
  def process_file_data(sorter)
    if self.data
      if self.data[0] == 91 # '[' character
        process_name_list(sorter)
      else
        process_simple_list(sorter)
      end
    end
  end

  # Process simple list: one Name per line.
  def process_simple_list(sorter)
    self.data.split(/\s*[\n\r]+\s*/).each do |name|
      sorter.add_name(name.strip_squeeze)
    end
  end

  # Process species lists that get generated by the Name species listing
  # program(??)  I think this was some external script Nathan wrote for Darvin.
  def process_name_list(sorter)
    entry_text = self.data.gsub('[','').split(/\s*\r\]\r\s*/)
    entry_text.each do |e|
      timestamp = nil
      what = nil
      e.split(/\s*\r\s*/).each do |key_value|
        kv = key_value.split(/\s*\|\s*/)
        if kv.length != 2
          raise sprintf("Bad key|value pair (%s) in %s", key_value, filename)
        end
        key, value = kv
        if key == 'Date'
          # timestamp = Time.local(*(ParseDate.parsedate(value)))
          timestamp = Time.parse(value)
        elsif key == 'Name'
          what = value.strip.squeeze(' ')
        elsif key == 'Time'
          # Ignore
        else
          raise sprintf("Unrecognized key|value pair: %s\n", key_value)
        end
      end
      if what
        sorter.add_name(what, timestamp)
      end
    end
  end

  # Create and add a minimal Observation (with associated Naming and optional
  # Vote objects), and add it to the SpeciesList.
  #
  #   name = 'Agaricus campestris' or
  #          Name.find_by_text_name('Agaricus campestris')
  #
  #   spl.construct_observation(
  #     :created  => Time.now,
  #     :modified => Time.now,
  #     :user     => User.current,
  #     :when     => spl.when,
  #     :where    => spl.where,
  #     :what     => name,  # (no default)
  #     :notes    => '',
  #     :is_collection_location => false,
  #     :specimen => false,
  #     :vote     => nil
  #   )
  #
  def construct_observation(args)
    now  = Time.now
    user = User.current

    args[:created]  ||= now        
    args[:modified] ||= now        
    args[:user]     ||= user       
    args[:when]     ||= self.when  
    args[:notes]    ||= ''
    args[:vote]     ||= Vote.maximum_vote
    if !args[:where] && !args[:location]
      args[:where]    = where      
      args[:location] = location   
    end
    if args[:specimen].nil?
      args[:specimen] = false
    end
    if args[:is_collection_location].nil?
      args[:is_collection_location] = true
    end

    if !args[:what].blank?
      name = args[:what]
      name = name.id if name.is_a?(Name)
      obs = Observation.create(
        :created  => args[:created],
        :modified => args[:modified],
        :user     => args[:user],
        :when     => args[:when],
        :where    => args[:where],
        :location => args[:location],
        :name_id  => name,
        :notes    => args[:notes],
        :specimen => args[:specimen],
        :is_collection_location => args[:is_collection_location]
      )

      naming = Naming.create(
        :created     => args[:created],
        :modified    => args[:modified],
        :user        => args[:user],
        :name_id     => name,
        :observation => obs
      )

      if args[:vote] && (args[:vote].to_i != 0)
        vote = Vote.create(
          :created     => args[:created],
          :modified    => args[:modified],
          :user        => args[:user],
          :value       => args[:vote],
          :observation => obs,
          :naming      => naming
        )
      end

      self.observations << obs

      Transaction.post_observation(
        :id           => obs,
        :date         => args[:when],
        :location     => obs.location || obs.where,
        :name         => args[:what],
        :notes        => args[:notes],
        :specimen     => args[:specimen],
        :is_collection_location => args[:is_collection_location],
        :species_list => self
      )

      Transaction.post_naming(
        :observation => obs,
        :name        => args[:what],
        :vote        => args[:vote]
      )
    end
  end

################################################################################

protected

  def validate # :nodoc:
    # Clean off leading/trailing whitespace from +where+.
    self.where = self.where.strip_squeeze if self.where
    self.where = nil if self.where == ''

    if self.title.to_s.blank?
      errors.add(:title, :validate_species_list_title_missing.t)
    elsif self.title.length > 100
      errors.add(:title, :validate_species_list_title_too_long.t)
    end

    if self.place_name.to_s.blank? and !self.location
      errors.add(:place_name, :validate_species_list_where_missing.t)
    elsif self.where.to_s.length > 100
      errors.add(:place_name, :validate_species_list_where_too_long.t)
    end

    if !self.user && !User.current
      errors.add(:user, :validate_species_list_user_missing.t)
    end
  end
end
