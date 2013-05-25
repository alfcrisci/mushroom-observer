# encoding: utf-8
require File.expand_path(File.dirname(__FILE__) + '/../boot.rb')

class ObservationConsensusTest < UnitTestCase
  
  # with one naming, that naming gets returned
  def test_one_naming
    obj = ObservationConsensus.new
    target_naming = namings(:mary_morchella_naming)
    obj.add_naming(target_naming)
    assert_equal(target_naming, obj.consensus)
  end
  
  # with two namings by equivalent observers, the one made by the observer wins
  def test_observer_and_another
    obj = ObservationConsensus.new
    target_naming = namings(:rolf_morchella_angusticeps_naming)
    target_naming.refresh_vote_cache
    obj.add_naming(target_naming)
    other_naming = namings(:roy_morchella_importuna_naming)
    other_naming.refresh_vote_cache
    obj.add_naming(other_naming)

    assert_equal(target_naming, obj.consensus)
    
    observation = target_naming.observation
    observer_user = observation.user
    assert_equal(target_naming.user, observer_user)
    
    other_user = other_naming.user
    assert_not_equal(observer_user, other_user)
    assert_equal(observer_user.contribution, other_user.contribution)
  end

  # with two namings not by the observer, the one made by the more experienced user wins
  def test_two_unequal_users
    obj = ObservationConsensus.new
    target_naming = namings(:roy_morchella_importuna_naming)
    target_naming.refresh_vote_cache
    obj.add_naming(target_naming)
    other_naming = namings(:mary_morchella_naming)
    other_naming.refresh_vote_cache
    obj.add_naming(other_naming)

    assert_equal(target_naming, obj.consensus)

    observation = target_naming.observation
    observer_user = observation.user
    target_user = target_naming.user
    assert_not_equal(target_user, observer_user)

    other_user = other_naming.user
    assert_not_equal(other_user, observer_user)
    assert(target_user.contribution > other_user.contribution)
  end
  
  # with two namings by two equivalent observers that aren't the observer, the more recent one wins
  def test_two_equal_users
    obj = ObservationConsensus.new
    other_naming = namings(:mary_morchella_naming)
    other_naming.refresh_vote_cache
    obj.add_naming(other_naming)
    target_naming = namings(:katrina_morchella_angusticeps_naming)
    target_naming.refresh_vote_cache
    obj.add_naming(target_naming)

    assert_equal(target_naming, obj.consensus)

    observation = target_naming.observation
    observer_user = observation.user
    target_user = target_naming.user
    assert_not_equal(target_user, observer_user)

    other_user = other_naming.user
    assert_not_equal(other_user, observer_user)
    assert_equal(target_user.contribution, other_user.contribution)
    assert(target_naming.modified > other_naming.modified)
  end

  # Multiple votes
  
  # Deprecated and approved synonyms
  
  # Two deprecated synonyms
  
  # Two approved synonyms
  
  # Repeated name vs. single stronger name (observer)
  
  # Ignore weaker votes for synonyms
  
end
