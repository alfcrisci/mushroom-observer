# encoding: utf-8
#
#  = EOL Data
#
#    name_count
#    total_image_count
#    total_description_count
#    has_images?(id) - id is the id of a Name
#    images(id) - id is the id of a Name
#    image_count(id) - id is the id of a Name
#    has_descriptions?(id) - id is the id of a Name
#    descriptions(id) - id is the id of a Name
#    description_count(id) - id is the id of a Name
#
################################################################################

class EolData
  attr_accessor :names
  
  def initialize
    self.names = prune_synonyms(image_names() + description_names() + term_names())
    @id_to_image = id_to_image()
    @name_id_to_images = name_id_to_images()
    @id_to_description = id_to_description()
    @name_id_to_descriptions = name_id_to_descriptions()
    @license_id_to_url = license_id_to_url()
    @user_id_to_legal_name = user_id_to_legal_name()
    @description_id_to_authors = description_id_to_authors()
    @image_id_to_names = image_id_to_names()
  end
  
  def image_to_names(id)
    @image_id_to_names[id].map {|n| n.real_search_name }.join(' & ')
  end
  
  def name_count
    self.names.count
  end
  
  def total_image_count
    @id_to_image.count
  end
  
  def total_description_count
    @id_to_description.count
  end
  
  def has_images?(id)
    @name_id_to_images.member?(id)
  end

  def all_images
    @id_to_image.values
  end
  
  def images(id)
    @name_id_to_images[id]
  end
  
  def image_count(id)
    if self.has_images?(id)
      @name_id_to_images[id].count
    else
      0
    end
  end
  
  def has_descriptions?(id)
    @name_id_to_descriptions.member?(id)
  end
  
  def all_descriptions
    @id_to_description.values
  end
  
  def descriptions(id)
    @name_id_to_descriptions[id]
  end
  
  def description_count(id)
    if self.has_descriptions?(id)
      @name_id_to_descriptions[id].count
    else
      0
    end
  end

  def license_url(id)
    @license_id_to_url[id]
  end
  
  def legal_name(id)
    @user_id_to_legal_name[id]
  end

  def rights_holder(image)
    result = image.copyright_holder
    if result.nil? or result.strip == ""
      legal_name(image.user_id)
    else
      result
    end
  end

  def authors(id)
    @description_id_to_authors[id].join(', ')
  end
  
  def refresh_links_to_eol
    refresh_predicate(self.names, ':eolName')
  end

