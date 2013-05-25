# encoding: utf-8
require File.expand_path(File.dirname(__FILE__) + '/../boot.rb')

class ChecklistTest < UnitTestCase

  def genera(species)
    species.map {|name| name.split(' ', 2).first}.uniq
  end

  def test_checklist_for_site
    data = Checklist::ForSite.new
    assert(data.genera.length > 0)
    assert(data.species.length > 0)
  end

  def test_checklist_for_users
    for_site = Checklist::ForSite.new
    
    data = Checklist::ForUser.new(@mary)
    assert_equal(0, data.num_genera)
    assert_equal(0, data.num_species)
    assert_equal([], data.genera)
    assert_equal([], data.species)
    assert(for_site.contains(data))

    data = Checklist::ForUser.new(@katrina)
    assert(data.num_genera >= 1)
    assert(data.num_species >= 1)
    assert(for_site.contains(data))

    data = Checklist::ForUser.new(@rolf)
    assert(data.num_genera >= 3)
    assert(data.num_species >= 6)
    assert(for_site.contains(data))

    User.current = @dick
    Observation.create!(:name => names(:agaricus))
    assert_names_equal(names(:agaricus), Observation.last.name)
    assert_users_equal(@dick, Observation.last.user)
    data = Checklist::ForUser.new(@dick)
    assert_equal(0, data.num_species)

    Observation.create!(:name => names(:lactarius_kuehneri))
    data = Checklist::ForUser.new(@dick)
    assert_equal(['Lactarius'], data.genera)
    assert_equal(['Lactarius alpinus'], data.species)

    Observation.create!(:name => names(:lactarius_subalpinus))
    Observation.create!(:name => names(:lactarius_alpinus))
    data = Checklist::ForUser.new(@dick)
    assert_equal(['Lactarius'], data.genera)
    assert_equal(['Lactarius alpinus'], data.species)
  end

  def test_checklist_for_projects
    proj = projects(:bolete_project)
    data = Checklist::ForProject.new(proj)
    assert_equal(0, data.num_genera)
    assert_equal(0, data.num_species)
    assert_equal([], data.genera)
    assert_equal([], data.species)

    obs = observations(:coprinus_comatus_obs)
    proj.observations << obs
    data = Checklist::ForProject.new(proj)
    assert_equal(1, data.num_genera)
    assert_equal(1, data.num_species)
    assert_equal(['Coprinus'], data.genera)
    assert_equal(['Coprinus comatus'], data.species)
  end

  def test_checklist_for_species_lists
    list = species_lists(:unknown_species_list)
    data = Checklist::ForSpeciesList.new(list)
    assert_equal(0, data.num_genera)
    assert_equal(0, data.num_species)
    assert_equal([], data.genera)
    assert_equal([], data.species)

    obs = observations(:coprinus_comatus_obs)
    list.observations << obs
    data = Checklist::ForSpeciesList.new(list)
    assert_equal(1, data.num_genera)
    assert_equal(1, data.num_species)
    assert_equal(['Coprinus'], data.genera)
    assert_equal(['Coprinus comatus'], data.species)
  end
end
