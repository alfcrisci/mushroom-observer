# encoding: utf-8
#
#  = Checklist
#
#  This class calculates a checklist of species observed by users,
#  projects, etc.
#
#  == Methods
#
#  num_genera::      Number of genera seen.
#  num_species::     Number of species seen.
#  genera::          List of genera (text_name) seen.
#  species::         List of species (text_name) seen.
#
#  == Usage
#
#    data = Checklist::ForUser.new(user)
#    puts "Life List: #{data.num_species} species in #{data.num_genera} genera."
#
################################################################################

class Checklist

  # Build list of species observed by entire site.
  class ForSite < Checklist
  end

  # Build list of species observed by one User.
  class ForUser < Checklist
    def initialize(user)
      @user = user
      raise "Expected User instance, got #{user.inspect}." unless user.is_a?(User)
    end

    def query
      super(
        :conditions => [ "o.user_id = #{@user.id}" ]
      )
    end
  end

  # Build list of species observed by one Project.
  class ForProject < Checklist
    def initialize(project)
      @project = project
      raise "Expected Project instance, got #{project.inspect}." unless project.is_a?(Project)
    end

    def query
      super(
        :tables => [ 'observations_projects op' ],
        :conditions => [ 'op.observation_id = o.id', "op.project_id = #{@project.id}" ]
      )
    end
  end

  # Build list of species observed by one SpeciesList.
  class ForSpeciesList < Checklist
    def initialize(list)
      @list = list
      raise "Expected SpeciesList instance, got #{list.inspect}." unless list.is_a?(SpeciesList)
    end

    def query
      super(
        :tables => [ 'observations_species_lists os' ],
        :conditions => [ 'os.observation_id = o.id', "os.species_list_id = #{@list.id}" ]
      )
    end
  end

################################################################################

  def initialize
    @genera = @species = nil
  end

  def num_genera
    calc_checklist if not @genera
    return @genera.length
  end

  def num_species
    calc_checklist if not @species
    return @species.length
  end

  def genera
    calc_checklist if not @genera
    return @genera.values.sort
  end

  def species
    calc_checklist if not @species
    return @species.values.sort
  end

  def contains(checklist)
    ((checklist.genera - self.genera) == []) and  ((checklist.species - self.species) == [])
  end
  
private

  def calc_checklist
    @genera = {}
    @species = {}
    synonyms = count_nonsynonyms_and_gather_synonyms
    count_synonyms(synonyms)
  end

  def count_nonsynonyms_and_gather_synonyms
    synonyms = {}
    ranks = [:Species] + Name::RANKS_BELOW_SPECIES
    for text_name, syn_id, deprecated in Name.connection.select_rows(query)
      if syn_id and deprecated == 1
        # wait until we find an accepted synonym
        text_name = synonyms[syn_id] ||= nil
      elsif syn_id
        # use the first accepted synonym we encounter
        text_name = synonyms[syn_id] ||= text_name
      else
        # count non-synonyms immediately
        count_species(text_name)
      end
    end
    return synonyms
  end

  def count_synonyms(synonyms)
    ranks = [:Species] + Name::RANKS_BELOW_SPECIES
    for syn_id, text_name in synonyms
      text_name ||= Name.connection.select_values(%(
        SELECT text_name FROM names
        WHERE synonym_id = #{syn_id}
          AND rank IN (#{ranks_to_consider})
        ORDER BY deprecated ASC
      )).first
      count_species(text_name)
    end
  end

  def count_species(text_name)
    unless text_name.blank?
      g, s = text_name.split(' ', 3)
      @genera[g] = g
      @species[[g, s]] = "#{g} #{s}"
    end
  end

  def ranks_to_consider
    ranks = [:Species] + Name::RANKS_BELOW_SPECIES
    ranks.map {|x| Name.connection.quote(x.to_s)}.join(', ')
  end

  def query(args={})
    tables = [
      'names n',
      'observations o',
    ]
    conditions = [
      'n.id = o.name_id',
      "n.rank IN (#{ranks_to_consider})",
      'o.user_id > 0',
    ]
    tables += args[:tables] || []
    conditions += args[:conditions] || []
    return %(
      SELECT n.text_name, n.synonym_id, n.deprecated
      FROM #{tables.join(', ')}
      WHERE (#{conditions.join(') AND (')})
    )
  end
end