private    
  def prune_synonyms(names)
    synonyms = Hash.new{|h, k| h[k] = []}
    for name in names
      if name.synonym_id
        synonyms[name.synonym_id] << name
      end
    end
    names_to_keep = {}
    for synonym_id, name_list in synonyms
      name = most_desirable_name(name_list)
      names_to_keep[name.id] = true
    end
    names.delete_if do |name|
      name.synonym_id and not names_to_keep.has_key?(name.id)
    end
    names
  end

  def most_desirable_name(names)
    most_desirable = names[0]
    for new_name in names[1..-1]
      most_desirable = most_desirable.more_popular(new_name)
    end
    most_desirable
  end

  DESCRIPTION_CONDITIONS = %(FROM name_descriptions, names
    WHERE name_descriptions.name_id = names.id
    AND names.ok_for_export
    AND NOT names.deprecated
    AND name_descriptions.review_status in ('vetted', 'unvetted')
    AND name_descriptions.ok_for_export
    AND name_descriptions.public
  )
  
  def description_names
    return get_sorted_names(DESCRIPTION_CONDITIONS)
  end

  def name_id_to_descriptions
    descriptions = @id_to_description
    make_list_hash_from_pairs(Name.connection.select_all("SELECT DISTINCT names.id nid, name_descriptions.id did #{DESCRIPTION_CONDITIONS}").map{
      |row| [row['nid'], descriptions[row['did']]]
    })
  end
  
  def id_to_description
    return make_id_hash(NameDescription.find_by_sql("SELECT DISTINCT name_descriptions.* #{DESCRIPTION_CONDITIONS}"))
  end

  IMAGE_CONDITIONS = %(FROM observations, images_observations, images, names
    WHERE observations.name_id = names.id
    AND observations.vote_cache >= 2.4
    AND observations.id = images_observations.observation_id
    AND images_observations.image_id = images.id
    AND images.vote_cache >= 2
    AND images.ok_for_export
    AND names.ok_for_export
    AND NOT names.deprecated
    AND names.rank IN ('Form','Variety','Subspecies','Species', 'Genus')
  )

  def image_names
    get_sorted_names(IMAGE_CONDITIONS)
  end

  TERM_CONDITIONS = %(FROM terms, images_terms, images, images_observations, observations, names
    WHERE ((terms.id = images_terms.term_id
            AND images.id = images_terms.image_id)
           OR (terms.thumb_image_id = images.id))
    AND images_observations.image_id = images.id
    AND images_observations.observation_id = observations.id
    AND observations.name_id = names.id
    AND images.vote_cache >= 2
    AND observations.vote_cache >= 2.4
    AND images.ok_for_export
    AND names.ok_for_export
    AND NOT names.deprecated
  )

  def term_names
    get_sorted_names(TERM_CONDITIONS)
  end

  def get_sorted_names(conditions)
    SortedSet.new(Name.find_by_sql("SELECT DISTINCT names.* #{conditions}"))
  end

  def get_name_rows(conditions)
    Name.connection.select_all("SELECT DISTINCT names.id nid, images.id iid #{conditions}")
  end
  
  def get_all_name_rows
    get_name_rows(IMAGE_CONDITIONS) + get_name_rows(TERM_CONDITIONS)
  end
  
  def name_id_to_images
    make_list_hash_from_pairs(get_all_name_rows.map{
      |row| [row['nid'], @id_to_image[row['iid']]]
    })
  end
  
  def get_images(conditions)
    Image.find_by_sql("SELECT DISTINCT images.* #{conditions}")
  end
  
  def get_all_images
    get_images(IMAGE_CONDITIONS) + get_images(TERM_CONDITIONS)
  end
  
  def id_to_image
    make_id_hash(get_all_images)
  end
  
  def image_id_to_names
    make_list_hash_from_pairs(names.map {
      |n| @name_id_to_images[n.id].map { |i| [i.id, n] } }.reduce {
      |a,b| a+b })
  end
  
  def license_id_to_url()
    # There are only three licenses at the moment. Just grabbing them all.
    result = {}
    License.find(:all).each {|l| result[l.id] = l.url}
    result
  end
  
  def user_id_to_legal_name()
    # Just grab the ones with contribution > 0 (1621) since we're going to use at least 400 of them
    result = {}
    data = User.connection.select_rows %(
      SELECT id, IF(COALESCE(name,'') = '', login, name) AS name
      FROM users WHERE contribution > 0
    )
    for id, legal_name in data
      result[id] = legal_name
    end
    result
  end

  def description_id_to_authors()
    data = Name.connection.select_rows %(
      SELECT name_description_id, user_id FROM name_descriptions_authors
    )
    pairs = data.map do |name_description_id, user_id|
      [ name_description_id.to_i, @user_id_to_legal_name[user_id.to_i] ]
    end
    result = make_list_hash_from_pairs(pairs)
    all_descriptions.each do |d|
      result[d.id] = [@user_id_to_legal_name[d.user_id]] if !result.member?(d.id)
    end
    result
  end
  
  def make_list_hash_from_pairs(pairs)
    result = Hash.new{|h, k| h[k] = []}
    for x, y in pairs
      result[x].push(y)
    end
    result
  end
  
  def make_id_hash(obj_list)
    result = {}
    obj_list.each {|o| result[o.id] = o}
    result
  end
  
  def refresh_predicate(subjects, predicate)
    Triple.delete_predicate_matches(predicate)
    create_name_triples(subjects, predicates)
  end

  def create_name_triples(subjects, p)
    url_generator = EolUrlGenerator.new()
    for s in subjects
      Triple.new(subject=s.uri, predicate=p, object=url_generator.calc_url(name))
    end
  end
  
  def name_url(name)
    return "http://eol.org/search/#{name.text_name}"
  end
end
